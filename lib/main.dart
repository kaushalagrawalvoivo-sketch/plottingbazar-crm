import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/supabase_constants.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  // Without this, any error thrown before runApp() reaches the browser as
  // an uncaught JS exception and leaves a blank, frozen page -- which is
  // exactly what "the app crashed" looks like from the outside. This is
  // most likely to happen right when a minimized/backgrounded PWA is
  // reopened: Android/Chrome commonly discards the page in the background
  // to save memory and does a fresh load the moment it's reopened, and if
  // the network hasn't finished reconnecting yet at that instant, the very
  // first request this app makes (Supabase.initialize, below) fails.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Uncaught Flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();

  try {
    await _initSupabaseWithRetry();
  } catch (error) {
    // Genuinely no connection even after retrying -- show a real retry
    // screen instead of leaving a blank page that looks like a crash.
    debugPrint('Supabase init ultimately failed: $error');
    runApp(ProviderScope(child: _StartupErrorApp(onRetry: main)));
    return;
  }

  // Notifications never need to block the first frame -- the service
  // already guards every one of its own failures internally. Awaiting it
  // here (after Supabase) used to add a second full round-trip before the
  // user saw anything, on every single cold/resumed load.
  unawaited(NotificationService.instance.initialize());

  runApp(const ProviderScope(child: PlottingBazaarApp()));
}

/// Retries a couple of times with a short backoff instead of failing
/// straight away. Reopening a backgrounded PWA very often races the
/// device's network reconnecting, and a single failed request here used
/// to take down the entire app before it ever got to show anything.
Future<void> _initSupabaseWithRetry() async {
  const maxAttempts = 3;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await Supabase.initialize(
        url: SupabaseConstants.url,
        publishableKey: SupabaseConstants.publishableKey,
      );
      return;
    } catch (error) {
      debugPrint('Supabase.initialize attempt $attempt failed: $error');
      if (attempt == maxAttempts) rethrow;
      await Future.delayed(Duration(milliseconds: 500 * attempt));
    }
  }
}

/// Shown instead of a blank/frozen page when Supabase genuinely can't be
/// reached after retries (e.g. no internet at all) -- lets the user try
/// again with a tap instead of force-closing and reopening the app.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Could not connect. Check your internet connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    ),
  );
}
