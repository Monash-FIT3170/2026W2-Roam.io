/*
 * Author: Sam Sutherland
 * Last Modified: 01/08/2026
 * Description:
 *   Tests application lifecycle tracking used to determine whether
 *   notifications should appear in-app or as Android device notifications.
 */

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/notifications/services/app_lifecycle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLifecycleService', () {
    final service = AppLifecycleService.instance;

    test('reports resumed state as foreground', () {
      // Act: simulate the application becoming active and visible.
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Assert: resumed is the only state treated as foreground.
      expect(service.state, AppLifecycleState.resumed);
      expect(service.isInForeground, isTrue);
    });

    test('reports paused state as background', () {
      // Act: simulate the application moving into the background.
      service.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(service.state, AppLifecycleState.paused);
      expect(service.isInForeground, isFalse);
    });

    test('reports inactive state as not foreground', () {
      // Inactive represents a temporary interruption, such as a system
      // dialog or application transition.
      service.didChangeAppLifecycleState(AppLifecycleState.inactive);

      expect(service.state, AppLifecycleState.inactive);
      expect(service.isInForeground, isFalse);
    });

    test('reports detached state as not foreground', () {
      // Detached indicates that Flutter is no longer attached to a host view.
      service.didChangeAppLifecycleState(AppLifecycleState.detached);

      expect(service.state, AppLifecycleState.detached);
      expect(service.isInForeground, isFalse);
    });
  });
}
