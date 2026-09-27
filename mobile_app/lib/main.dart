import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/gov_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Crash-prevention: Global error logging
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // Log error details locally to prevent silent app crashes
      debugPrint("GovAppError: ${details.exceptionAsString()}");
    };

    // System Navigation Bar & Status Bar Theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: GovTheme.ashokaNavy,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    runApp(const FieldDrugTestingApp());
  }, (Object error, StackTrace stack) {
    debugPrint("UncaughtAppZoneError: $error\n$stack");
  });
}

class FieldDrugTestingApp extends StatelessWidget {
  const FieldDrugTestingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MHA Field Drug Testing Companion',
      debugShowCheckedModeBanner: false,
      theme: GovTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
