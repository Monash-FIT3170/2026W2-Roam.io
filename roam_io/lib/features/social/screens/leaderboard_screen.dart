import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../data/leaderboard_service.dart';
import '../domain/leaderboard_entry.dart';
import '../widgets/social_avatar.dart';
import '../widgets/social_message.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _futureEntries;
  final LeaderboardService _service = LeaderboardService();

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _futureEntries = _service.getLeaderboard(uid);
  }

  String _formatMetric(LeaderboardEntry entry) {
    return '${entry.xpEarned} XP';
  }

  void _sortEntries(List<LeaderboardEntry> entries) {
    entries.sort((a, b) => b.xpEarned.compareTo(a.xpEarned));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(
        title: const Text('Leaderboards'),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppSurfaces.pageBackground(context),
      ),
      body: FutureBuilder<List<LeaderboardEntry>>(
        future: _futureEntries,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return SocialMessage(
              'Error loading leaderboards: ${snapshot.error}',
            );
          }

          final entries = snapshot.data ?? [];
          _sortEntries(entries);

          return Column(
            children: [
              if (entries.isEmpty)
                const Expanded(
                  child: SocialMessage(
                    'No activity found in the last 30 days.',
                  ),
                )
              else ...[
                // Top Leader Highlights
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppSurfaces.card(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppSurfaces.border(context)),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomCenter,
                        clipBehavior: Clip.none,
                        children: [
                          SocialAvatar(
                            displayName: entries.first.displayName,
                            photoUrl: entries.first.photoUrl,
                            radius: 48,
                          ),
                          const Positioned(
                            bottom: -12,
                            child: Icon(
                              Icons.workspace_premium,
                              color: AppColors.clay,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _formatMetric(entries.first),
                        style: textTheme.headlineLarge?.copyWith(
                          fontSize: 32,
                          color: AppSurfaces.textPrimary(context),
                        ),
                      ),
                      Text(
                        '#1 Leader',
                        style: textTheme.labelMedium?.copyWith(
                          fontSize: 14,
                          color: AppSurfaces.textMuted(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entries.first.displayName,
                        textAlign: TextAlign.center,
                        style: textTheme.titleLarge?.copyWith(
                          color: AppSurfaces.textPrimary(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Remaining Users List
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text(
                                '${index + 1}',
                                textAlign: TextAlign.center,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: index == 0
                                      ? AppColors.clay
                                      : AppSurfaces.textPrimary(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SocialAvatar(
                              displayName: entry.displayName,
                              photoUrl: entry.photoUrl,
                              radius: 20,
                            ),
                          ],
                        ),
                        title: Text(
                          entry.displayName,
                          style: textTheme.titleMedium?.copyWith(
                            color: AppSurfaces.textPrimary(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        trailing: Text(
                          _formatMetric(entry),
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppSurfaces.textMuted(context),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
