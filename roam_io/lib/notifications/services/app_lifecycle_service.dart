/*
 * Author: Sam Sutherland
 * Last Modified: 01/08/2026
 * Description:
 *   Tracks whether the application is currently running in the
 *   foreground or background, so notifications can be delivered
 *   using the appropriate presentation method.
 */

import 'package:flutter/widgets.dart';

/// Tracks the current lifecycle state of the application.
class AppLifecycleService with WidgetsBindingObserver {
  AppLifecycleService._();

  static final AppLifecycleService instance =
      AppLifecycleService._();

  AppLifecycleState _state = AppLifecycleState.resumed;

  /// Returns the current lifecycle state of the application.
  AppLifecycleState get state => _state;

  /// Returns true if the application is currently running in the foreground, otherwise false.
  bool get isInForeground =>
      _state == AppLifecycleState.resumed;

  /// Begins observing lifecycle changes.
  void initialise() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Stops observing lifecycle changes.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Updates the stored lifecycle state whenever Flutter reports a lifecycle change.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
  }
}