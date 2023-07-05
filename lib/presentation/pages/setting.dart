import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get_storage/get_storage.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController controller = TextEditingController();
  final box = GetStorage();

  String defaultServerUrl = '';
  Timer? timer;
  @override
  void initState() {
    defaultServerUrl = box.read('SERVER_URL') ?? '';
    controller.text = defaultServerUrl;
    super.initState();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.lightBlue),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TextField(
              controller: controller,
              onChanged: (e) {
                setState(() {});
              },
              decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 0.0, horizontal: 16),
                  // border: OutlineInputBorder(),
                  helperText: 'Set server url to post data',
                  hintText: "SERVER URL"),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      onPressed: controller.text != defaultServerUrl
                          ? () async {
                              box.write('SERVER_URL', controller.text);
                              final service = FlutterBackgroundService();
                              var isRunning = await service.isRunning();
                              if (isRunning) {
                                service.invoke("stopService");
                              }
                              timer = Timer(const Duration(seconds: 2), () {
                                service.startService();
                              });
                              service.startService();
                              setState(() {
                                defaultServerUrl = controller.text;
                              });
                            }
                          : null,
                      child: const Text("Update"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        )),
      ),
    );
  }
}
