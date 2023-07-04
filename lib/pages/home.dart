import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String text = "Stop Geo+ Service";

  @override
  void initState() {
    Geolocator.isLocationServiceEnabled().then((serviceEnabled) {
      if (!serviceEnabled) {
        return Future.error('Location services are disabled.');
      }
      Geolocator.checkPermission().then((permission) {
        if (permission == LocationPermission.denied) {
          Geolocator.requestPermission().then((permission) {
            SharedPreferences.getInstance().then((value) {
              if (permission == LocationPermission.denied) {
                value.setBool("authorized", false);
                return Future.error('Location permissions are denied');
              }
              if (permission == LocationPermission.deniedForever) {
                value.setBool("authorized", false);
                return Future.error(
                    'Location permissions are permanently denied, we cannot request permissions.');
              }
              value.setBool("authorized", true);
            });
          });
        }
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: const Text(
          'GEO+',
          style: TextStyle(color: Colors.deepPurple),
        ),
      ),
      drawer:  Drawer(
        child: Column(
          children: [
            const SizedBox(
              width: double.infinity,
              child: DrawerHeader(
                  margin: EdgeInsets.zero,
                  decoration: BoxDecoration(color: Colors.deepPurple),
                  child: Center(
                    child: Text(
                      'GEO+',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  )),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'), onTap: (){
                Get.back();
                Get.toNamed('/settings');
            },)
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StreamBuilder<Map<String, dynamic>?>(
              stream: FlutterBackgroundService().on('update'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                final data = snapshot.data!;
                Map<String, dynamic>? device = data["device"];
                Map<String, dynamic>? position = data["position"];
                return Column(
                  children: [
                    Text("Model : ${device?['model'] ?? 'Unknown'}"),
                    Text("Latitude: ${position?['lat']}"),
                    Text("Longitude: ${position?['long']}"),
                  ],
                );
              },
            ),
            ElevatedButton(
              child: const Text("Foreground Mode"),
              onPressed: () {
                FlutterBackgroundService().invoke("setAsForeground");
              },
            ),
            ElevatedButton(
              child: const Text("Background Mode"),
              onPressed: () {
                FlutterBackgroundService().invoke("setAsBackground");
              },
            ),
            ElevatedButton(
              child: Text(text),
              onPressed: () async {
                final service = FlutterBackgroundService();
                var isRunning = await service.isRunning();
                if (isRunning) {
                  service.invoke("stopService");
                } else {
                  service.startService();
                }
                if (!isRunning) {
                  text = 'Stop Geo+ Service';
                } else {
                  text = 'Start Geo+ Service';
                }
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
