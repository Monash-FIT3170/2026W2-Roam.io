/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Routes users between loading, login, email verification, and authenticated
 *   app shell states. Keys the authenticated shell by UID so logout/login
 *   account switching rebuilds a fresh notification session.
 */

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/notifications/widgets/notification_overlay.dart';

import '../../../shared/widgets/splash_loading_screen.dart';
import '../../navigation/screens/main_shell_screen.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

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
  static const _minimumSplashDuration = Duration(milliseconds: 500);

  bool _minimumSplashElapsed = false;
  String? _onboardedUid;

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
          _onboardedUid = null;
          return const LoginScreen();
        }

        if (!auth.isEmailVerified) {
          return const VerifyEmailScreen();
        }

        final uid = auth.currentUser!.uid;
        if (_onboardedUid != uid) _onboardedUid = null;
        final profile = auth.currentProfile;
        if (profile == null || profile.uid != uid) {
          if (auth.isBusy) return const SplashLoadingScreen();
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('We couldn’t load your profile.'),
                    TextButton(
                      onPressed: auth.refreshCurrentUser,
                      child: const Text('Try again'),
                    ),
                    TextButton(
                      onPressed: auth.signOut,
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!profile.onboardingCompleted) {
          return OnboardingScreen(
            key: ValueKey<String>('onboarding-$uid'),
            onComplete: () async {
              await auth.completeOnboarding();
              if (mounted && auth.currentUser?.uid == uid) {
                setState(() => _onboardedUid = uid);
              }
            },
          );
        }
        return NotificationOverlay(
          key: ValueKey<String>('notification-overlay-$uid'),
          child: MainShellScreen(
            key: ValueKey<String>('main-shell-$uid'),
            requestNotificationPermission: widget.requestNotificationPermission,
            initialIndex: _onboardedUid == uid ? 0 : 2,
          ),
        );
      },
    );
  }
}
