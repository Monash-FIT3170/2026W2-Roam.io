/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Central state management for the journey feature. Implements a state
 *   machine to coordinate the journey workflow: setup → tracking → completing → review.
 */

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/journey.dart';
import '../domain/journey_location.dart';
import '../domain/journey_phase.dart';
import '../domain/transport_mode.dart';
import 'journey_service.dart';
import 'journey_tracking_service.dart';
import 'polyline_codec.dart';

/// Controller for managing the journey lifecycle and state.
class JourneyController extends ChangeNotifier {
  JourneyController({
    JourneyService? journeyService,
    JourneyTrackingService? trackingService,
  }) : _journeyService = journeyService ?? JourneyService(),
       _trackingService = trackingService ?? JourneyTrackingService();

  final JourneyService _journeyService;
  final JourneyTrackingService _trackingService;

  // ─────────────────────────────────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────────────────────────────────

  JourneyPhase _currentPhase = JourneyPhase.idle;
  JourneyLocation? _startLocation;
  JourneyLocation? _endLocation;
  TransportMode _transportMode = TransportMode.walk;
  DateTime? _startTime;
  DateTime? _endTime;
  List<LatLng> _routePoints = [];
  double _distanceMeters = 0.0;
  int _tilesUnlocked = 0;
  int _tileXpEarned = 0;
  String? _errorMessage;

  StreamSubscription<List<LatLng>>? _routeSubscription;
  StreamSubscription<double>? _distanceSubscription;

  // ─────────────────────────────────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────────────────────────────────

  JourneyPhase get currentPhase => _currentPhase;
  JourneyLocation? get startLocation => _startLocation;
  JourneyLocation? get endLocation => _endLocation;
  TransportMode get transportMode => _transportMode;
  DateTime? get startTime => _startTime;
  DateTime? get endTime => _endTime;
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  double get distanceMeters => _distanceMeters;
  int get tilesUnlocked => _tilesUnlocked;
  int get tileXpEarned => _tileXpEarned;
  int get journeyXpEarned =>
      ((_distanceMeters / 100).round() * _transportMode.xpMultiplier).round();
  int get totalXpEarned => journeyXpEarned + _tileXpEarned;
  String? get errorMessage => _errorMessage;

  bool get isTracking => _currentPhase == JourneyPhase.tracking;
  bool get hasActiveJourney => _currentPhase != JourneyPhase.idle;

  /// Returns the elapsed duration since journey start.
  Duration get elapsedDuration {
    if (_startTime == null) return Duration.zero;
    final end = _endTime ?? DateTime.now();
    return end.difference(_startTime!);
  }

  /// Returns formatted elapsed time string.
  String get formattedElapsedTime {
    final duration = elapsedDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Returns formatted distance string.
  String get formattedDistance {
    if (_distanceMeters >= 1000) {
      return '${(_distanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${_distanceMeters.toInt()} m';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phase 1: Setup
  // ─────────────────────────────────────────────────────────────────────────

  /// Begins the journey setup flow.
  void beginJourneySetup() {
    if (_currentPhase != JourneyPhase.idle) {
      debugPrint('[JourneyController] Cannot start setup: not idle');
      return;
    }

    _currentPhase = JourneyPhase.settingUp;
    _errorMessage = null;
    notifyListeners();

    debugPrint('[JourneyController] Entered setup phase');
  }

  /// Sets the starting location for the journey.
  void setStartLocation(JourneyLocation location) {
    _startLocation = location;
    notifyListeners();

    debugPrint('[JourneyController] Start location set: ${location.name}');
  }

  /// Sets the transport mode for the journey.
  void setTransportMode(TransportMode mode) {
    _transportMode = mode;
    notifyListeners();

    debugPrint('[JourneyController] Transport mode set: ${mode.displayName}');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phase 2: Tracking
  // ─────────────────────────────────────────────────────────────────────────

  /// Starts GPS tracking. Requires start location to be set.
  Future<void> startTracking() async {
    if (_currentPhase != JourneyPhase.settingUp) {
      debugPrint('[JourneyController] Cannot start tracking: not in setup');
      return;
    }

    if (_startLocation == null) {
      _errorMessage = 'Please select a start location';
      notifyListeners();
      return;
    }

    try {
      _startTime = DateTime.now();
      _currentPhase = JourneyPhase.tracking;
      _routePoints = [];
      _distanceMeters = 0.0;
      _tilesUnlocked = 0;
      _tileXpEarned = 0;

      _subscribeToTrackingUpdates();

      // Start tracking with the start location as initial point
      await _trackingService.startTracking(
        initialPosition: _startLocation!.latLng,
      );

      notifyListeners();
      debugPrint('[JourneyController] Tracking started');
    } catch (e) {
      _currentPhase = JourneyPhase.settingUp;
      _errorMessage = 'Failed to start tracking: $e';
      notifyListeners();
      debugPrint('[JourneyController] Failed to start tracking: $e');
    }
  }

  /// Records XP from a tile first unlocked while this journey is tracking.
  void recordTileUnlocked(int xpAwarded) {
    if (!isTracking || xpAwarded <= 0) return;
    _tilesUnlocked += 1;
    _tileXpEarned += xpAwarded;
    notifyListeners();
  }

  /// Resumes the current journey after the user backs out of ending it.
  ///
  /// Preserves the original start time, route, and accumulated distance.
  Future<void> resumeTracking() async {
    if (_currentPhase != JourneyPhase.completing) {
      debugPrint('[JourneyController] Cannot resume: not completing');
      return;
    }

    try {
      _subscribeToTrackingUpdates();
      await _trackingService.resumeTracking();

      _endTime = null;
      _currentPhase = JourneyPhase.tracking;
      _errorMessage = null;
      notifyListeners();
      debugPrint('[JourneyController] Tracking resumed');
    } catch (e) {
      await _routeSubscription?.cancel();
      await _distanceSubscription?.cancel();
      _routeSubscription = null;
      _distanceSubscription = null;
      _errorMessage = 'Failed to resume tracking: $e';
      notifyListeners();
      debugPrint('[JourneyController] Failed to resume tracking: $e');
    }
  }

  void _subscribeToTrackingUpdates() {
    _routeSubscription = _trackingService.routeStream.listen((points) {
      _routePoints = points;
      notifyListeners();
    });

    _distanceSubscription = _trackingService.distanceStream.listen((distance) {
      _distanceMeters = distance;
      notifyListeners();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phase 3: Completing
  // ─────────────────────────────────────────────────────────────────────────

  /// Stops GPS tracking and moves to the completing phase.
  Future<void> stopTracking() async {
    if (_currentPhase != JourneyPhase.tracking) {
      debugPrint('[JourneyController] Cannot stop: not tracking');
      return;
    }

    _endTime = DateTime.now();

    // Stop the tracking service and get final points
    final finalPoints = await _trackingService.stopTracking();
    _routePoints = finalPoints;
    _distanceMeters = _trackingService.totalDistanceMeters;

    // Clean up subscriptions
    await _routeSubscription?.cancel();
    await _distanceSubscription?.cancel();
    _routeSubscription = null;
    _distanceSubscription = null;

    _currentPhase = JourneyPhase.completing;
    notifyListeners();

    debugPrint(
      '[JourneyController] Tracking stopped, entering completing phase',
    );
  }

  /// Sets the ending location for the journey.
  /// Also adds the end location to the route points to ensure the polyline
  /// connects to the selected location (not just the last GPS position).
  void setEndLocation(JourneyLocation location) {
    _endLocation = location;

    // Add the end location to the route if it's different from the last point
    if (_routePoints.isNotEmpty) {
      final lastPoint = _routePoints.last;
      // Only add if significantly different (more than 1m away)
      final distance = _calculateDistanceBetweenPoints(
        lastPoint,
        location.latLng,
      );
      if (distance > 1.0) {
        _routePoints.add(location.latLng);
      }
    } else {
      // No route points yet, just add the end location
      _routePoints.add(location.latLng);
    }

    notifyListeners();

    debugPrint('[JourneyController] End location set: ${location.name}');
  }

  /// Calculates distance between two points in meters using Haversine formula.
  double _calculateDistanceBetweenPoints(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000; // meters
    final double dLat = _toRadians(p2.latitude - p1.latitude);
    final double dLng = _toRadians(p2.longitude - p1.longitude);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(p1.latitude)) *
            cos(_toRadians(p2.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  /// Moves to the review phase after end location is set.
  void proceedToReview() {
    if (_currentPhase != JourneyPhase.completing) {
      debugPrint('[JourneyController] Cannot proceed: not completing');
      return;
    }

    if (_endLocation == null) {
      _errorMessage = 'Please select an end location';
      notifyListeners();
      return;
    }

    _currentPhase = JourneyPhase.reviewing;
    notifyListeners();

    debugPrint('[JourneyController] Entered review phase');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phase 4: Review & Save
  // ─────────────────────────────────────────────────────────────────────────

  /// Updates the start location's custom name.
  void updateStartLocationName(String customName) {
    if (_startLocation != null) {
      _startLocation = _startLocation!.copyWith(
        customName: customName.isEmpty ? null : customName,
      );
      notifyListeners();
    }
  }

  /// Updates the end location's custom name.
  void updateEndLocationName(String customName) {
    if (_endLocation != null) {
      _endLocation = _endLocation!.copyWith(
        customName: customName.isEmpty ? null : customName,
      );
      notifyListeners();
    }
  }

  void updateStartLocation(JourneyLocation location) {
    _startLocation = location;
    notifyListeners();
  }

  void updateEndLocation(JourneyLocation location) {
    _endLocation = location;
    notifyListeners();
  }

  Future<void> updateSavedLocation({
    required String userId,
    required String journeyId,
    required bool isStartLocation,
    required JourneyLocation location,
  }) {
    return _journeyService.updateJourneyLocation(
      userId: userId,
      journeyId: journeyId,
      isStartLocation: isStartLocation,
      location: location,
    );
  }

  /// Saves the journey to Firestore.
  Future<Journey?> saveJourney(String userId) async {
    if (_currentPhase != JourneyPhase.reviewing) {
      debugPrint('[JourneyController] Cannot save: not reviewing');
      return null;
    }

    if (_startLocation == null ||
        _endLocation == null ||
        _startTime == null ||
        _endTime == null) {
      _errorMessage = 'Journey data incomplete';
      notifyListeners();
      return null;
    }

    // Validate minimum journey requirements
    if (_routePoints.length < 2) {
      _errorMessage = 'Journey too short (no movement recorded)';
      notifyListeners();
      return null;
    }

    if (_distanceMeters < 50) {
      _errorMessage = 'Journey too short (minimum 50m required)';
      notifyListeners();
      return null;
    }

    try {
      // Calculate XP based on distance and transport mode
      final distanceXp = journeyXpEarned;
      final totalXp = totalXpEarned;

      // Encode the route for efficient storage
      final encodedRoute = PolylineCodec.encode(_routePoints);

      final journey = Journey(
        id: '', // Will be assigned by Firestore
        userId: userId,
        startTime: _startTime!,
        endTime: _endTime!,
        startLocation: _startLocation!,
        endLocation: _endLocation!,
        transportMode: _transportMode,
        encodedRoute: encodedRoute,
        distanceMeters: _distanceMeters,
        durationSeconds: elapsedDuration.inSeconds,
        xpEarned: totalXp,
        journeyXpEarned: distanceXp,
        tilesUnlocked: _tilesUnlocked,
        tileXpEarned: _tileXpEarned,
      );

      final savedJourney = await _journeyService.saveJourney(journey);

      // Reset to idle
      _resetState();

      debugPrint('[JourneyController] Journey saved: ${savedJourney.id}');
      return savedJourney;
    } catch (e) {
      _errorMessage = 'Failed to save journey: $e';
      notifyListeners();
      debugPrint('[JourneyController] Failed to save: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cancel & Reset
  // ─────────────────────────────────────────────────────────────────────────

  /// Cancels the current journey and returns to idle.
  Future<void> cancelJourney() async {
    if (_trackingService.isTracking) {
      await _trackingService.stopTracking();
    }

    await _routeSubscription?.cancel();
    await _distanceSubscription?.cancel();

    _resetState();
    debugPrint('[JourneyController] Journey cancelled');
  }

  /// Resets all state to idle.
  void _resetState() {
    _currentPhase = JourneyPhase.idle;
    _startLocation = null;
    _endLocation = null;
    _transportMode = TransportMode.walk;
    _startTime = null;
    _endTime = null;
    _routePoints = [];
    _distanceMeters = 0.0;
    _tilesUnlocked = 0;
    _tileXpEarned = 0;
    _errorMessage = null;
    _routeSubscription = null;
    _distanceSubscription = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Journey History Access
  // ─────────────────────────────────────────────────────────────────────────

  /// Gets a stream of the user's journey history.
  Stream<List<Journey>> getJourneysStream(String userId) {
    return _journeyService.getJourneysStream(userId);
  }

  /// Gets all journeys for a user.
  Future<List<Journey>> getJourneys(String userId) {
    return _journeyService.getJourneys(userId);
  }

  /// Deletes a journey.
  Future<void> deleteJourney({
    required String userId,
    required String journeyId,
  }) {
    return _journeyService.deleteJourney(userId: userId, journeyId: journeyId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cleanup
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _routeSubscription?.cancel();
    _distanceSubscription?.cancel();
    _trackingService.dispose();
    super.dispose();
  }
}
