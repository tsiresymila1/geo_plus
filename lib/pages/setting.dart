import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController controller = TextEditingController();

  String defaultServerUrl = '';

  @override
  void initState() {
    SharedPreferences.getInstance().then((preference) {
      defaultServerUrl = preference.getString('SERVER_URL') ?? '';
      controller.text = defaultServerUrl;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.deepPurple),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                  border: OutlineInputBorder(),
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
                          ? () {
                              SharedPreferences.getInstance()
                                  .then((preference) {
                                preference.setString(
                                    'SERVER_URL', controller.text);
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
