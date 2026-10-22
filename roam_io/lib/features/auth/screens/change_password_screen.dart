/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Provides the change password screen for authenticated users updating
 *   account credentials from Settings.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_cartoon.dart';
import '../../../theme/app_colours.dart';
import '../../settings/widgets/settings_group.dart';
import '../providers/auth_provider.dart';

/// Screen for changing the current user's password.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Validates password fields and submits the change request.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    await auth.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
      return;
    }

    AppToast.success(context, 'Password updated successfully.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SettingsStyle.background(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CartoonPageHeader(
              title: 'Change Password',
              outlineWidth: SettingsStyle.outlineWidth,
              soft: true,
              outlineColor: SettingsStyle.outline(context),
            ),
            Expanded(
              child: Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: SettingsStyle.card(context),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              decoration: SettingsStyle.input(
                                context,
                                labelText: 'Current password',
                              ),
                              validator: (value) {
                                if ((value ?? '').isEmpty) {
                                  return 'Current password is required.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              decoration: SettingsStyle.input(
                                context,
                                labelText: 'New password',
                              ),
                              validator: (value) {
                                final text = value ?? '';
                                if (text.isEmpty) {
                                  return 'New password is required.';
                                }
                                if (text.length < 8) {
                                  return 'New password must be at least 8 characters.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              decoration: SettingsStyle.input(
                                context,
                                labelText: 'Confirm new password',
                              ),
                              validator: (value) {
                                final text = value ?? '';
                                if (text.isEmpty) {
                                  return 'Please confirm your new password.';
                                }
                                if (text != _newPasswordController.text) {
                                  return 'Passwords do not match.';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 20),
                            CartoonPressable(
                              enabled: !auth.isBusy,
                              soft: true,
                              child: ElevatedButton(
                                onPressed: auth.isBusy ? null : _submit,
                                style:
                                    SettingsStyle.button(
                                      context,
                                      background: AppColors.sage,
                                      foreground: Colors.white,
                                    ).copyWith(
                                      minimumSize: const WidgetStatePropertyAll(
                                        Size.fromHeight(50),
                                      ),
                                    ),
                                child: auth.isBusy
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Update password'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
