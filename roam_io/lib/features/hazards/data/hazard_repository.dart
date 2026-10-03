import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/hazard_category.dart';
import '../domain/hazard_report.dart';

/// Firestore access for community hazards.
class HazardRepository {
  HazardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _hazards =>
      _firestore.collection('hazards');

  /// Watches hazards active at [cutoff]. Consumers still prune against their
  /// current clock because a Firestore query does not advance with time.
  Stream<List<HazardReport>> watchActiveHazards({required DateTime cutoff}) {
    return _hazards
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .snapshots()
        .map((snapshot) {
          if (kDebugMode) {
            debugPrint(
              '[HazardRepository] Active hazard snapshot: '
              '${snapshot.docs.length} document(s)',
            );
          }
          return snapshot.docs
              .map(HazardReport.fromFirestore)
              .toList(growable: false);
        });
  }

  Future<HazardReport> createHazard({
    required String reporterId,
    required HazardCategory category,
    required double latitude,
    required double longitude,
    required DateTime createdAt,
    required Duration expiryDuration,
    String? description,
    String? photoUrl,
    String? photoStoragePath,
  }) async {
    final document = _hazards.doc();
    final cleanDescription = description?.trim();
    final report = HazardReport(
      id: document.id,
      reporterId: reporterId,
      category: category,
      latitude: latitude,
      longitude: longitude,
      description: cleanDescription == null || cleanDescription.isEmpty
          ? null
          : cleanDescription,
      photoUrl: photoUrl,
      photoStoragePath: photoStoragePath,
      createdAt: createdAt,
      lastConfirmedAt: createdAt,
      expiresAt: createdAt.add(expiryDuration),
    );
    await document.set(report.toFirestore());
    if (kDebugMode) {
      debugPrint(
        '[HazardRepository] Hazard document created: '
        'id=${report.id}, lat=${report.latitude}, lng=${report.longitude}, '
        'expiresAt=${report.expiresAt.toIso8601String()}',
      );
    }
    return report;
  }

  Future<void> confirmHazard({
    required String hazardId,
    required DateTime confirmedAt,
    required Duration expiryDuration,
  }) {
    return _hazards.doc(hazardId).update(<String, dynamic>{
      'lastConfirmedAt': Timestamp.fromDate(confirmedAt),
      'expiresAt': Timestamp.fromDate(confirmedAt.add(expiryDuration)),
    });
  }
}
