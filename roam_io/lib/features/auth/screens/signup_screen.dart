/*
 * Author: Alvin Liong
 * Last Modified: 3/05/2026
 * Description:
 *   Provides the account registration screen for creating new user accounts
 *   and profiles.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_page_scaffold.dart';

/// Screen for registering a new account with profile details.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  /// Validates registration fields and creates the account.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      username: _usernameController.text.trim(),
      displayName: _displayNameController.text.trim(),
    );

    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
      return;
    }

    AppToast.success(
      context,
      'Account created. Verification email sent. Please verify before logging in.',
    );

    // Return to the root AuthGate route so it can show VerifyEmailScreen.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return AuthPageScaffold(
          title: 'Start your adventure',
          subtitle:
              'Create your account to unlock visits, earn progress, and save favourites.',
          footerText: 'Already have an account?',
          footerLabel: 'Login',
          onFooterTap: auth.isBusy ? null : () => Navigator.of(context).pop(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInputField(
                  controller: _usernameController,
                  label: 'Username',
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Username is required.';
                    if (text.length < 3) {
                      return 'Username must be at least 3 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  controller: _displayNameController,
                  label: 'Display name',
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Display name is required.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Email is required.';
                    if (!text.contains('@') || !text.contains('.')) {
                      return 'Enter a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  controller: _passwordController,
                  label: 'Password',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    final text = value ?? '';
                    if (text.isEmpty) return 'Password is required.';
                    if (text.length < 8) {
                      return 'Password must be at least 8 characters.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: auth.isBusy ? null : _submit,
                  child: auth.isBusy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign up'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    bool obscureText = false,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppSurfaces.innerCard(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppSurfaces.border(context)),
        ),
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
