import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

class PlottingBazaarApp extends StatelessWidget {
  const PlottingBazaarApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PlottingBazaar CRM',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.data,
    home: const SplashScreen(),
  );
}
