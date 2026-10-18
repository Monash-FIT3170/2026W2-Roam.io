/*
 * Author: n8nunes
 * Last Updated: 18 October 2026
 * Description:
 *   Social leaderboard ranking the signed-in user's group by XP earned over
 *   the last 30 days, with a podium for the top three and Social-style rows
 *   for everyone else.
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_cartoon.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../data/leaderboard_service.dart';
import '../domain/leaderboard_entry.dart';
import '../widgets/social_avatar.dart';
import '../widgets/social_card.dart';
import '../widgets/social_layout.dart';
import '../widgets/social_message.dart';

/// XP leaderboard opened from the Social tab.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.loadEntries, this.currentUserId});

  /// Injected for tests; production loads from [LeaderboardService].
  final Future<List<LeaderboardEntry>> Function()? loadEntries;

  /// Injected for tests; production reads the signed-in Firebase user.
  final String? currentUserId;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _futureEntries;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = widget.currentUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    _futureEntries =
        widget.loadEntries?.call() ?? LeaderboardService().getLeaderboard(_uid);
  }

  void _sortEntries(List<LeaderboardEntry> entries) {
    entries.sort((a, b) => b.xpEarned.compareTo(a.xpEarned));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CartoonPageHeader(
              title: 'Leaderboards',
              soft: true,
              outlineWidth: 1,
              outlineColor: AppSurfaces.border(context),
            ),
            Expanded(
              child: FutureBuilder<List<LeaderboardEntry>>(
                future: _futureEntries,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    debugPrint(
                      '[LeaderboardScreen] load failed: ${snapshot.error}',
                    );
                    return const SocialMessage(
                      'Could not load leaderboards right now.',
                    );
                  }

                  final entries = [...?snapshot.data];
                  _sortEntries(entries);

                  if (entries.isEmpty) {
                    return const SocialMessage(
                      'No activity found in the last 30 days.',
                    );
                  }

                  final podium = entries.take(3).toList();
                  final rest = entries.skip(3).toList();

                  return SocialContentWidth(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        SocialLayout.gutter,
                        0,
                        SocialLayout.gutter,
                        32,
                      ),
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: _PeriodPill(),
                        ),
                        const SizedBox(height: 18),
                        _Podium(entries: podium, currentUserId: _uid),
                        if (rest.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          for (var i = 0; i < rest.length; i++) ...[
                            if (i > 0)
                              const SizedBox(height: SocialLayout.rowGap),
                            _RankRow(
                              rank: i + 4,
                              entry: rest[i],
                              isYou: rest[i].userId == _uid,
                            ),
                          ],
                        ],
                      ],
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

String _xp(LeaderboardEntry entry) => '${entry.xpEarned} XP';

/// Colour for a podium place (1st clay, 2nd sage, 3rd light sage).
Color _placeColour(int rank) => switch (rank) {
  1 => AppColors.clay,
  2 => AppColors.sage,
  _ => AppColors.lightSage,
};

/// Small tinted chip naming the ranking window.
class _PeriodPill extends StatelessWidget {
  const _PeriodPill();

  @override
  Widget build(BuildContext context) {
    final sage = AppSurfaces.isDark(context)
        ? AppColors.lightSage
        : AppColors.sage;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_rounded, size: 14, color: sage),
          const SizedBox(width: 6),
          Text(
            'XP earned · last 30 days',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: sage,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Top-three podium: 2nd on the left, 1st raised in the middle, 3rd right.
class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.currentUserId});

  final List<LeaderboardEntry> entries;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    // Visual order 2-1-3; missing places leave an empty slot so 1st stays
    // centred.
    final order = [2, 1, 3];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 0),
      decoration: SocialCard.decoration(
        context,
      ).copyWith(color: AppSurfaces.softCard(context)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final rank in order)
            Expanded(
              child: rank <= entries.length
                  ? _PodiumPlace(
                      rank: rank,
                      entry: entries[rank - 1],
                      isYou: entries[rank - 1].userId == currentUserId,
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({
    required this.rank,
    required this.entry,
    required this.isYou,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colour = _placeColour(rank);
    final first = rank == 1;
    final blockHeight = switch (rank) {
      1 => 92.0,
      2 => 66.0,
      _ => 48.0,
    };

    return MergeSemantics(
      child: Semantics(
        label: 'Rank $rank',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: first ? 26 : 0,
              child: first
                  ? const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.clay,
                      size: 26,
                      semanticLabel: 'Top leader',
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            SocialAvatar(
              displayName: entry.displayName,
              photoUrl: entry.photoUrl,
              radius: first ? 34 : 26,
              borderWidth: 3,
              borderColor: colour,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                isYou ? '${entry.displayName} (You)' : entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppSurfaces.textPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _xp(entry),
              style: textTheme.bodySmall?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            // The podium block, rounded on top like a stack of blocks.
            Container(
              height: blockHeight,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colour, colour.withValues(alpha: 0.75)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Text(
                '$rank',
                semanticsLabel: '',
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Social-style row for 4th place onwards.
class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.entry,
    required this.isYou,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sage = AppSurfaces.isDark(context)
        ? AppColors.lightSage
        : AppColors.sage;

    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SocialLayout.cardPadding,
          vertical: 12,
        ),
        decoration: SocialCard.decoration(context).copyWith(
          color: AppSurfaces.softCard(context),
          border: Border.all(
            color: isYou ? sage : AppSurfaces.border(context),
            width: isYou ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                semanticsLabel: 'Rank $rank',
                style: textTheme.titleSmall?.copyWith(
                  color: sage,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SocialAvatar(
              displayName: entry.displayName,
              photoUrl: entry.photoUrl,
              radius: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: AppSurfaces.textPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isYou) ...[
              const SizedBox(width: 8),
              Text(
                'You',
                style: textTheme.labelMedium?.copyWith(
                  color: sage,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.clay.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _xp(entry),
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.clay,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
