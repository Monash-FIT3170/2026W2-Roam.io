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
import '../../../theme/app_colours.dart';
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
  String? _registrationError;
  bool _passwordVisible = false;

  static final _errorColor = Color.alphaBlend(
    AppColors.ink.withValues(alpha: 0.2),
    AppColors.clay,
  );

  static final _errorTextStyle = TextStyle(
    color: _errorColor,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

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

    setState(() => _registrationError = null);
    final auth = context.read<AuthProvider>();
    await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      username: _usernameController.text.trim(),
      displayName: _displayNameController.text.trim(),
    );

    if (!mounted) return;

    if (auth.errorMessage != null) {
      setState(() => _registrationError = auth.errorMessage);
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
          centerContent: true,
          subtitle:
              'Create your account to unlock visits, earn progress, and save favourites.',
          footerText: 'Already have an account?',
          footerLabel: 'Sign in',
          onFooterTap: auth.isBusy ? null : () => Navigator.of(context).pop(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInputField(
                  controller: _usernameController,
                  label: 'Username',
                  hint: 'Choose a username',
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
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _displayNameController,
                  label: 'Display name',
                  hint: 'Enter your display name',
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Display name is required.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'you@example.com',
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
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'At least 8 characters',
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
                const SizedBox(height: 24),
                FilledButton(
                  style:
                      FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        backgroundColor: AppColors.sage,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Color.alphaBlend(
                          AppColors.sage.withValues(alpha: 0.18),
                          AppColors.cream,
                        ),
                        disabledForegroundColor: AppColors.ink.withValues(
                          alpha: 0.55,
                        ),
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ).copyWith(
                        overlayColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.disabled)) {
                            return Colors.transparent;
                          }
                          if (states.contains(WidgetState.pressed)) {
                            return AppColors.ink.withValues(alpha: 0.18);
                          }
                          if (states.contains(WidgetState.focused)) {
                            return AppColors.ink.withValues(alpha: 0.10);
                          }
                          if (states.contains(WidgetState.hovered)) {
                            return AppColors.ink.withValues(alpha: 0.10);
                          }
                          return Colors.transparent;
                        }),
                        side: WidgetStateProperty.resolveWith((states) {
                          return BorderSide(
                            color:
                                states.contains(WidgetState.focused) &&
                                    !states.contains(WidgetState.disabled)
                                ? AppColors.ink
                                : Colors.transparent,
                            width: 2,
                          );
                        }),
                      ),
                  onPressed: auth.isBusy ? null : _submit,
                  child: auth.isBusy
                      ? Semantics(
                          label: 'Sign up',
                          value: 'Creating account',
                          liveRegion: true,
                          child: const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.sage,
                            ),
                          ),
                        )
                      : const Text('Sign up'),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: _registrationError == null
                      ? const SizedBox.shrink()
                      : Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color.alphaBlend(
                                AppColors.clay.withValues(alpha: 0.08),
                                AppColors.cream,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.clay),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.clay,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _registrationError!,
                                    style: _errorTextStyle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    bool obscureText = false,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.sage.withValues(alpha: 0.5)),
    );
    // Reserve two lines at the user's text scale; longer errors can still grow.
    final errorHeight = MediaQuery.textScalerOf(context).scale(13) * 1.4 * 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            obscureText: obscureText && !_passwordVisible,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: obscureText
                  ? IconButton(
                      tooltip: _passwordVisible
                          ? 'Hide password'
                          : 'Show password',
                      color: AppColors.sage,
                      style: ButtonStyle(
                        side: WidgetStateProperty.resolveWith((states) {
                          return BorderSide(
                            color: states.contains(WidgetState.focused)
                                ? AppColors.ink
                                : Colors.transparent,
                            width: 2,
                          );
                        }),
                      ),
                      onPressed: () {
                        setState(() => _passwordVisible = !_passwordVisible);
                      },
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        semanticLabel: _passwordVisible
                            ? 'Hide password'
                            : 'Show password',
                      ),
                    )
                  : null,
              hintStyle: TextStyle(
                color: AppColors.ink.withValues(alpha: 0.6),
                fontSize: 16,
                height: 1.5,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.all(16),
              filled: true,
              fillColor: AppColors.cream.withValues(alpha: 0.9),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: const BorderSide(color: AppColors.sage, width: 2),
              ),
              errorBorder: border.copyWith(
                borderSide: const BorderSide(color: AppColors.clay, width: 1.5),
              ),
              focusedErrorBorder: border.copyWith(
                borderSide: const BorderSide(color: AppColors.clay, width: 2),
              ),
              helper: SizedBox(height: errorHeight),
              helperStyle: _errorTextStyle,
              errorStyle: _errorTextStyle,
            ),
            errorBuilder: (context, message) => Semantics(
              liveRegion: true,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: errorHeight),
                child: Text(message, style: _errorTextStyle),
              ),
            ),
            validator: validator,
            onFieldSubmitted: onFieldSubmitted,
          ),
        ),
      ],
    );
  }
}
