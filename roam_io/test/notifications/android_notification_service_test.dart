/*
 * Author: Sam Sutherland
 * Last Modified: 05/08/2026
 * Description:
 *   Tests Android notification service platform guards.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/notifications/notification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('AndroidNotificationService', () {
    test('initialise returns without throwing on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await expectLater(
        AndroidNotificationService.instance.initialise(),
        completes,
      );
    });

    test('requestPermission returns false on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final granted = await AndroidNotificationService.instance
          .requestPermission();

      expect(granted, isFalse);
    });
  });
}
