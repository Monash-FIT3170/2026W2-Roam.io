/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Unit tests for XpAwardResult success and failure factories.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/profile/domain/xp_award_result.dart';

void main() {
  group('XpAwardResult', () {
    test('failed factory marks award as unsuccessful', () {
      final result = XpAwardResult.failed(amount: 50);

      expect(result.succeeded, isFalse);
      expect(result.amount, 50);
      expect(result.didLevelUp, isFalse);
      expect(result.historyRecorded, isFalse);
    });

    test('success factory derives didLevelUp from levels', () {
      final result = XpAwardResult.success(
        amount: 50,
        previousXp: 90,
        newXp: 140,
        previousLevel: 1,
        newLevel: 2,
        historyRecorded: true,
      );

      expect(result.succeeded, isTrue);
      expect(result.didLevelUp, isTrue);
      expect(result.historyRecorded, isTrue);
    });
  });
}
