/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 18/05/2026
 * Description:
 *   Unit tests for VisitedPolygonRecord Firestore mapping aliases and date
 *   parsing fallbacks added for ART-68 coverage enforcement.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_record.dart';

void main() {
  group('VisitedPolygonRecord.toMap', () {
    test('writes Firestore field names and timestamp value', () {
      final visitedAt = DateTime(2026, 5, 18, 9);
      final record = VisitedPolygonRecord(
        profileId: 'user-1',
        polygonId: 'polygon-1',
        visitedAt: visitedAt,
      );

      final map = record.toMap();

      expect(map['profile_id'], 'user-1');
      expect(map['polygon_id'], 'polygon-1');
      expect((map['visited_at'] as Timestamp).toDate(), visitedAt);
    });
  });

  group('VisitedPolygonRecord.fromMap', () {
    test('uses user_id as a fallback for profileId', () {
      final visitedAt = DateTime(2026, 5, 18, 10);
      final record = VisitedPolygonRecord.fromMap(<String, dynamic>{
        'user_id': 'user-1',
        'polygon_id': 'polygon-1',
        'visited_at': Timestamp.fromDate(visitedAt),
      });

      expect(record.profileId, 'user-1');
      expect(record.polygonId, 'polygon-1');
      expect(record.visitedAt, visitedAt);
    });

    test('uses userId as a fallback for profileId', () {
      final visitedAt = DateTime(2026, 5, 18, 11);
      final record = VisitedPolygonRecord.fromMap(<String, dynamic>{
        'userId': 'user-2',
        'polygonId': 'polygon-2',
        'lastVisitedAt': visitedAt,
      });

      expect(record.profileId, 'user-2');
      expect(record.polygonId, 'polygon-2');
      expect(record.visitedAt, visitedAt);
    });
  });

  group('VisitedPolygonRecord.parseVisitedAt', () {
    test('falls back to the current time for invalid date strings', () {
      final before = DateTime.now();
      final result = VisitedPolygonRecord.parseVisitedAt('not-a-date');
      final after = DateTime.now();

      expect(result.isBefore(before), isFalse);
      expect(result.isAfter(after), isFalse);
    });

    test('falls back to the current time for unsupported input', () {
      final before = DateTime.now();
      final result = VisitedPolygonRecord.parseVisitedAt(12345);
      final after = DateTime.now();

      expect(result.isBefore(before), isFalse);
      expect(result.isAfter(after), isFalse);
    });
  });
}
