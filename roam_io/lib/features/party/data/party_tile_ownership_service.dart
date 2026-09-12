import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Ownership derivation gate: mirrors deriveOwnership in
/// functions/party_dwell.js (30s testing gate, higher-cumulative-total wins).
/// Kept in sync manually; the server is the source of truth for the same rule.
const int claimGateSeconds = 30;

String? deriveOwnership(Map<String, dynamic>? data) {
  if (data == null) return null;
  final teamA = (data['teamADwellSeconds'] as num?)?.toDouble() ?? 0;
  final teamB = (data['teamBDwellSeconds'] as num?)?.toDouble() ?? 0;
  final aEligible = teamA > claimGateSeconds;
  final bEligible = teamB > claimGateSeconds;

  if (!aEligible && !bEligible) return null;
  if (aEligible && !bEligible) return 'A';
  if (bEligible && !aEligible) return 'B';
  return teamA >= teamB ? 'A' : 'B';
}

/// Stored dwell counter and team state for a single party tile.
class PartyTileData {
  const PartyTileData({
    required this.tileId,
    required this.teamADwellSeconds,
    required this.teamBDwellSeconds,
    this.lastPingByUser = const {},
  });

  final String tileId;
  final double teamADwellSeconds;
  final double teamBDwellSeconds;
  final Map<String, dynamic> lastPingByUser;

  String? get owningTeam => deriveOwnership({
    'teamADwellSeconds': teamADwellSeconds,
    'teamBDwellSeconds': teamBDwellSeconds,
  });

  double teamDwellSeconds(String team) {
    if (team == 'A') return teamADwellSeconds;
    if (team == 'B') return teamBDwellSeconds;
    return 0.0;
  }

  factory PartyTileData.fromMap(String tileId, Map<String, dynamic>? data) {
    if (data == null) {
      return PartyTileData(
        tileId: tileId,
        teamADwellSeconds: 0,
        teamBDwellSeconds: 0,
      );
    }
    return PartyTileData(
      tileId: tileId,
      teamADwellSeconds: (data['teamADwellSeconds'] as num?)?.toDouble() ?? 0,
      teamBDwellSeconds: (data['teamBDwellSeconds'] as num?)?.toDouble() ?? 0,
      lastPingByUser: Map<String, dynamic>.from(
        data['lastPingByUser'] as Map? ?? const {},
      ),
    );
  }
}

/// Watches a party's tile ownership, live, for the map overlay.
class PartyTileOwnershipService {
  PartyTileOwnershipService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<Map<String, String?>> watchOwnership(String partyId) {
    return watchTileData(partyId).map((tiles) {
      return <String, String?>{
        for (final entry in tiles.entries) entry.key: entry.value.owningTeam,
      };
    });
  }

  Stream<Map<String, PartyTileData>> watchTileData(String partyId) {
    return _firestore
        .collection('parties')
        .doc(partyId)
        .collection('tiles')
        .snapshots()
        .map((snapshot) {
          return <String, PartyTileData>{
            for (final doc in snapshot.docs)
              doc.id: PartyTileData.fromMap(doc.id, doc.data()),
          };
        });
  }
}
