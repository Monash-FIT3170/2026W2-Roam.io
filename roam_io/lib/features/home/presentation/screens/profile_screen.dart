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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshCurrentUser();
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF171A20) : AppColors.sand;

    final avatarSurfaceColor =
        isDark ? const Color(0xFF151A15) : AppColors.cream;

    // Only the inner Email / Username / Display Name fields use this colour.
    final infoTileColor =
        isDark ? const Color(0xFF242832) : const Color(0xFFF6EBD8);

    final borderColor = colorScheme.primary.withValues(
      alpha: isDark ? 0.24 : 0.12,
    );

    final mutedTextColor = colorScheme.onSurface.withValues(alpha: 0.6);

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
            final darkModeEnabled = profile?.darkModeEnabled ?? false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppPageHeader(
                  title: 'Profile Settings',
                  subtitle: 'Manage your identity and account preferences.',
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: avatarSurfaceColor,
                                  border: Border.all(
                                    color: colorScheme.primary,
                                    width: 1.8,
                                  ),
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 38,
                                  color: colorScheme.primary,
                                ),
                              ),

                              const SizedBox(height: 10),

                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

                              _ProfileInfoTile(
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
                          enabled: darkModeEnabled,
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
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.secondary.withValues(
                                alpha: 0.9,
                              ),
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.12),
        ),
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
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 0,
        ),
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