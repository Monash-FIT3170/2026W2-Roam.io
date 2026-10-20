/// A persisted Party Mode season summary (no per-tile/per-user breakdown).
class PartySeason {
  const PartySeason({
    required this.id,
    required this.teamAMembers,
    required this.teamBMembers,
    required this.teamATileCount,
    required this.teamBTileCount,
    required this.winner,
    required this.startAt,
    required this.endAt,
  });

  final String id;
  final List<String> teamAMembers;
  final List<String> teamBMembers;
  final int teamATileCount;
  final int teamBTileCount;
  final String? winner;
  final DateTime? startAt;
  final DateTime endAt;

  factory PartySeason.fromMap(String id, Map<String, dynamic> map) {
    return PartySeason(
      id: id,
      teamAMembers: List<String>.from(map['teamAMembers'] as List? ?? const []),
      teamBMembers: List<String>.from(map['teamBMembers'] as List? ?? const []),
      teamATileCount: map['teamATileCount'] as int? ?? 0,
      teamBTileCount: map['teamBTileCount'] as int? ?? 0,
      winner: map['winner'] as String?,
      startAt: map['startAt'] != null
          ? DateTime.parse(map['startAt'] as String)
          : null,
      endAt: DateTime.parse(map['endAt'] as String),
    );
  }
}
