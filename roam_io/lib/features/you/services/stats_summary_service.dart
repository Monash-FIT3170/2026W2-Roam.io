import 'package:cloud_firestore/cloud_firestore.dart';

import '../../profile/domain/stats_summary.dart';
import '../../profile/domain/xp_event.dart';

/// Maintains rollup counters at `profiles/{uid}/stats_summary/summary`.
class StatsSummaryService {
  StatsSummaryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _summaryDoc(String uid) {
    return _firestore
        .collection('profiles')
        .doc(uid)
        .collection('stats_summary')
        .doc('summary');
  }

  Future<StatsSummary?> getSummary(String uid) async {
    final snapshot = await _summaryDoc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return StatsSummary.fromMap(data);
  }

  Stream<StatsSummary> watchSummary(String uid) {
    return _summaryDoc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return const StatsSummary();
      return StatsSummary.fromMap(data);
    });
  }

  Future<void> recordVisit({
    required String uid,
    required bool isFirstVisit,
  }) async {
    final updates = <String, dynamic>{
      'totalVisits': FieldValue.increment(1),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (isFirstVisit) {
      updates['uniquePlaces'] = FieldValue.increment(1);
    }
    await _summaryDoc(uid).set(updates, SetOptions(merge: true));
  }

  Future<void> recordTileUnlock({
    required String uid,
    required double areaSquareMetres,
  }) async {
    final updates = <String, dynamic>{
      'totalTiles': FieldValue.increment(1),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (areaSquareMetres > 0) {
      updates['totalAreaSquareMetres'] = FieldValue.increment(areaSquareMetres);
    }
    await _summaryDoc(uid).set(updates, SetOptions(merge: true));
  }

  Future<void> recordJourney({
    required String uid,
    required double distanceMeters,
    required int durationSeconds,
  }) async {
    await _summaryDoc(uid).set(<String, dynamic>{
      'totalJourneys': FieldValue.increment(1),
      'totalDistanceMeters': FieldValue.increment(distanceMeters),
      'totalJourneySeconds': FieldValue.increment(durationSeconds),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> recordXpAward({
    required String uid,
    required int amount,
    required XpEventSource source,
    required DateTime earnedAt,
  }) async {
    if (amount <= 0) return;

    final sourceField = switch (source) {
      XpEventSource.visit => 'xpBySource.visit',
      XpEventSource.tileUnlock => 'xpBySource.tileUnlock',
      XpEventSource.journey => 'xpBySource.journey',
      XpEventSource.milestone => 'xpBySource.milestone',
      XpEventSource.unknown => null,
    };

    if (sourceField == null) return;

    final earnedDate = DateTime(
      earnedAt.year,
      earnedAt.month,
      earnedAt.day,
    );

    await _firestore.runTransaction((transaction) async {
      final ref = _summaryDoc(uid);
      final snapshot = await transaction.get(ref);
      final data = snapshot.data() ?? <String, dynamic>{};

      final lastDateRaw = data['lastXpEarnedDate'] as String?;
      final lastDate = lastDateRaw == null
          ? null
          : DateTime.tryParse(lastDateRaw);
      final lastDateOnly = lastDate == null
          ? null
          : DateTime(lastDate.year, lastDate.month, lastDate.day);

      var streak = (data['currentXpStreakDays'] as num?)?.toInt() ?? 0;
      if (lastDateOnly == null) {
        streak = 1;
      } else if (earnedDate.isAtSameMomentAs(lastDateOnly)) {
        streak = streak <= 0 ? 1 : streak;
      } else if (earnedDate.difference(lastDateOnly).inDays == 1) {
        streak += 1;
      } else {
        streak = 1;
      }

      transaction.set(ref, <String, dynamic>{
        sourceField: FieldValue.increment(amount),
        'currentXpStreakDays': streak,
        'lastXpEarnedDate': earnedDate.toIso8601String(),
        'updatedAt': earnedAt.toIso8601String(),
      }, SetOptions(merge: true));
    });
  }
}
