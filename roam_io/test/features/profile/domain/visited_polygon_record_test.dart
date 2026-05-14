import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_record.dart';

void main() {
  group('VisitedPolygonRecord.fromMap', () {
    test('reads snake_case profile and polygon ids', () {
      final at = DateTime(2026, 3, 15, 12);
      final record = VisitedPolygonRecord.fromMap(<String, dynamic>{
        'profile_id': 'p1',
        'polygon_id': 'poly-a',
        'visited_at': Timestamp.fromDate(at),
      });

      expect(record.profileId, 'p1');
      expect(record.polygonId, 'poly-a');
      expect(record.visitedAt, at);
    });

    test('accepts camelCase legacy keys', () {
      final record = VisitedPolygonRecord.fromMap(<String, dynamic>{
        'profileId': 'legacy-profile',
        'polygonId': 'poly-b',
        'lastVisitedAt': '2026-04-01T08:30:00.000',
      });

      expect(record.profileId, 'legacy-profile');
      expect(record.polygonId, 'poly-b');
      expect(record.visitedAt, DateTime.parse('2026-04-01T08:30:00.000'));
    });

    test('parseVisitedAt handles Timestamp, DateTime, and ISO string', () {
      final t = DateTime(2026, 1, 2);
      expect(VisitedPolygonRecord.parseVisitedAt(Timestamp.fromDate(t)), t);
      expect(VisitedPolygonRecord.parseVisitedAt(t), t);
      expect(
        VisitedPolygonRecord.parseVisitedAt('2026-01-02T00:00:00.000'),
        DateTime.parse('2026-01-02T00:00:00.000'),
      );
    });
  });

  group('VisitedPolygonRecord.toMap', () {
    test('writes snake_case fields for Firestore', () {
      final at = DateTime(2026, 5, 1, 10);
      final record = VisitedPolygonRecord(
        profileId: 'u1',
        polygonId: 'tile-9',
        visitedAt: at,
      );

      final map = record.toMap();
      expect(map['profile_id'], 'u1');
      expect(map['polygon_id'], 'tile-9');
      expect((map['visited_at'] as Timestamp).toDate(), at);
    });
  });
}
