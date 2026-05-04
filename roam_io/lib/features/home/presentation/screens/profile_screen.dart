import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_surfaces.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/app_toast.dart';
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

  Future<void> _changeProfilePhoto() async {
    final auth = context.read<AuthProvider>();
    if (auth.isBusy) return;

    final XFile? pickedFile;
    try {
      pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.error(
        context,
        'Could not open photo library. Please check photo permissions and try again.',
      );
      return;
    }
    if (pickedFile == null) return;

    await auth.uploadProfilePicture(pickedFile);
    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
      return;
    }

    if (auth.wasLastProfilePhotoUploadUnchanged) {
      AppToast.show(context, 'That photo is already your profile picture.');
      return;
    }

    AppToast.success(context, 'Profile picture updated successfully.');
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

  Future<void> _toggleDarkMode(bool enabled) async {
    final auth = context.read<AuthProvider>();
    await auth.updateDarkModePreference(enabled);

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cardColor = AppSurfaces.card(context);
    final avatarSurfaceColor = AppSurfaces.softCard(context);
    final infoTileColor = AppSurfaces.innerCard(context);
    final borderColor = AppSurfaces.border(context);
    final mutedTextColor = AppSurfaces.textSubtle(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
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
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 76,
                                height: 76,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    GestureDetector(
                                      onTap: auth.isBusy
                                          ? null
                                          : _changeProfilePhoto,
                                      child: Container(
                                        width: 76,
                                        height: 76,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: avatarSurfaceColor,
                                          border: Border.all(
                                            color: colorScheme.primary,
                                            width: 1.8,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: profile?.photoUrl != null
                                              ? Image.network(
                                                  profile!.photoUrl!,
                                                  fit: BoxFit.cover,
                                                  width: 76,
                                                  height: 76,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Icon(
                                                        Icons.person_rounded,
                                                        size: 38,
                                                        color:
                                                            colorScheme.primary,
                                                      ),
                                                )
                                              : Icon(
                                                  Icons.person_rounded,
                                                  size: 38,
                                                  color: colorScheme.primary,
                                                ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: -4,
                                      bottom: -4,
                                      child: Material(
                                        color: cardColor,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: auth.isBusy
                                              ? null
                                              : _changeProfilePhoto,
                                          child: Padding(
                                            padding: const EdgeInsets.all(7),
                                            child: Icon(
                                              Icons.camera_alt_rounded,
                                              size: 16,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              Text(
                                visibleDisplayName.isEmpty
                                    ? 'Display Name'
                                    : visibleDisplayName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),

                              const SizedBox(height: 2),

                              Text(
                                '@$username',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: mutedTextColor,
                                ),
                              ),

                              const SizedBox(height: 14),

                              _ProfileInfoTile(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: email,
                                surfaceColor: infoTileColor,
                              ),

                              const SizedBox(height: 8),

                              _ProfileInfoTile(
                                icon: Icons.alternate_email_rounded,
                                label: 'Username',
                                value: username,
                                surfaceColor: infoTileColor,
                              ),

                              const SizedBox(height: 8),

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
                                      surfaceColor: infoTileColor,
                                    ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        _DarkModePreferenceTile(
                          enabled: auth.darkModeEnabled,
                          onChanged: auth.isBusy || profile == null
                              ? null
                              : _toggleDarkMode,
                        ),

                        const SizedBox(height: 18),

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

                        const SizedBox(height: 10),

                        TextButton.icon(
                          onPressed: auth.isBusy ? null : _logout,
                          icon: Icon(
                            Icons.logout_rounded,
                            size: 15,
                            color: colorScheme.secondary,
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
                              vertical: 2,
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
  final Color surfaceColor;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: colorScheme.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
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

class _DarkModePreferenceTile extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _DarkModePreferenceTile({
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        // Restored to the original dark card colour.
        color: isDark ? const Color(0xFF171A20) : AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
        ),
      ),
      child: SwitchListTile(
        dense: true,
        value: enabled,
        onChanged: onChanged,
        secondary: Icon(
          enabled ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          size: 21,
          color: colorScheme.primary,
        ),
        title: Text(
          'Dark Mode',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Use a darker theme across the app.',
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        activeThumbColor: Colors.white,
        activeTrackColor: colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      ),
    );
  }
}

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
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SizedBox(
        width: 210,
        height: 42,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ),
    );
  }
}
