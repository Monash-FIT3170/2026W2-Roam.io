/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Provides the dedicated Settings flow for updating the profile display name
 *   while keeping the user on the page after a successful save.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';

/// Dedicated screen for editing the user's display name.
class ChangeDisplayNameScreen extends StatefulWidget {
  const ChangeDisplayNameScreen({super.key});

  @override
  State<ChangeDisplayNameScreen> createState() =>
      _ChangeDisplayNameScreenState();
}

class _ChangeDisplayNameScreenState extends State<ChangeDisplayNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final displayName = context
          .read<AuthProvider>()
          .currentProfile
          ?.displayName;
      _controller.text = displayName ?? '';
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
    await auth.updateDisplayName(_controller.text.trim());
    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
      return;
    }

    final savedName = auth.currentProfile?.displayName;
    if (savedName != null) {
      _controller.text = savedName;
    }
    AppToast.success(context, 'Display name updated.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(title: const Text('Change Display Name')),
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _controller,
                      enabled: !auth.isBusy,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Display name is required.';
                        return null;
                      },
                      onFieldSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: auth.isBusy ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: auth.isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Display Name'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
