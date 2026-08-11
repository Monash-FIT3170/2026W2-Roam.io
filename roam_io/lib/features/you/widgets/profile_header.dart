import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../../profile/domain/profile_model.dart';
import 'xp_progress_section.dart';

/// Identity header shown on the Profile tab: avatar, XP, and social stats row.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    required this.tileCount,
    required this.journeyCount,
  });

  final ProfileModel? profile;
  final int tileCount;
  final int journeyCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = profile?.displayName ?? '-';
    final username = profile?.username ?? '-';
    final photoUrl = profile?.photoUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppSurfaces.softCard(context),
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary, width: 2),
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person_rounded,
                          color: colorScheme.primary,
                        ),
                      )
                    : Icon(Icons.person_rounded, color: colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppSurfaces.textPrimary(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppSurfaces.textMuted(context),
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  if (profile != null) ...[
                    const SizedBox(height: 4),
                    XpProgressSection(profile: profile!, compact: true),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ProfileStatsRow(
          tileCount: tileCount,
          journeyCount: journeyCount,
        ),
      ],
    );
  }
}

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.tileCount,
    required this.journeyCount,
  });

  final int tileCount;
  final int journeyCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileStat(label: 'Following', value: '0'),
        const ProfileStat(label: 'Followers', value: '0'),
        ProfileStat(label: 'Tiles', value: formatProfileNumber(tileCount)),
        ProfileStat(
          label: 'Journeys',
          value: formatProfileNumber(journeyCount),
        ),
        const ProfileStat(label: 'Sidequests', value: '0'),
      ],
    );
  }
}

class ProfileStat extends StatelessWidget {
  const ProfileStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
                fontSize: 9,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppSurfaces.textPrimary(context),
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String formatProfileNumber(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buffer = StringBuffer(sign);

  for (var index = 0; index < digits.length; index += 1) {
    final digitsRemaining = digits.length - index;
    buffer.write(digits[index]);
    if (digitsRemaining > 1 && digitsRemaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}
