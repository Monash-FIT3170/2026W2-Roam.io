/*
 * Author: Sam Sutherland
 * Last Modified: 13/08/2026
 * Description:
 *   Cross-platform bridge for live Journey notifications. Android delegates to
 *   a foreground-service notification and iOS delegates to ActivityKit.
 */

// coverage:ignore-file

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Actions that can be triggered from a live Journey notification.
enum LiveActivityAction { pause, resume, stop, open }

/// Immutable snapshot displayed by a system-level live Journey notification.
class LiveJourneyState {
  const LiveJourneyState({
    required this.journeyId,
    required this.transportMode,
    required this.startTime,
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.tilesUnlocked,
    required this.xpEarned,
    required this.isPaused,
  });

  final String journeyId;
  final String transportMode;
  final DateTime startTime;
  final int elapsedSeconds;
  final double distanceMeters;
  final int tilesUnlocked;
  final int xpEarned;
  final bool isPaused;

  Map<String, Object> toMap() {
    return {
      'journeyId': journeyId,
      'transportMode': transportMode,
      'startTimeMillis': startTime.millisecondsSinceEpoch,
      'elapsedSeconds': elapsedSeconds,
      'distanceMeters': distanceMeters,
      'tilesUnlocked': tilesUnlocked,
      'xpEarned': xpEarned,
      'isPaused': isPaused,
    };
  }
}

/// Contract used by [JourneyController] so the native bridge can be replaced
/// by a fake implementation in unit tests.
abstract interface class LiveActivityGateway {
  Stream<LiveActivityAction> get actions;

  Future<bool> get isSupported;

  Future<void> startJourney(LiveJourneyState state);

  Future<void> updateJourney(LiveJourneyState state);

  Future<void> pauseJourney(LiveJourneyState state);

  Future<void> resumeJourney(LiveJourneyState state);

  Future<void> stopJourney(LiveJourneyState state);
}

/// Bridges Flutter Journey state to Android and iOS live-notification APIs.
class LiveActivityService implements LiveActivityGateway {
  LiveActivityService._() {
    _channel.setMethodCallHandler(_handleNativeCall);
    unawaited(_consumePendingNativeAction());
  }

  static final LiveActivityService instance = LiveActivityService._();

  static const MethodChannel _channel = MethodChannel(
    'com.fit3170.roamio/live_activity',
  );

  LiveActivityAction? _pendingAction;

  late final StreamController<LiveActivityAction> _actionController =
      StreamController<LiveActivityAction>.broadcast(
        onListen: () {
          final pendingAction = _pendingAction;
          if (pendingAction == null) return;

          _pendingAction = null;
          scheduleMicrotask(() => _actionController.add(pendingAction));
        },
      );

  String? _activityId;

  @override
  Stream<LiveActivityAction> get actions => _actionController.stream;

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> get isSupported async {
    if (!_isMobilePlatform) return false;

    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('[LiveActivityService] Support check failed: $error');
      return false;
    }
  }

  @override
  Future<void> startJourney(LiveJourneyState state) async {
    if (!_isMobilePlatform) return;
    if (!await isSupported) return;

    try {
      final id = await _channel.invokeMethod<String>('start', state.toMap());
      if (id != null && id.isNotEmpty) {
        _activityId = id;
      }
    } on MissingPluginException {
      // Native bridge is intentionally absent from widget/unit tests.
    } on PlatformException catch (error) {
      debugPrint('[LiveActivityService] Failed to start: $error');
    }
  }

  @override
  Future<void> updateJourney(LiveJourneyState state) {
    return _invokeStateMethod('update', state);
  }

  @override
  Future<void> pauseJourney(LiveJourneyState state) {
    return _invokeStateMethod('pause', state);
  }

  @override
  Future<void> resumeJourney(LiveJourneyState state) {
    return _invokeStateMethod('resume', state);
  }

  @override
  Future<void> stopJourney(LiveJourneyState state) async {
    await _invokeStateMethod('stop', state);
    _activityId = null;
  }

  Future<void> _invokeStateMethod(String method, LiveJourneyState state) async {
    if (!_isMobilePlatform) return;

    final arguments = <String, Object>{
      ...state.toMap(),
      'activityId': ?_activityId,
    };

    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Native bridge is intentionally absent from widget/unit tests.
    } on PlatformException catch (error) {
      debugPrint('[LiveActivityService] $method failed: $error');
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onAction') return;

    final rawAction = call.arguments is String
        ? call.arguments as String
        : (call.arguments as Map<Object?, Object?>?)?['action'] as String?;

    if (rawAction == null) return;

    final action = LiveActivityAction.values.where(
      (candidate) => candidate.name == rawAction,
    );

    if (action.isNotEmpty) {
      _emitAction(action.first);
      try {
        await _channel.invokeMethod<void>('ackPendingAction');
      } on MissingPluginException {
        // Native bridge is intentionally absent from widget/unit tests.
      } on PlatformException catch (error) {
        debugPrint(
          '[LiveActivityService] Action acknowledgement failed: $error',
        );
      }
    }
  }

  Future<void> _consumePendingNativeAction() async {
    if (!_isMobilePlatform) return;

    try {
      final rawAction = await _channel.invokeMethod<String>(
        'consumePendingAction',
      );
      if (rawAction == null) return;

      final matching = LiveActivityAction.values.where(
        (candidate) => candidate.name == rawAction,
      );
      if (matching.isNotEmpty) {
        _emitAction(matching.first);
      }
    } on MissingPluginException {
      // Native bridge is intentionally absent from widget/unit tests.
    } on PlatformException catch (error) {
      debugPrint('[LiveActivityService] Pending action check failed: $error');
    }
  }

  void _emitAction(LiveActivityAction action) {
    if (_actionController.hasListener) {
      _actionController.add(action);
    } else {
      _pendingAction = action;
    }
  }
}
