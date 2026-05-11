/*
 * Author: Alvin Liong
 * Last Modified: 3/05/2026
 * Description:
 *   Provides the email verification screen and actions for resending or
 *   checking verification status.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../providers/auth_provider.dart';

/// Screen shown to signed-in users until their email address is verified.
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Verify Email')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Please verify your email address before continuing. '
                  'Check your inbox and spam folder.',
                ),
                const SizedBox(height: 12),
                Text('Signed in as: ${auth.currentUser?.email ?? '-'}'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: auth.isBusy
                      ? null
                      : () async {
                          await context
                              .read<AuthProvider>()
                              .sendVerificationEmail();
                          if (!context.mounted) return;
                          if (auth.errorMessage != null) {
                            AppToast.error(context, auth.errorMessage!);
                            return;
                          }
                          AppToast.success(context, 'Verification email sent.');
                        },
                  child: const Text('Resend verification email'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: auth.isBusy
                      ? null
                      : () async {
                          await context
                              .read<AuthProvider>()
                              .refreshCurrentUser();
                        },
                  child: const Text('I have verified, refresh'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: auth.isBusy
                      ? null
                      : () async {
                          await context.read<AuthProvider>().signOut();
                        },
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
