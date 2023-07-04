
import 'package:flutter/material.dart';
import 'package:geo/pages/home.dart';
import 'package:geo/pages/setting.dart';
import 'package:geo/service.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'GEO+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurpleAccent),
        useMaterial3: true,
      ),
      defaultTransition: Transition.cupertino,
      getPages: [
        GetPage(name: '/', page: () => const HomePage()),
        GetPage(name: '/settings', page: () =>  const SettingPage()),
      ],
      initialRoute: '/',
    );
  }
}

