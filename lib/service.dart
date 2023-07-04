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
import 'package:shared_preferences/shared_preferences.dart';

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
        android: AndroidInitializationSettings('ic_bg_service_small'),
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

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log);

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString("hello", "world");

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
      data['device'] = {
        "model": device,
        'id': androidInfo.id,
        'serialNumber': androidInfo.serialNumber,
        'version': androidInfo.version.release
      };
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device = iosInfo.model;
      data['device'] = {
        "model": device,
        'id': iosInfo.identifierForVendor,
        'serialNumber': iosInfo.localizedModel,
        'version': iosInfo.systemVersion
      };
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
                icon: 'ic_bg_service_small',
                ongoing: true,
              ),
            ),
          );
          // if you don't using custom notification, uncomment this
          service.setForegroundNotificationInfo(
            title: "Geo+ Service",
            content: "Long: ${position.longitude}; Lat: ${position.latitude}",
          );
        }
      }
      service.invoke(
        'update',
        {
          "position": {
            'lat': position.latitude,
            'long': position.longitude
          },
          "device": data['device'],
        },
      );
      data['position'] = position.toJson();
      /// send to url
      debugPrint('FLUTTER BACKGROUND SERVICE DEVICE : ${data.toString()}');
      await _sendData(data);
    } catch (e) {}
  });
}

Future<Position> _determinePosition() async {
  return await Geolocator.getCurrentPosition();
}

Future _sendData(Map<String, dynamic> data) async {
  SharedPreferences preference = await SharedPreferences.getInstance();
  String? serverUrl = preference.getString('SERVER_URL');
  if (serverUrl != null) {
    final formData = FormData.fromMap(data);
    try {
      await Dio().post(serverUrl, data: formData);
    } catch (e) {}
  }
}
