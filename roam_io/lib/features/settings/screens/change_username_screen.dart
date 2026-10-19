/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Provides the dedicated Settings flow for updating the profile username
 *   while keeping the user on the page after a successful save.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_cartoon.dart';
import '../../../theme/app_colours.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/settings_group.dart';

/// Dedicated screen for editing the user's username.
class ChangeUsernameScreen extends StatefulWidget {
  const ChangeUsernameScreen({super.key});

  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final username = context.read<AuthProvider>().currentProfile?.username;
      _controller.text = username ?? '';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    await auth.updateUsername(_controller.text.trim());
    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
      return;
    }

    final savedUsername = auth.currentProfile?.username;
    if (savedUsername != null) {
      _controller.text = savedUsername;
    }
    AppToast.success(context, 'Username updated.');
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
              title: 'Change Username',
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
                              controller: _controller,
                              enabled: !auth.isBusy,
                              textInputAction: TextInputAction.done,
                              decoration: SettingsStyle.input(
                                context,
                                labelText: 'Username',
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) {
                                  return 'Username is required.';
                                }
                                if (text.length < 3) {
                                  return 'Username must be at least 3 characters.';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _save(),
                            ),
                            const SizedBox(height: 20),
                            CartoonPressable(
                              enabled: !auth.isBusy,
                              soft: true,
                              child: ElevatedButton(
                                onPressed: auth.isBusy ? null : _save,
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
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save Username'),
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
