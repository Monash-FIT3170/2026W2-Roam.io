class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.xpEarned,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
  final int xpEarned;
}
