/*
 * Author: Alvin Liong
 * Last Modified: 4/05/2026
 * Description:
 *   Initializes Firebase, wires app-wide authentication state, and launches
 *   the root Roam.io application widget.
 */

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/auth_gate_screen.dart';
import 'features/journeys/data/journey_controller.dart';
import 'features/profile/domain/pending_xp_celebration.dart';
import 'firebase_options.dart';
import 'shared/widgets/xp_progress_celebration.dart';
import 'theme/app_theme.dart';
import 'package:roam_io/notifications/services/android_notification_service.dart';
import 'package:roam_io/notifications/services/app_lifecycle_service.dart';

/// Starts the Flutter app after Firebase has been initialized.
Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<JourneyController>(
          create: (_) => JourneyController(),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          // Listen for XP celebration events (level-up or forced claim overlay).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (auth.pendingXpCelebration != null && _levelUpOverlay == null) {
              final unlockToast = auth.takePendingUnlockToast();
              final pending = auth.pendingXpCelebration!;
              final celebration = unlockToast == null
                  ? pending
                  : pending.withRewardToast(unlockToast);
              _showXpCelebration(celebration);
              auth.clearPendingXpCelebration();
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

  void _showXpCelebration(PendingXpCelebration celebration) {
    _levelUpOverlay = OverlayEntry(
      builder: (context) => XpProgressCelebration(
        celebration: celebration,
        onDismiss: () {
          _levelUpOverlay?.remove();
          _levelUpOverlay = null;
        },
      ),
    );

    _navigatorKey.currentState?.overlay?.insert(_levelUpOverlay!);
  }
}
