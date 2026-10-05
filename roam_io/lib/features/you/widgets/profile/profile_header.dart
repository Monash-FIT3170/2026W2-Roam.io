/*
 * Author: Amarprit Singh
 * Last Updated: 5 October 2026
 * Description:
 *   Compact identity row for the Profile tab: avatar, name, handle, an
 *   optional bio line, and tappable inline counts such as Following and
 *   Followers, with Edit Profile kept small and secondary.
 */

import 'package:flutter/material.dart';

import '../../../../theme/app_surfaces.dart';
import '../../../social/widgets/social_avatar.dart';
import 'stat_block.dart';

/// One tappable "12 Following"-style count in the header.
class ProfileHeaderStat {
  const ProfileHeaderStat({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.username,
    this.photoUrl,
    this.bio,
    this.stats = const <ProfileHeaderStat>[],
    this.onEditProfile,
  });

  final String displayName;
  final String username;
  final String? photoUrl;

  /// One line of location or bio. Profiles have no such field yet, so the
  /// line stays hidden until one is passed.
  final String? bio;
  final List<ProfileHeaderStat> stats;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bioText = bio?.trim();
    // At large system text sizes the button no longer fits beside the name,
    // so it drops below the counts instead.
    final editBesideName = MediaQuery.textScalerOf(context).scale(10) <= 13;
    final editButton = onEditProfile == null
        ? null
        : _EditProfileButton(onPressed: onEditProfile!);

    return Row(
      children: [
        SocialAvatar(
          displayName: displayName,
          photoUrl: photoUrl,
          radius: 28,
          borderWidth: 1.5,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppSurfaces.textPrimary(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (editButton != null && editBesideName) editButton,
                ],
              ),
              Text(
                '@$username',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (bioText != null && bioText.isNotEmpty)
                Text(
                  bioText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 14,
                  runSpacing: 2,
                  children: [
                    for (final stat in stats) _HeaderStatPair(stat: stat),
                  ],
                ),
              ],
              if (editButton != null && !editBesideName) ...[
                const SizedBox(height: 4),
                editButton,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderStatPair extends StatelessWidget {
  const _HeaderStatPair({required this.stat});

  final ProfileHeaderStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stat.value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppSurfaces.textPrimary(context),
              fontWeight: FontWeight.w800,
              fontFeatures: kTabularFigures,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            stat.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    final onTap = stat.onTap;
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: content,
    );
  }
}

/// Secondary action: muted, borderless and small, so it does not compete
/// with the name beside it.
class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.edit_outlined, size: 14),
      label: const Text('Edit Profile'),
      style: TextButton.styleFrom(
        foregroundColor: AppSurfaces.textMuted(context),
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
