// import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:localshare/notifiers/dark_mode_notifier.dart';
import 'package:localshare/pages/main_navigation.dart';
import 'package:localshare/pages/splash_screen.dart';
import 'package:localshare/utils/settings_manager.dart';
// import 'package:localshare/pages/permission_screen.dart';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;
  bool _hasEssentialPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    try {
      // Initialize settings manager
      await SettingsManager().initialize();

      // Check essential permissions
      final storageStatus = await Permission.storage.status;
      final locationStatus = await Permission.location.status;
      final audioStatus = await Permission.audio.status;

      // Consider permissions granted if storage is granted (essential for file sharing)
      bool hasEssential =
          storageStatus == PermissionStatus.granted &&
          locationStatus == PermissionStatus.granted &&
          audioStatus == PermissionStatus.granted;

      setState(() {
        _hasEssentialPermissions = hasEssential;
        _isInitialized = true;
      });
    } catch (e) {
      print('Permission check error: $e');
      setState(() {
        _hasEssentialPermissions = false;
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder:
          (context, isDark, child) => MaterialApp(
            theme: ThemeData(
              brightness: isDark ? Brightness.dark : Brightness.light,
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor:
                  isDark ? const Color(0xFF2C1D4D) : Colors.grey[50],
              appBarTheme: AppBarTheme(
                backgroundColor:
                    isDark
                        ? const Color.fromARGB(255, 59, 42, 96)
                        : Colors.blue,
                elevation: 0,
                titleTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor:
                    isDark ? const Color(0xFF3A2C5F) : Colors.white,
                indicatorColor:
                    isDark
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.1),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    );
                  }
                  return TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.normal,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                      size: 24,
                    );
                  }
                  return IconThemeData(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    size: 24,
                  );
                }),
              ),
              cardTheme: CardThemeData(
                color: isDark ? const Color(0xFF3A2C5F) : Colors.white,
                elevation: isDark ? 2 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textTheme: TextTheme(
                bodyLarge: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                bodyMedium: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                titleLarge: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                titleMedium: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              colorScheme:
                  isDark
                      ? const ColorScheme.dark(
                        primary: Colors.blue,
                        secondary: Colors.blueAccent,
                        surface: Color(0xFF3A2C5F),
                        background: Color(0xFF2C1D4D),
                        onPrimary: Colors.white,
                        onSecondary: Colors.white,
                        onSurface: Colors.white,
                        onBackground: Colors.white,
                      )
                      : const ColorScheme.light(
                        primary: Colors.blue,
                        secondary: Colors.blueAccent,
                        surface: Colors.white,
                        background: Colors.grey,
                        onPrimary: Colors.white,
                        onSecondary: Colors.white,
                        onSurface: Colors.black87,
                        onBackground: Colors.black87,
                      ),
            ),
            debugShowCheckedModeBanner: false,
            home:
                _isInitialized ? const MainNavigation() : const SplashScreen(),
          ),
    );
  }
}

Future<bool> hasStoragePermission() async {
  if (Platform.isAndroid) {
    final sdkInt = (await Permission.storage.status).toString();
    if (await Permission.storage.isGranted) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.photos.isGranted) return true;
    if (await Permission.mediaLibrary.isGranted) return true;
    if (await Permission.audio.isGranted) return true;
    // For Android 13+:
    if (await Permission.photos.isGranted &&
        await Permission.videos.isGranted &&
        await Permission.audio.isGranted)
      return true;
    // For Android 13+ (API 33+), check READ_MEDIA_* permissions
    if (await Permission.mediaLibrary.isGranted) return true;
  }
  // For iOS, just check photos
  if (Platform.isIOS) {
    if (await Permission.photos.isGranted) return true;
  }
  return false;
}
