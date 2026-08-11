/// A labelled value row for source, category, or mode breakdown charts.
class StatsBreakdownItem {
  const StatsBreakdownItem({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;
}

/// A place ranked by visit count for Locations stats.
class TopPlaceEntry {
  const TopPlaceEntry({
    required this.placeName,
    required this.visitCount,
  });

  final String placeName;
  final int visitCount;
}

/// A tile ranked by re-entry count for Tiles stats.
class TopTileEntry {
  const TopTileEntry({
    required this.polygonId,
    required this.displayName,
    required this.entryCount,
  });

  final String polygonId;
  final String displayName;
  final int entryCount;
}

/// Best XP day summary for insight cards.
class BestXpDay {
  const BestXpDay({required this.day, required this.amount});

  final DateTime day;
  final int amount;
}
