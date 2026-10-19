import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/party_season.dart';

/// Reads persisted Party Mode season summaries at `parties/{partyId}/seasons`.
class PartySeasonService {
  PartySeasonService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<PartySeason>> watchSeasons(String partyId) {
    return _firestore
        .collection('parties')
        .doc(partyId)
        .collection('seasons')
        .orderBy('endAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PartySeason.fromMap(doc.id, doc.data()))
              .toList();
        });
  }
}
