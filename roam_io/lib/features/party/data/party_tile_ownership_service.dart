import 'package:cloud_firestore/cloud_firestore.dart';

/// Ownership derivation gate: mirrors deriveOwnership in
/// functions/party_dwell.js (5-minute gate, higher-cumulative-total wins).
/// Kept in sync manually; the server is the source of truth for the same rule.
const int claimGateSeconds = 5 * 60;

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

/// Watches a party's tile ownership, live, for the map overlay.
class PartyTileOwnershipService {
  PartyTileOwnershipService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<Map<String, String?>> watchOwnership(String partyId) {
    return _firestore
        .collection('parties')
        .doc(partyId)
        .collection('tiles')
        .snapshots()
        .map((snapshot) {
          return <String, String?>{
            for (final doc in snapshot.docs) doc.id: deriveOwnership(doc.data()),
          };
        });
  }
}
