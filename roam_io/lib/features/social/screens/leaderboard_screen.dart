import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../data/leaderboard_service.dart';
import '../domain/leaderboard_entry.dart';
import '../widgets/social_avatar.dart';

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
    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(
        title: const Text('Leaderboards'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<LeaderboardEntry>>(
        future: _futureEntries,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading leaderboards: ${snapshot.error}'));
          }

          final entries = snapshot.data ?? [];
          _sortEntries(entries);

          return Column(
            children: [
              if (entries.isEmpty)
                const Expanded(
                  child: Center(child: Text('No activity found in the last 30 days.')),
                )
              else ...[
                // Top Leader Highlights
                Container(
                  padding: const EdgeInsets.all(24),
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
                            child: Icon(Icons.workspace_premium, color: Colors.amber, size: 36),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _formatMetric(entries.first),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        '#1 Leader',
                        style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entries.first.displayName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Remaining Users List
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: index == 0 ? Colors.amber : Colors.black87,
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
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Text(
                          _formatMetric(entry),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ]
            ],
          );
        },
      ),
    );
  }
}
