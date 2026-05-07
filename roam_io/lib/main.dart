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
import 'theme/app_theme.dart';

/// Starts the Flutter app after Firebase has been initialized.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

/// Root application widget that provides authentication state and app themes.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Roam.io',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: auth.darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
            home: const AuthGateScreen(),
          );
        },
      ),
    );
  }
}
