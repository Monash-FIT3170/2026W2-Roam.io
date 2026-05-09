import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/auth_gate.dart';
import 'firebase_options.dart';
import 'shared/widgets/level_up_celebration.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  



  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

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
              _showLevelUpCelebration(auth.pendingLevelUp!);
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
            home: const AuthGate(),
          );
        },
      ),
    );
  }

  void _showLevelUpCelebration(int newLevel) {
    _levelUpOverlay = OverlayEntry(
      builder: (context) => LevelUpCelebration(
        newLevel: newLevel,
        onDismiss: () {
          _levelUpOverlay?.remove();
          _levelUpOverlay = null;
        },
      ),
    );

    _navigatorKey.currentState?.overlay?.insert(_levelUpOverlay!);
  }
}
