/// A Party Mode party: two teams competing to claim map tiles.
class Party {
  const Party({
    required this.id,
    required this.joinCode,
    required this.teamAMembers,
    required this.teamBMembers,
  });

  final String id;
  final String joinCode;
  final List<String> teamAMembers;
  final List<String> teamBMembers;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'joinCode': joinCode,
      'teamAMembers': teamAMembers,
      'teamBMembers': teamBMembers,
    };
  }

  factory Party.fromMap(String id, Map<String, dynamic> map) {
    return Party(
      id: id,
      joinCode: map['joinCode'] as String,
      teamAMembers: List<String>.from(map['teamAMembers'] as List? ?? const []),
      teamBMembers: List<String>.from(map['teamBMembers'] as List? ?? const []),
    );
  }
}
