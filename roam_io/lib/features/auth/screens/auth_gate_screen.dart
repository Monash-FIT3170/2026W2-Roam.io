/*
 * Author: Alvin Liong
 * Last Modified: 4/05/2026
 * Description:
 *   Routes users between loading, login, email verification, and authenticated
 *   app shell states.
 */

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import '../../navigation/screens/main_shell_screen.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

import '../../../shared/widgets/splash_loading_screen.dart';

/// Chooses the correct top-level screen based on authentication state.
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGateScreen> {
  static const _minimumSplashDuration = Duration(seconds: 2);

  bool _minimumSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    // Refresh after the first frame so Provider access has a mounted context.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(_minimumSplashDuration);
      if (!mounted) return;

      await context.read<AuthProvider>().refreshCurrentUser();
      if (!mounted) return;

      setState(() => _minimumSplashElapsed = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FlutterNativeSplash.remove();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!_minimumSplashElapsed || auth.viewState == AuthViewState.loading) {
          return const SplashLoadingScreen();
        }

        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        if (!auth.isEmailVerified) {
          return const VerifyEmailScreen();
        }

        return const MainShellScreen();
      },
    );
  }
}
