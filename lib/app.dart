import 'package:flutter/material.dart';

import 'screens/splash/splash_screen.dart';

class PlottingBazaarApp extends StatelessWidget {
  const PlottingBazaarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlottingBazaar CRM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const SplashScreen(),
    );
  }
}