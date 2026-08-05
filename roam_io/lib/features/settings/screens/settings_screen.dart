/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Provides the row-based Settings screen for account identity, account edit
 *   navigation, profile photo updates, standalone session actions, and app
 *   preferences.
 */

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/change_password_screen.dart';
import '../widgets/settings_group.dart';
import 'change_display_name_screen.dart';
import 'change_email_screen.dart';
import 'change_username_screen.dart';

/// Screen for viewing and updating the current user's account settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshCurrentUser();
    });
  }

  /// Opens the image picker and uploads a changed profile photo.
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

  /// Signs out the current user.
  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.signOut();

    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
    }
  }

  /// Persists the user's dark mode preference.
  Future<void> _toggleDarkMode(bool enabled) async {
    final auth = context.read<AuthProvider>();
    await auth.updateDarkModePreference(enabled);

    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppSurfaces.pageBackground(context),
      child: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final profile = auth.currentProfile;

            if (auth.isBusy && profile == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final username = profile?.username ?? '-';
            final displayName = profile?.displayName ?? '-';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppPageHeader(title: 'Settings'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 118),
                    child: Column(
                      children: [
                        _AccountHeader(
                          displayName: displayName,
                          username: username,
                          photoUrl: profile?.photoUrl,
                          isBusy: auth.isBusy,
                          onPhotoTap: _changeProfilePhoto,
                        ),
                        const SizedBox(height: 22),
                        SettingsGroup(
                          title: 'Account',
                          children: [
                            SettingsRow(
                              icon: Icons.badge_outlined,
                              title: 'Change Display Name',
                              onTap: auth.isBusy
                                  ? null
                                  : () =>
                                        _open(const ChangeDisplayNameScreen()),
                            ),
                            SettingsRow(
                              icon: Icons.alternate_email_rounded,
                              title: 'Change Username',
                              onTap: auth.isBusy
                                  ? null
                                  : () => _open(const ChangeUsernameScreen()),
                            ),
                            SettingsRow(
                              icon: Icons.email_outlined,
                              title: 'Change Email',
                              onTap: auth.isBusy
                                  ? null
                                  : () => _open(const ChangeEmailScreen()),
                            ),
                            SettingsRow(
                              icon: Icons.lock_outline_rounded,
                              title: 'Change Password',
                              onTap: auth.isBusy
                                  ? null
                                  : () => _open(const ChangePasswordScreen()),
                              showDivider: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        SettingsGroup(
                          title: 'Preferences',
                          children: [
                            SettingsRow(
                              icon: Icons.dark_mode_outlined,
                              title: 'Dark Mode',
                              showChevron: false,
                              showDivider: false,
                              trailing: Switch(
                                value: auth.darkModeEnabled,
                                onChanged: auth.isBusy || profile == null
                                    ? null
                                    : _toggleDarkMode,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Center(
                          child: TextButton.icon(
                            onPressed: auth.isBusy ? null : _logout,
                            icon: Icon(
                              Icons.logout_rounded,
                              color: theme.colorScheme.error,
                              size: 18,
                            ),
                            label: Text(
                              'Log out',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              minimumSize: const Size(120, 44),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.displayName,
    required this.username,
    required this.photoUrl,
    required this.isBusy,
    required this.onPhotoTap,
  });

  final String displayName;
  final String username;
  final String? photoUrl;
  final bool isBusy;
  final VoidCallback onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: AppSurfaces.softCard(context),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: isBusy ? null : onPhotoTap,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.primary, width: 2),
                    ),
                    child: ClipOval(
                      child: photoUrl != null && photoUrl!.isNotEmpty
                          ? Image.network(
                              photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _AvatarFallback(color: colorScheme.primary),
                            )
                          : _AvatarFallback(color: colorScheme.primary),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Material(
                  color: AppSurfaces.card(context),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: isBusy ? null : onPhotoTap,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppSurfaces.textPrimary(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@$username',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.person_rounded, size: 38, color: color);
  }
}
