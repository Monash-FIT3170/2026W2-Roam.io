/// Rollup counters for fast Stats tab hero numbers.
///
/// Stored at `profiles/{uid}/stats_summary/summary`.
class StatsSummary {
  const StatsSummary({
    this.totalVisits = 0,
    this.uniquePlaces = 0,
    this.totalTiles = 0,
    this.totalAreaSquareMetres = 0,
    this.totalJourneys = 0,
    this.totalDistanceMeters = 0,
    this.totalJourneySeconds = 0,
    this.xpFromVisits = 0,
    this.xpFromTileUnlocks = 0,
    this.xpFromJourneys = 0,
    this.xpFromMilestones = 0,
    this.currentXpStreakDays = 0,
    this.lastXpEarnedDate,
    this.updatedAt,
  });

  final int totalVisits;
  final int uniquePlaces;
  final int totalTiles;
  final double totalAreaSquareMetres;
  final int totalJourneys;
  final double totalDistanceMeters;
  final int totalJourneySeconds;
  final int xpFromVisits;
  final int xpFromTileUnlocks;
  final int xpFromJourneys;
  final int xpFromMilestones;
  final int currentXpStreakDays;
  final DateTime? lastXpEarnedDate;
  final DateTime? updatedAt;

  int get totalXpFromSources =>
      xpFromVisits + xpFromTileUnlocks + xpFromJourneys + xpFromMilestones;

  factory StatsSummary.fromMap(Map<String, dynamic> map) {
    final xpBySource = map['xpBySource'];
    var xpFromVisits = 0;
    var xpFromTileUnlocks = 0;
    var xpFromJourneys = 0;
    var xpFromMilestones = 0;

    if (xpBySource is Map<String, dynamic>) {
      xpFromVisits = (xpBySource['visit'] as num?)?.toInt() ?? 0;
      xpFromTileUnlocks = (xpBySource['tileUnlock'] as num?)?.toInt() ?? 0;
      xpFromJourneys = (xpBySource['journey'] as num?)?.toInt() ?? 0;
      xpFromMilestones = (xpBySource['milestone'] as num?)?.toInt() ?? 0;
    }

    return StatsSummary(
      totalVisits: (map['totalVisits'] as num?)?.toInt() ?? 0,
      uniquePlaces: (map['uniquePlaces'] as num?)?.toInt() ?? 0,
      totalTiles: (map['totalTiles'] as num?)?.toInt() ?? 0,
      totalAreaSquareMetres:
          (map['totalAreaSquareMetres'] as num?)?.toDouble() ?? 0,
      totalJourneys: (map['totalJourneys'] as num?)?.toInt() ?? 0,
      totalDistanceMeters:
          (map['totalDistanceMeters'] as num?)?.toDouble() ?? 0,
      totalJourneySeconds: (map['totalJourneySeconds'] as num?)?.toInt() ?? 0,
      xpFromVisits: xpFromVisits,
      xpFromTileUnlocks: xpFromTileUnlocks,
      xpFromJourneys: xpFromJourneys,
      xpFromMilestones: xpFromMilestones,
      currentXpStreakDays: (map['currentXpStreakDays'] as num?)?.toInt() ?? 0,
      lastXpEarnedDate: DateTime.tryParse(
        map['lastXpEarnedDate'] as String? ?? '',
      ),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
    );
  }
}
