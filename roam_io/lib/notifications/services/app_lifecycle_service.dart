import 'package:flutter/widgets.dart';

class AppLifecycleService with WidgetsBindingObserver {
  AppLifecycleService._();

  static final AppLifecycleService instance =
      AppLifecycleService._();

  AppLifecycleState _state = AppLifecycleState.resumed;

  AppLifecycleState get state => _state;

  bool get isInForeground =>
      _state == AppLifecycleState.resumed;

  void initialise() {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
  }
}