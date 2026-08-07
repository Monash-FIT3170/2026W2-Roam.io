/*
 * Author: Alvin Liong
 * Last Modified: 4/05/2026
 * Description:
 *   Initializes Firebase, wires app-wide authentication state, and launches
 *   the root Roam.io application widget.
 */

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/auth_gate_screen.dart';
import 'firebase_options.dart';
import 'shared/widgets/level_up_celebration.dart';
import 'theme/app_theme.dart';
import 'package:roam_io/notifications/services/android_notification_service.dart';
import 'package:roam_io/notifications/services/app_lifecycle_service.dart';

/// Starts the Flutter app after Firebase has been initialized.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLifecycleService.instance.initialise();
  await AndroidNotificationService.instance.initialise();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

/// Root application widget that provides authentication state and app themes.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  OverlayEntry? _levelUpOverlay;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          // Listen for level-up events
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (auth.pendingLevelUp != null && _levelUpOverlay == null) {
              final unlockToast = auth.takePendingUnlockToast();
              _showLevelUpCelebration(
                auth.pendingLevelUp!,
                rewardToastMessage: unlockToast,
              );
              auth.clearPendingLevelUp();
            }
          });

          return MaterialApp(
            title: 'Roam.io',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: auth.darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
            navigatorKey: _navigatorKey,
            home: const AuthGateScreen(),
          );
        },
      ),
    );
  }

  void _showLevelUpCelebration(int newLevel, {String? rewardToastMessage}) {
    _levelUpOverlay = OverlayEntry(
      builder: (context) => LevelUpCelebration(
        newLevel: newLevel,
        rewardToastMessage: rewardToastMessage,
        onDismiss: () {
          _levelUpOverlay?.remove();
          _levelUpOverlay = null;
        },
      ),
    );

    _navigatorKey.currentState?.overlay?.insert(_levelUpOverlay!);
  }
}
