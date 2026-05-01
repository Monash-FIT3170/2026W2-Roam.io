import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/app_page_header.dart';
import '../../../../theme/app_colours.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _displayNameController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.addListener(_handleDisplayNameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshCurrentUser();
    });
  }

  void _handleDisplayNameChanged() {
    if (_isEditing) {
      setState(() {});
    }
  }

  void _startEditing(String displayName) {
    _displayNameController.text = displayName == '-' ? '' : displayName;
    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _saveDisplayName() async {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a name')));
      return;
    }

    final auth = context.read<AuthProvider>();
    await auth.updateDisplayName(displayName);

    if (!mounted) return;

    if (auth.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
      return;
    }

    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.signOut();

    if (!mounted) return;

    if (auth.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
    }
  }

  @override
  void dispose() {
    _displayNameController
      ..removeListener(_handleDisplayNameChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cream,
      child: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final profile = auth.currentProfile;

            if (auth.isBusy && profile == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final email = auth.currentUser?.email ?? '-';
            final username = profile?.username ?? '-';
            final displayName = profile?.displayName ?? '-';
            final visibleDisplayName = _isEditing
                ? _displayNameController.text.trim()
                : displayName;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPageHeader(
                    title: 'Profile Settings',
                    subtitle: 'Manage your identity and account preferences.',
                    trailing: TextButton(
                      onPressed: auth.isBusy || profile == null
                          ? null
                          : _isEditing
                          ? _saveDisplayName
                          : () => _startEditing(displayName),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.sage,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(48, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(_isEditing ? 'Save' : 'Edit'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // 🟫 Profile Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.sand,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppColors.sage.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            children: [
                              // 🔥 Avatar (NOW CREAM)
                              Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.cream,
                                  border: Border.all(
                                    color: AppColors.sage,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 48,
                                  color: AppColors.sage,
                                ),
                              ),

                              const SizedBox(height: 14),

                              Text(
                                visibleDisplayName.isEmpty
                                    ? 'Display Name'
                                    : visibleDisplayName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                '@$username',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink.withValues(alpha: 0.45),
                                ),
                              ),

                              const SizedBox(height: 20),

                              _ProfileInfoTile(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: email,
                              ),

                              const SizedBox(height: 10),

                              _ProfileInfoTile(
                                icon: Icons.alternate_email_rounded,
                                label: 'Username',
                                value: username,
                              ),

                              const SizedBox(height: 10),

                              _isEditing
                                  ? _EditableProfileInfoTile(
                                      icon: Icons.badge_outlined,
                                      label: 'Display Name',
                                      controller: _displayNameController,
                                      enabled: !auth.isBusy,
                                    )
                                  : _ProfileInfoTile(
                                      icon: Icons.badge_outlined,
                                      label: 'Display Name',
                                      value: displayName,
                                    ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 🔥 PRIMARY CTA (SAGE BUTTON)
                        _SecondaryProfileButton(
                          label: 'Change Password',
                          icon: Icons.lock_outline_rounded,
                          onPressed: auth.isBusy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ChangePasswordScreen(),
                                    ),
                                  );
                                },
                        ),

                        const SizedBox(height: 18),

                        // 🔴 Minimal logout
                        TextButton.icon(
                          onPressed: auth.isBusy ? null : _logout,
                          icon: Icon(
                            Icons.logout_rounded,
                            size: 16,
                            color: AppColors.clay,
                          ),
                          label: Text(
                            'Log out',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.clay.withValues(alpha: 0.85),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EditableProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool enabled;

  const _EditableProfileInfoTile({
    required this.icon,
    required this.label,
    required this.controller,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.sage.withValues(alpha: 0.65),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 21, color: AppColors.sage),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sage,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: controller,
                  enabled: enabled,
                  autofocus: true,
                  cursorColor: AppColors.sage,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.cream,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    suffixIcon: Icon(
                      Icons.edit_rounded,
                      size: 18,
                      color: AppColors.sage,
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.sage.withValues(alpha: 0.35),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.sage,
                        width: 1.6,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.sage.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🧾 Info tile
class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🔥 SAGE BUTTON (primary)
class _SecondaryProfileButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SecondaryProfileButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 220,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sage,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
