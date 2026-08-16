/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Firestore persistence for milestone claim state.
 */

import 'package:cloud_firestore/cloud_firestore.dart';

import 'milestone_catalog.dart';
import 'milestone_progress.dart';

/// Reads/writes `profiles/{uid}/milestones/{milestoneId}`.
class MilestoneService {
  MilestoneService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('profiles').doc(uid).collection('milestones');
  }

  Stream<Map<MilestoneId, MilestoneClaimState>> watchClaims(String uid) {
    return _collection(uid).snapshots().map((snapshot) {
      final claims = <MilestoneId, MilestoneClaimState>{};
      for (final doc in snapshot.docs) {
        final id = MilestoneId.fromWire(doc.id);
        if (id == null) continue;
        claims[id] = MilestoneClaimState.fromMap(id, doc.data());
      }
      return claims;
    });
  }

  /// Marks [tier] claimed if not already. Returns false if already claimed.
  Future<bool> claimTier({
    required String uid,
    required MilestoneId milestoneId,
    required int tier,
  }) async {
    final ref = _collection(uid).doc(milestoneId.wireValue);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final existing = MilestoneClaimState.fromMap(
        milestoneId,
        snapshot.data(),
      );
      if (existing.hasClaimed(tier)) {
        return false;
      }

      final next = {...existing.claimedTiers, tier};
      final sorted = next.toList()..sort();
      transaction.set(ref, <String, dynamic>{
        'claimedTiers': sorted,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      return true;
    });
  }

  /// Best-effort rollback if XP award fails after a successful claim write.
  Future<void> unclaimTier({
    required String uid,
    required MilestoneId milestoneId,
    required int tier,
  }) async {
    final ref = _collection(uid).doc(milestoneId.wireValue);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final existing = MilestoneClaimState.fromMap(
        milestoneId,
        snapshot.data(),
      );
      if (!existing.hasClaimed(tier)) return;

      final next = {...existing.claimedTiers}..remove(tier);
      final sorted = next.toList()..sort();
      transaction.set(ref, <String, dynamic>{
        'claimedTiers': sorted,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    });
  }
}
