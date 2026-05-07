/*
 * Author: Alvin Liong
 * Last Modified: 3/05/2026
 * Description:
 *   Provides the login screen and navigation to sign-up and password recovery
 *   flows.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/app_toast.dart';
import 'forgot_password_screen.dart';
import '../providers/auth_provider.dart';
import 'signup_screen.dart';

/// Screen for signing in with email and password credentials.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates credentials and submits the sign-in request.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    await auth.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
      return;
    }

    AppToast.success(context, 'Login successful.');
  }

  /// Opens the account registration flow.
  void _openSignup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SignupScreen()));
  }

  /// Opens the password reset flow.
  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Email is required.';
                      if (!text.contains('@') || !text.contains('.')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) {
                      if ((value ?? '').isEmpty) return 'Password is required.';
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: auth.isBusy ? null : _submit,
                    child: auth.isBusy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: auth.isBusy ? null : _openForgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                  TextButton(
                    onPressed: auth.isBusy ? null : _openSignup,
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
