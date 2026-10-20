/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 06/10/2026
 * Description:
 *   Provides the row-based Settings screen for account identity, account edit
 *   navigation, profile photo updates, privacy, session actions, and app
 *   preferences.
 */

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_cartoon.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../../theme/app_theme_mode.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/change_password_screen.dart';
import '../../map/fog/fog_decay_difficulty.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../../roammate/services/roammate_voice_service.dart';
import '../widgets/settings_group.dart';
import 'change_display_name_screen.dart';
import 'change_email_screen.dart';
import 'change_username_screen.dart';

/// Screen for viewing and updating the current user's account settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.showPageHeader = true});

  /// The bottom-navigation destination owns its header. Embedded edit routes
  /// can hide it and provide a standard app bar with a back affordance.
  final bool showPageHeader;

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

  /// Lets the user choose and persists a fixed or time-aware appearance.
  Future<void> _chooseThemeMode() async {
    final auth = context.read<AuthProvider>();
    if (auth.isBusy || auth.currentProfile == null) return;

    final selectedMode = await showModalBottomSheet<AppThemeMode>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: SettingsStyle.background(context),
      builder: (sheetContext) => _ThemeModeSheet(
        selectedMode: auth.themeMode,
        onSelected: (mode) => Navigator.of(sheetContext).pop(mode),
      ),
    );

    if (selectedMode == null || selectedMode == auth.themeMode) return;

    await auth.updateThemeModePreference(selectedMode);

    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
    }
  }

  /// Lets the user choose how quickly explored areas can become fogged again.
  Future<void> _chooseFogDecayDifficulty() async {
    final auth = context.read<AuthProvider>();
    if (auth.isBusy || auth.currentProfile == null) return;

    final selectedDifficulty = await showModalBottomSheet<FogDecayDifficulty>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: SettingsStyle.background(context),
      builder: (sheetContext) => _FogDecayDifficultySheet(
        selectedDifficulty: auth.fogDecayDifficulty,
        onSelected: (difficulty) => Navigator.of(sheetContext).pop(difficulty),
      ),
    );

    if (selectedDifficulty == null ||
        selectedDifficulty == auth.fogDecayDifficulty) {
      return;
    }

    await auth.updateFogDecayDifficulty(selectedDifficulty);
    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
    }
  }

  /// Enables or disables spoken Roammate messages.
  Future<void> _toggleRoammateVoice(bool enabled) async {
    final auth = context.read<AuthProvider>();

    // Stop immediately when the user opts out, without waiting for Firestore.
    if (!enabled) {
      await RoammateVoiceService.instance.stop();
    }

    await auth.updateRoammateVoicePreference(enabled);

    if (!mounted) return;

    if (auth.errorMessage != null) {
      AppToast.error(context, auth.errorMessage!);
    }
  }

  /// Persists whether the account requires approval for new followers.
  Future<void> _togglePrivateAccount(bool enabled) async {
    final auth = context.read<AuthProvider>();
    await auth.updateSocialPrivacy(
      auth.socialPrivacy.copyWith(isPrivateAccount: enabled),
    );

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
      color: SettingsStyle.background(context),
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
                if (widget.showPageHeader)
                  CartoonPageHeader(
                    title: 'Settings',
                    showBrand: true,
                    outlineWidth: SettingsStyle.outlineWidth,
                    soft: true,
                    outlineColor: SettingsStyle.outline(context),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      widget.showPageHeader ? 4 : 16,
                      20,
                      118,
                    ),
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
                              icon: Icons.badge_rounded,
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
                              icon: Icons.mail_rounded,
                              title: 'Change Email',
                              onTap: auth.isBusy
                                  ? null
                                  : () => _open(const ChangeEmailScreen()),
                            ),
                            SettingsRow(
                              icon: Icons.lock_rounded,
                              title: 'Change Password',
                              onTap: auth.isBusy
                                  ? null
                                  : () => _open(const ChangePasswordScreen()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        SettingsGroup(
                          title: 'Preferences',
                          children: [
                            SettingsRow(
                              icon: Icons.palette_rounded,
                              title: 'Appearance',
                              onTap: auth.isBusy || profile == null
                                  ? null
                                  : _chooseThemeMode,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _themeModeLabel(auth.themeMode),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppSurfaces.textMuted(context),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 22,
                                    color: AppSurfaces.textSubtle(context),
                                  ),
                                ],
                              ),
                            ),
                            SettingsRow(
                              icon: Icons.record_voice_over_rounded,
                              title: 'Roammate Voice',
                              showChevron: false,
                              trailing: Switch(
                                key: const ValueKey<String>(
                                  'roammate-voice-switch',
                                ),
                                trackOutlineColor: WidgetStatePropertyAll(
                                  SettingsStyle.outline(context),
                                ),
                                value: auth.roammateVoiceEnabled,
                                onChanged: auth.isBusy || profile == null
                                    ? null
                                    : _toggleRoammateVoice,
                              ),
                            ),
                            SettingsRow(
                              icon: Icons.cloud_rounded,
                              title: 'Fog Decay Difficulty',
                              onTap: auth.isBusy || profile == null
                                  ? null
                                  : _chooseFogDecayDifficulty,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _fogDecayDifficultyLabel(
                                      auth.fogDecayDifficulty,
                                    ),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppSurfaces.textMuted(context),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 22,
                                    color: AppSurfaces.textSubtle(context),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        SettingsGroup(
                          title: 'Privacy',
                          children: [
                            SettingsRow(
                              icon: Icons.visibility_off_rounded,
                              title: 'Private Account',
                              showChevron: false,
                              trailing: Switch(
                                trackOutlineColor: WidgetStatePropertyAll(
                                  SettingsStyle.outline(context),
                                ),
                                value: auth.socialPrivacy.isPrivateAccount,
                                onChanged: auth.isBusy || profile == null
                                    ? null
                                    : _togglePrivateAccount,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        SettingsGroup(
                          title: 'Help',
                          children: [
                            SettingsRow(
                              icon: Icons.auto_stories_rounded,
                              title: 'View tutorial',
                              onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (tutorialContext) =>
                                      OnboardingScreen(
                                        onComplete: () =>
                                            Navigator.of(tutorialContext).pop(),
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Center(
                          child: CartoonPressable(
                            enabled: !auth.isBusy,
                            flat: true,
                            child: TextButton.icon(
                              onPressed: auth.isBusy ? null : _logout,
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: const Text('Log out'),
                              style: SettingsStyle.button(
                                context,
                                background: Colors.transparent,
                                foreground: theme.colorScheme.error,
                                height: 46,
                              ),
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

String _themeModeLabel(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
    AppThemeMode.dynamic => 'Dynamic',
  };
}

String _fogDecayDifficultyLabel(FogDecayDifficulty difficulty) {
  return switch (difficulty) {
    FogDecayDifficulty.monthly => 'Monthly',
    FogDecayDifficulty.quarterly => 'Quarterly',
    FogDecayDifficulty.yearly => 'Yearly',
  };
}

class _FogDecayDifficultySheet extends StatelessWidget {
  const _FogDecayDifficultySheet({
    required this.selectedDifficulty,
    required this.onSelected,
  });

  final FogDecayDifficulty selectedDifficulty;
  final ValueChanged<FogDecayDifficulty> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fog Decay Difficulty',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose how long explored areas remain clear before fog can return.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppSurfaces.textMuted(context),
            ),
          ),
          const SizedBox(height: 16),
          for (final difficulty in FogDecayDifficulty.values)
            _FogDecayDifficultyOption(
              difficulty: difficulty,
              title: _fogDecayDifficultyLabel(difficulty),
              subtitle: switch (difficulty) {
                FogDecayDifficulty.monthly =>
                  'Fog can return after about 1 month',
                FogDecayDifficulty.quarterly =>
                  'Fog can return after about 3 months',
                FogDecayDifficulty.yearly =>
                  'Fog can return after about 1 year',
              },
              selected: selectedDifficulty == difficulty,
              onTap: onSelected,
            ),
        ],
      ),
    );
  }
}

class _FogDecayDifficultyOption extends StatelessWidget {
  const _FogDecayDifficultyOption({
    required this.difficulty,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final FogDecayDifficulty difficulty;
  final String title;
  final String subtitle;
  final bool selected;
  final ValueChanged<FogDecayDifficulty> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppSurfaces.cardShadow(context),
        ),
        child: Material(
          color: selected
              ? AppColors.sage.withValues(alpha: 0.1)
              : SettingsStyle.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected ? AppColors.sage : SettingsStyle.outline(context),
              width: selected ? 1.75 : SettingsStyle.outlineWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: ValueKey<String>(
              'fog-decay-${difficulty.storageValue.toLowerCase()}',
            ),
            onTap: () => onTap(difficulty),
            leading: Icon(
              Icons.cloud_outlined,
              color: selected
                  ? theme.colorScheme.primary
                  : AppSurfaces.textPrimary(context),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(subtitle),
            trailing: selected
                ? const Icon(Icons.check_circle_rounded, color: AppColors.sage)
                : Icon(
                    Icons.circle_outlined,
                    color: AppSurfaces.textSubtle(context),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ThemeModeSheet extends StatelessWidget {
  const _ThemeModeSheet({required this.selectedMode, required this.onSelected});

  final AppThemeMode selectedMode;
  final ValueChanged<AppThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose how Roam.io colours the app, map, and clouds.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppSurfaces.textMuted(context),
            ),
          ),
          const SizedBox(height: 16),
          _ThemeModeOption(
            mode: AppThemeMode.light,
            icon: Icons.light_mode_outlined,
            title: 'Light',
            subtitle: 'Always use the daytime appearance',
            selected: selectedMode == AppThemeMode.light,
            onTap: onSelected,
          ),
          _ThemeModeOption(
            mode: AppThemeMode.dark,
            icon: Icons.dark_mode_outlined,
            title: 'Dark',
            subtitle: 'Always use the low-light appearance',
            selected: selectedMode == AppThemeMode.dark,
            onTap: onSelected,
          ),
          _ThemeModeOption(
            mode: AppThemeMode.dynamic,
            icon: Icons.brightness_auto_outlined,
            title: 'Dynamic',
            subtitle: 'Light from 6 AM to 6 PM, dark overnight',
            selected: selectedMode == AppThemeMode.dynamic,
            onTap: onSelected,
          ),
        ],
      ),
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final ValueChanged<AppThemeMode> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppSurfaces.cardShadow(context),
        ),
        child: Material(
          color: selected
              ? AppColors.sage.withValues(alpha: 0.1)
              : SettingsStyle.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected ? AppColors.sage : SettingsStyle.outline(context),
              width: selected ? 1.75 : SettingsStyle.outlineWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: ValueKey<String>('theme-mode-${mode.storageValue}'),
            onTap: () => onTap(mode),
            leading: Icon(
              icon,
              color: selected
                  ? theme.colorScheme.primary
                  : AppSurfaces.textPrimary(context),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(subtitle),
            trailing: selected
                ? const Icon(Icons.check_circle_rounded, color: AppColors.sage)
                : Icon(
                    Icons.circle_outlined,
                    color: AppSurfaces.textSubtle(context),
                  ),
          ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: SettingsStyle.surface(context),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: isBusy ? null : onPhotoTap,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: SettingsStyle.outline(context),
                          width: SettingsStyle.outlineWidth,
                        ),
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
                  right: -4,
                  bottom: -4,
                  child: Material(
                    color: AppColors.sage,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: SettingsStyle.outline(context),
                        width: SettingsStyle.outlineWidth,
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isBusy ? null : onPhotoTap,
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 15,
                          color: Colors.white,
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
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppSurfaces.isDark(context)
                        ? AppColors.lightSage
                        : AppColors.sage,
                    fontWeight: FontWeight.w500,
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

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.person_rounded, size: 38, color: color);
  }
}
