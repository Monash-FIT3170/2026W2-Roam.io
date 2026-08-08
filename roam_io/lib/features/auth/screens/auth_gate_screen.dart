/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Routes users between loading, login, email verification, and authenticated
 *   app shell states. Keys the authenticated shell by UID so logout/login
 *   account switching rebuilds a fresh notification session.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigation/screens/main_shell_screen.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';
import 'package:roam_io/notifications/widgets/notification_overlay.dart';

/// Chooses the correct top-level screen based on authentication state.
class AuthGateScreen extends StatefulWidget {
  /// Whether the authenticated shell should request Android notification
  /// permission. This is disabled in widget tests.
  final bool requestNotificationPermission;

  const AuthGateScreen({super.key, this.requestNotificationPermission = true});

  @override
  State<AuthGateScreen> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGateScreen> {
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

        final uid = auth.currentUser!.uid;
        return NotificationOverlay(
          key: ValueKey<String>('notification-overlay-$uid'),
          child: MainShellScreen(
            key: ValueKey<String>('main-shell-$uid'),
            requestNotificationPermission: widget.requestNotificationPermission,
          ),
        );
      },
    );
  }
}
