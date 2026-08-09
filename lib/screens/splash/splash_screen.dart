import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_screen.dart';
import '../dashboard/main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // A brief pause just so the logo is actually visible -- this used to
    // be a flat 2 seconds *every single time* the app opened (including
    // every resume from being minimized), which was most of why the app
    // felt slow to load. Supabase is already fully initialized before
    // this screen ever runs (main.dart awaits it), so there's no real
    // work left to wait for here.
    Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      // Supabase persists the session to local storage by default, so if
      // the user already has a valid (non-expired) session we skip the
      // login screen entirely instead of forcing them to log in again
      // every time the app opens.
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null && !session.isExpired;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isLoggedIn ? const MainShell() : const LoginScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image(image: AssetImage('assets/images/logo.png'), width: 220),
      ),
    );
  }
}
