/*
 * Author: Sam Sutherland
 * Last Modified: 13/08/2026
 * Description:
 *   Tests system notification service platform guards without invoking native
 *   Android or iOS notification plugins in the unit-test environment.
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
    test(
      'initialise returns without throwing on unsupported platforms',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;

        await expectLater(
          AndroidNotificationService.instance.initialise(),
          completes,
        );
      },
    );

    test('requestPermission returns false on unsupported platforms', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final granted = await AndroidNotificationService.instance
          .requestPermission();

      expect(granted, isFalse);
    });
  });
}
