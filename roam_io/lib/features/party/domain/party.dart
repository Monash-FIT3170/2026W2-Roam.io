import '../data/party_tile_ownership_service.dart';

/// A Party Mode party: two teams competing to claim map tiles.
class Party {
  const Party({
    required this.id,
    required this.joinCode,
    required this.teamAMembers,
    required this.teamBMembers,
    this.tiles = const <String, dynamic>{},
  });

  final String id;
  final String joinCode;
  final List<String> teamAMembers;
  final List<String> teamBMembers;
  final Map<String, dynamic> tiles;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'joinCode': joinCode,
      'teamAMembers': teamAMembers,
      'teamBMembers': teamBMembers,
      'tiles': tiles,
    };
  }

  factory Party.fromMap(String id, Map<String, dynamic> map) {
    return Party(
      id: id,
      joinCode: (map['joinCode'] as String?) ?? '',
      teamAMembers: List<String>.from(map['teamAMembers'] as List? ?? const []),
      teamBMembers: List<String>.from(map['teamBMembers'] as List? ?? const []),
      tiles: Map<String, dynamic>.from(map['tiles'] as Map? ?? const {}),
    );
  }

  /// Ownership by tile ID derived from the party's stored tiles map.
  Map<String, String?> get tileOwnership {
    final result = <String, String?>{};
    for (final entry in tiles.entries) {
      if (entry.value is Map) {
        final data = Map<String, dynamic>.from(entry.value as Map);
        result[entry.key] = deriveOwnership(data);
      }
    }
    return result;
  }

  /// Returns 'A' or 'B' if [uid] is in that team, or null if not a member.
  String? teamForUser(String uid) {
    if (teamAMembers.contains(uid)) return 'A';
    if (teamBMembers.contains(uid)) return 'B';
    return null;
  }

  /// Whether [uid] belongs to either team in this party.
  bool isMember(String uid) => teamForUser(uid) != null;

  /// Total count of members across both teams.
  int get totalMembers => teamAMembers.length + teamBMembers.length;
}
