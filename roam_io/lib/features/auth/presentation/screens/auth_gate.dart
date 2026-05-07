/*
 * Author: Alvin Liong
 * Last Modified: 4/05/2026
 * Description:
 *   Routes users between loading, login, email verification, and authenticated
 *   app shell states.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/mapfeature/MapPage.dart';

import '../../../home/presentation/screens/map_home.dart';
import '../../../home/presentation/screens/main_shell_screen.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

/// Chooses the correct top-level screen based on authentication state.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Refresh after the first frame so Provider access has a mounted context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.viewState == AuthViewState.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
