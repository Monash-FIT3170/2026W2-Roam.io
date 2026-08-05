/*
 * Author: Alvin Liong
 * Last Modified: 3/05/2026
 * Description:
 *   Provides the password reset screen where users request a recovery email.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_page_scaffold.dart';

/// Screen for requesting a Firebase password reset email.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Validates the email field and sends the password reset request.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    await auth.sendPasswordResetEmail(_emailController.text.trim());

    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
      return;
    }

    AppToast.success(
      context,
      'If an account exists for this email, a reset link has been sent.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return AuthPageScaffold(
          title: 'Reset your password',
          subtitle:
              'Enter your email. If an account exists, we will send a password reset link.',
          footerText: 'Remembered your password?',
          footerLabel: 'Login',
          onFooterTap: auth.isBusy ? null : () => Navigator.of(context).pop(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    filled: true,
                    fillColor: AppSurfaces.innerCard(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppSurfaces.border(context)),
                    ),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Email is required.';
                    if (!text.contains('@') || !text.contains('.')) {
                      return 'Enter a valid email address.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: auth.isBusy ? null : _submit,
                  child: auth.isBusy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send reset email'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
