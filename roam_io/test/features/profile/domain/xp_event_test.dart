/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Unit tests for XP event serialisation and source wire values used by
 *   timestamped XP history.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/xp_event.dart';

void main() {
  group('XpEvent', () {
    test('round-trips through Firestore map form', () {
      final earnedAt = DateTime(2026, 8, 3, 10, 7);
      final event = XpEvent(
        id: 'evt-1',
        amount: 50,
        earnedAt: earnedAt,
        source: XpEventSource.visit,
        sourceId: 'place-9',
      );

      final restored = XpEvent.fromMap(event.id, event.toMap());

      expect(restored.id, 'evt-1');
      expect(restored.amount, 50);
      expect(restored.earnedAt, earnedAt);
      expect(restored.source, XpEventSource.visit);
      expect(restored.sourceId, 'place-9');
    });

    test('does not fabricate amount when map fields are missing', () {
      final restored = XpEvent.fromMap('empty', <String, dynamic>{});
      expect(restored.amount, 0);
      expect(restored.source, XpEventSource.unknown);
    });
  });

  group('XpEventSource', () {
    test('parses known and unknown wire values', () {
      expect(XpEventSource.fromWire('visit'), XpEventSource.visit);
      expect(XpEventSource.fromWire('tileUnlock'), XpEventSource.tileUnlock);
      expect(XpEventSource.fromWire('milestone'), XpEventSource.milestone);
      expect(XpEventSource.fromWire('other'), XpEventSource.unknown);
      expect(XpEventSource.visit.wireValue, 'visit');
      expect(XpEventSource.milestone.wireValue, 'milestone');
    });
  });
}
