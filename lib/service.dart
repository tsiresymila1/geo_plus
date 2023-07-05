import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'domains/entities/position.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  /// OPTIONAL, using custom notification channel id
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'geo_plus_foreground', // id
    'GEO+ SERVICE', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('notification'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,
      // auto start service
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'geo_plus_foreground',
      initialNotificationTitle: 'GEO+ SERVICE',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will be executed when app is in foreground in separated isolate
      onForeground: onStart,

      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final box = GetStorage();
  final dir = await getApplicationDocumentsDirectory();
  Isar isar = await Isar.open(
    [PositionEntitySchema],
    directory: dir.path,
  );
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // bring to foreground
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    // test using external plugin
    final deviceInfo = DeviceInfoPlugin();
    Map<String, dynamic> data = {};
    String? device;
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;

      device = androidInfo.model;
      data['deviceId'] = androidInfo.id;
      data['model'] = device;
      data['version'] = androidInfo.version.release.toString();
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device = iosInfo.model;
      data['deviceId'] = iosInfo.identifierForVendor;
      data['model'] = device;
      data['version'] = iosInfo.systemVersion.toString();
    }
    try {
      Position position = await _determinePosition();
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          flutterLocalNotificationsPlugin.show(
            888,
            'GEO+ SERVICE',
            '${DateTime.now()}',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'geo_plus_foreground',
                'GEO+ SERVICE',
                icon: 'notification',
                ongoing: true,
              ),
            ),
          );
          // if you don't using custom notification, uncomment this
          service.setForegroundNotificationInfo(
            title: "Geo+ Service",
            content:
                "Long: ${position.longitude}; Lat: ${position.latitude} Speed: ${position.speed}",
          );
        }
      }
      service.invoke(
        'update',
        {
          "position": {
            'lat': position.latitude,
            'long': position.longitude,
            ...position.toJson()
          },
          "device": {
            "model": data['model'],
            "deviceId": data['deviceId'],
            "version": data['version'].toString()
          },
        },
      );
      data['positions'] = [position.toJson()];

      /// send to url
      await _sendData(
          isar, box, data, position, position.toJson()['timestamp']);
    } catch (e) {
      debugPrint('ERROR : ${e.toString()}');
    }
  });
}

Future<Position> _determinePosition() async {
  return await Geolocator.getCurrentPosition();
}

Future _sendData(Isar isar, GetStorage box, Map<String, dynamic> data,
    Position position, int timestamp) async {
  String? serverUrl = box.read<String>('SERVER_URL');
  int lastTimestamp = box.read<int>('timestamp') ?? 0;
  if (serverUrl != null && timestamp != lastTimestamp) {
    try {
      final positions =
          await isar.positionEntitys.where().sortByTimestamp().findAll();

      await Dio().post(serverUrl,
          data: {
            ...data,
            'position': [...data['position'], positions.map((e) => e.toJson())]
          },
          options: Options(headers: {"Content-Type": "application/json"}));
      box.write('timestamp', timestamp);
      await isar.positionEntitys.where().deleteAll();
    } catch (e) {
      final savedP = await isar.positionEntitys
          .filter()
          .timestampEqualTo(position.timestamp?.millisecondsSinceEpoch)
          .findFirst();
      if (savedP == null) {
        final p = PositionEntity.fromJson(position.toJson());
        await isar.writeTxn(() async {
          return await isar.positionEntitys.put(p);
        });
        debugPrint("ISAR : data saved ${p.toJson()}");
      }
    }
  }
}
