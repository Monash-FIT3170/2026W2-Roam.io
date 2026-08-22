/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 21 August 2026
 * Description:
 *   Hosts the map screen and wires widget lifecycle to the map controller. This
 *   file keeps UI thin while controller setup, visit XP wiring, heatmap
 *   toggling, place detail display, unlock reward feedback, journey tracking,
 *   and cleanup run in the correct Flutter lifecycle hooks.
 */

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../activity_feed/data/activity_creation_service.dart';
import '../../activity_feed/models/activity_media_item.dart';
import '../../auth/providers/auth_provider.dart';
import '../../journeys/data/journey_controller.dart';
import '../../journeys/data/polyline_codec.dart';
import '../../journeys/domain/journey.dart';
import '../../journeys/domain/journey_location.dart';
import '../../journeys/domain/journey_phase.dart';
import '../../journeys/domain/nearby_place.dart';
import '../../journeys/domain/transport_mode.dart';
import '../../journeys/widgets/end_journey_sheet.dart';
import '../../journeys/widgets/custom_location_details_sheet.dart';
import '../../journeys/widgets/journey_summary_sheet.dart';
import '../../journeys/widgets/journey_tracking_card.dart';
import '../../journeys/widgets/past_journey_summary_sheet.dart';
import '../../journeys/widgets/start_journey_sheet.dart';
import '../../profile/domain/xp_event.dart';
import '../../../shared/widgets/activity_saved_celebration.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../widgets/map_render.dart';
import '../widgets/mode_toggle_chip.dart';
import 'map_controller.dart';
import 'place_details_sheet.dart';
import 'place_of_interest.dart';
import 'places_service.dart';
import 'region_polygon.dart';
import 'tile_unlock_xp_service.dart';

/// Cached black circle marker icon for custom journey locations.
BitmapDescriptor? _customLocationIcon;

/// Creates a black circle icon matching the style of place markers.
Future<BitmapDescriptor> _getCustomLocationIcon() async {
  if (_customLocationIcon != null) return _customLocationIcon!;

  const double size = 20; // Match medium place marker size
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  const strokeWidth = size / 12;

  // Black fill
  final fillPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.fill;

  // White border
  final strokePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  // Shadow
  final shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.3)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, size / 18);

  const center = Offset(size / 2, size / 2);
  const radius = size / 2 - strokeWidth - 2;

  canvas.drawCircle(center + const Offset(1, size / 18), radius, shadowPaint);
  canvas.drawCircle(center, radius, fillPaint);
  canvas.drawCircle(center, radius, strokePaint);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  _customLocationIcon = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  return _customLocationIcon!;
}

/// Calculates Haversine distance between two points in meters.
double _haversineDistance(LatLng p1, LatLng p2) {
  const double earthRadius = 6371000; // meters
  final double lat1Rad = p1.latitude * math.pi / 180;
  final double lat2Rad = p2.latitude * math.pi / 180;
  final double dLat = (p2.latitude - p1.latitude) * math.pi / 180;
  final double dLng = (p2.longitude - p1.longitude) * math.pi / 180;

  final double a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1Rad) *
          math.cos(lat2Rad) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);

  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

/// Map screen that connects controller unlock events to provider XP and toast UI.
class MapPage extends StatefulWidget {
  const MapPage({super.key, this.activityCreationService});

  final ActivityCreationService? activityCreationService;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final MapController _mapController;
  late final JourneyController _journeyController;
  late final ActivityCreationService _activityCreationService;
  Set<Polyline> _activeJourneyPolyline = {};
  Set<Polyline> _savedJourneyPolylines = {};
  Set<Marker> _journeyMarkers = {};
  StreamSubscription<List<Journey>>? _journeysSubscription;
  bool _isOpeningJourneyCompletionFlow = false;
  bool _isSavingReviewedJourneyActivity = false;

  @override
  void initState() {
    super.initState();

    final authProvider = context.read<AuthProvider>();
    _activityCreationService =
        widget.activityCreationService ?? ActivityCreationService();

    // Own the controller for this page and start its setup work once mounted.
    _mapController = MapController(
      tileUnlockXpService: TileUnlockXpService(
        addXp: (xp) => authProvider.addXp(xp, source: XpEventSource.tileUnlock),
      ),
    );
    _mapController.addListener(_onMapStateChanged);
    _mapController.onPlaceSelected = _showPlaceDetails;
    _mapController.onRegionUnlockRewarded = _showRegionUnlockReward;
    _mapController.onRegionUnlockCelebrationRewarded = _showRegionUnlockReward;

    // Listen to journey controller for route updates
    _journeyController = context.read<JourneyController>();
    _journeyController.addListener(_onJourneyStateChanged);

    // Get user ID from auth provider and initialize
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      _mapController.initialise(
        userId: authProvider.currentUser?.uid,
        onVisitXpAwarded: (xp) async {
          await authProvider.addXp(xp, source: XpEventSource.visit);
        },
      );

      // Load saved journeys
      _loadSavedJourneys();
    });
  }

  /// Loads saved journeys and displays them on the map.
  void _loadSavedJourneys() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.uid;
    if (userId == null) return;

    final journeyController = context.read<JourneyController>();

    _journeysSubscription?.cancel();
    _journeysSubscription = journeyController.getJourneysStream(userId).listen((
      journeys,
    ) {
      _updateSavedJourneyVisuals(journeys);
    });
  }

  /// Creates polylines and markers for saved journeys.
  /// Only creates markers for custom locations (where placeId is null).
  /// If a location was selected from nearby places (has placeId), the existing
  /// place marker is used instead.
  Future<void> _updateSavedJourneyVisuals(List<Journey> journeys) async {
    final polylines = <Polyline>{};
    final markers = <Marker>{};

    // Check if we need a custom location icon (black circle)
    final needsCustomIcon = journeys.any(
      (j) => j.startLocation.placeId == null || j.endLocation.placeId == null,
    );

    BitmapDescriptor? customIcon;
    if (needsCustomIcon) {
      customIcon = await _getCustomLocationIcon();
    }

    for (final journey in journeys) {
      // Decode the route and create a polyline
      final routePoints = PolylineCodec.decode(journey.encodedRoute);
      if (routePoints.isNotEmpty) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('journey_${journey.id}'),
            points: routePoints,
            color: journey.transportMode.routeColor,
            width: 8,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
            consumeTapEvents: true,
            onTap: () => PastJourneySummarySheet.show(
              context: context,
              journey: journey,
            ),
          ),
        );

        // Add start marker only for custom locations (no placeId)
        // Uses black circle marker to match place marker style
        if (journey.startLocation.placeId == null && customIcon != null) {
          markers.add(
            Marker(
              markerId: MarkerId('journey_start_${journey.id}'),
              position: journey.startLocation.latLng,
              icon: customIcon,
              anchor: const Offset(0.5, 0.5),
              infoWindow: InfoWindow.noText,
              onTap: () => _showCustomLocation(
                journey: journey,
                location: journey.startLocation,
                isStartLocation: true,
              ),
            ),
          );
        }

        // Add end marker only for custom locations (no placeId)
        if (journey.endLocation.placeId == null && customIcon != null) {
          markers.add(
            Marker(
              markerId: MarkerId('journey_end_${journey.id}'),
              position: journey.endLocation.latLng,
              icon: customIcon,
              anchor: const Offset(0.5, 0.5),
              infoWindow: InfoWindow.noText,
              onTap: () => _showCustomLocation(
                journey: journey,
                location: journey.endLocation,
                isStartLocation: false,
              ),
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _savedJourneyPolylines = polylines;
        _journeyMarkers = markers;
      });
    }
  }

  Future<void> _showCustomLocation({
    required Journey journey,
    required JourneyLocation location,
    required bool isStartLocation,
  }) async {
    final userId = context.read<AuthProvider>().currentUser?.uid;
    if (userId == null) return;

    LatLng currentPosition;
    try {
      final position = await _mapController.getCurrentPosition();
      currentPosition = LatLng(position.latitude, position.longitude);
    } catch (_) {
      currentPosition = _mapController.center;
    }
    if (!mounted) return;

    await CustomLocationDetailsSheet.show(
      context: context,
      location: location,
      distanceMeters: _haversineDistance(currentPosition, location.latLng),
      userId: userId,
      onSave: (updated) =>
          context.read<JourneyController>().updateSavedLocation(
            userId: userId,
            journeyId: journey.id,
            isStartLocation: isStartLocation,
            location: updated,
          ),
    );
  }

  void _onMapStateChanged() {
    // Rebuild when the controller publishes new map state.
    if (mounted) setState(() {});
  }

  void _onJourneyStateChanged() {
    if (!mounted) return;
    final journeyController = context.read<JourneyController>();

    // Update active journey polyline when route changes
    if (journeyController.routePoints.isNotEmpty) {
      _activeJourneyPolyline = {
        Polyline(
          polylineId: const PolylineId('active_journey'),
          points: journeyController.routePoints,
          color: journeyController.transportMode.routeColor,
          width: 8,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
    } else {
      _activeJourneyPolyline = {};
    }

    setState(() {});
  }

  void _showPlaceDetails(PlaceOfInterest place) {
    PlaceDetailsSheet.show(
      context: context,
      scaffoldMessenger: ScaffoldMessenger.of(context),
      place: place,
      mapController: _mapController,
    );
  }

  void _showRegionUnlockReward(RegionPolygon region, int xpAwarded) {
    if (!mounted) return;

    context.read<JourneyController>().recordTileUnlocked(xpAwarded);

    final message = 'Unlocked New Region +$xpAwarded XP';
    final auth = context.read<AuthProvider>();

    // When XP triggers a level-up, show the unlock toast inside the celebration
    // overlay (below the centered content) instead of as a scaffold snackbar.
    if (auth.pendingLevelUp != null) {
      auth.stageUnlockToast(message);
      return;
    }

    AppToast.success(context, message);
  }

  @override
  void dispose() {
    // Detach listeners and release controller resources when leaving the page.
    _mapController.onPlaceSelected = null;
    _mapController.onRegionUnlockRewarded = null;
    _mapController.onRegionUnlockCelebrationRewarded = null;
    _mapController.removeListener(_onMapStateChanged);
    _mapController.disposeController();

    // Remove journey controller listener
    _journeyController.removeListener(_onJourneyStateChanged);

    // Cancel journeys subscription
    _journeysSubscription?.cancel();

    super.dispose();
  }

  // Journey handling methods
  Future<void> _startJourneyFlow() async {
    final journeyController = context.read<JourneyController>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.uid;

    // Get current position for the sheet
    LatLng currentPosition;
    try {
      final position = await _mapController.getCurrentPosition();
      currentPosition = LatLng(position.latitude, position.longitude);
    } catch (e) {
      currentPosition = _mapController.center;
    }

    // Fetch nearby places from Google Places API
    final placesService = PlacesService();
    final nearbyResults = await Future.wait([
      placesService.getNearbyPlaces(
        lat: currentPosition.latitude,
        lng: currentPosition.longitude,
        radiusMeters: 10,
      ),
      placesService.getNearbyPlaces(
        lat: currentPosition.latitude,
        lng: currentPosition.longitude,
        radiusMeters: PlacesService.transportEligibilityRadiusMeters,
        transportOnly: true,
      ),
    ]);
    final googlePlaces = nearbyResults[0];
    final nearbyTransportPlaces = nearbyResults[1];
    final availableTransportModes = <TransportMode>{
      TransportMode.walk,
      TransportMode.drive,
      for (final place in nearbyTransportPlaces.where(
        (place) =>
            place.distanceMeters != null &&
            place.distanceMeters! <=
                PlacesService.transportEligibilityRadiusMeters,
      ))
        ...place.supportedTransportModes,
    };

    // Get custom saved locations within radius
    final customLocations = await _getNearbySavedLocations(
      currentPosition: currentPosition,
      radiusMeters: 10,
      userId: userId,
      journeyController: journeyController,
    );
    if (!mounted) return;

    // Combine and sort by distance
    final allNearbyPlaces = [...googlePlaces, ...customLocations];
    allNearbyPlaces.sort(
      (a, b) => (a.distanceMeters ?? 999).compareTo(b.distanceMeters ?? 999),
    );

    // Show start journey sheet
    final result = await StartJourneySheet.show(
      context: context,
      currentPosition: currentPosition,
      nearbyPlaces: allNearbyPlaces,
      availableTransportModes: availableTransportModes,
    );

    if (result == null) {
      // User cancelled
      return;
    }

    // Configure and start the journey
    journeyController.beginJourneySetup();
    journeyController.setStartLocation(result.startLocation);
    journeyController.setTransportMode(result.transportMode);
    await journeyController.startTracking();
  }

  Future<void> _endJourneyFlow() async {
    final journeyController = context.read<JourneyController>();

    setState(() => _isOpeningJourneyCompletionFlow = true);
    try {
      // Stop active GPS tracking before moving into the existing completion flow.
      await journeyController.stopTracking();
      if (!mounted ||
          journeyController.currentPhase != JourneyPhase.completing) {
        return;
      }

      await _completeStoppedJourneyFlow();
    } finally {
      if (mounted) {
        setState(() => _isOpeningJourneyCompletionFlow = false);
      }
    }
  }

  /// Completes a Journey whose live tracking has already stopped.
  ///
  /// This is also used when the user presses Stop from a system-level live
  /// notification. In that case the map presents a Finish Journey action the
  /// next time the user returns to it.
  Future<void> _completeStoppedJourneyFlow() async {
    final journeyController = context.read<JourneyController>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.uid;

    if (journeyController.currentPhase != JourneyPhase.completing) return;
    if (!_isOpeningJourneyCompletionFlow && mounted) {
      setState(() => _isOpeningJourneyCompletionFlow = true);
    }

    // Get current position for the end location sheet.
    LatLng currentPosition;
    try {
      final position = await _mapController.getCurrentPosition();
      currentPosition = LatLng(position.latitude, position.longitude);
    } catch (e) {
      currentPosition = _mapController.center;
    }

    // Fetch nearby places from Google Places API.
    final placesService = PlacesService();
    final googlePlaces = await placesService.getNearbyPlaces(
      lat: currentPosition.latitude,
      lng: currentPosition.longitude,
      radiusMeters: 10,
    );

    // Get custom saved locations within radius.
    final customLocations = await _getNearbySavedLocations(
      currentPosition: currentPosition,
      radiusMeters: 10,
      userId: userId,
      journeyController: journeyController,
    );
    if (!mounted) return;

    final allNearbyPlaces = [...googlePlaces, ...customLocations];
    allNearbyPlaces.sort(
      (a, b) => (a.distanceMeters ?? 999).compareTo(b.distanceMeters ?? 999),
    );

    final endResult = await EndJourneySheet.show(
      context: context,
      currentPosition: currentPosition,
      distanceMeters: journeyController.distanceMeters,
      duration: journeyController.elapsedDuration,
      transportMode: journeyController.transportMode,
      nearbyPlaces: allNearbyPlaces,
    );
    if (!mounted) return;

    if (endResult == null) {
      await journeyController.cancelJourney();
      _activeJourneyPolyline = {};
      setState(() => _isOpeningJourneyCompletionFlow = false);
      return;
    }

    // User chose to continue tracking.
    if (endResult.continueTracking) {
      await journeyController.resumeTracking();
      if (mounted && journeyController.isTracking) {
        setState(() => _isOpeningJourneyCompletionFlow = false);
        AppToast.show(context, 'Journey resumed');
      }
      return;
    }

    journeyController.setEndLocation(endResult.endLocation);
    journeyController.proceedToReview();

    await _showJourneyReviewFlow();
    if (mounted) {
      setState(() => _isOpeningJourneyCompletionFlow = false);
    }
  }

  Future<void> _showJourneyReviewFlow() async {
    final journeyController = context.read<JourneyController>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.uid;

    if (journeyController.currentPhase != JourneyPhase.reviewing ||
        journeyController.startLocation == null ||
        journeyController.endLocation == null) {
      return;
    }

    final summaryResult = await JourneySummarySheet.show(
      context: context,
      startLocation: journeyController.startLocation!,
      endLocation: journeyController.endLocation!,
      transportMode: journeyController.transportMode,
      distanceMeters: journeyController.distanceMeters,
      duration: journeyController.elapsedDuration,
      routePoints: journeyController.routePoints,
      startTime: journeyController.startTime,
      initialTitle: journeyController.persistedReviewedJourney?.title,
      xpEarned: journeyController.totalXpEarned,
      tilesUnlocked: journeyController.tilesUnlocked,
      visitedRegionIds: _mapController.visitedRegionIds,
      currentRegionId: _mapController.currentRegion?.id,
      onUpdateStartName: journeyController.updateStartLocationName,
      onUpdateEndName: journeyController.updateEndLocationName,
      userId: userId,
      onUpdateStartLocation: journeyController.updateStartLocation,
      onUpdateEndLocation: journeyController.updateEndLocation,
    );
    if (!mounted || summaryResult == null) return;

    switch (summaryResult.action) {
      case JourneySummaryAction.save:
        await _saveReviewedJourneyActivity(
          summaryResult.title,
          media: summaryResult.media,
        );
        break;
      case JourneySummaryAction.discard:
        await _discardReviewedJourneyActivity(summaryResult.title);
        break;
    }
  }

  Future<void> _saveReviewedJourneyActivity(
    String title, {
    required List<PendingActivityMedia> media,
  }) async {
    final journeyController = context.read<JourneyController>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.uid;
    if (userId == null) {
      AppToast.error(context, 'Sign in to save this journey.');
      return;
    }

    authProvider.deferLevelUpCelebrationOverlay();
    setState(() => _isSavingReviewedJourneyActivity = true);

    final savedJourney = await journeyController.saveJourney(
      userId,
      title: title,
      resetAfterSave: false,
    );
    if (!mounted) {
      authProvider.resumeLevelUpCelebrationOverlay();
      return;
    }
    if (savedJourney == null) {
      authProvider.resumeLevelUpCelebrationOverlay();
      setState(() => _isSavingReviewedJourneyActivity = false);
      AppToast.error(
        context,
        journeyController.errorMessage ?? 'Could not save journey.',
      );
      return;
    }

    final xpAwarded = await _awardReviewedJourneyXp(savedJourney);
    if (!mounted || !xpAwarded) {
      authProvider.resumeLevelUpCelebrationOverlay();
      if (mounted) {
        setState(() => _isSavingReviewedJourneyActivity = false);
      }
      return;
    }

    try {
      await _activityCreationService.createJourneyActivity(
        journey: savedJourney,
        title: title,
        fallbackProfile: authProvider.currentProfile,
        mediaSelections: media,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[MapPage] publish journey activity failed $error\n$stackTrace',
      );
      if (mounted) {
        authProvider.resumeLevelUpCelebrationOverlay();
        setState(() => _isSavingReviewedJourneyActivity = false);
        AppToast.error(context, 'Journey saved. Could not publish activity.');
      }
      return;
    }

    if (!mounted) {
      authProvider.resumeLevelUpCelebrationOverlay();
      return;
    }
    await _showActivitySavedCelebration(xpEarned: savedJourney.xpEarned);
    if (!mounted) {
      authProvider.resumeLevelUpCelebrationOverlay();
      return;
    }
    journeyController.clearReviewedJourney();
    _activeJourneyPolyline = {};
    setState(() => _isSavingReviewedJourneyActivity = false);
    authProvider.resumeLevelUpCelebrationOverlay();
  }

  Future<void> _showActivitySavedCelebration({int? xpEarned}) async {
    final overlay = Overlay.of(context);
    final completer = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => ActivitySavedCelebration(
        xpEarned: xpEarned,
        onDismiss: () {
          entry.remove();
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    overlay.insert(entry);
    await completer.future;
  }

  Future<void> _discardReviewedJourneyActivity(String title) async {
    final journeyController = context.read<JourneyController>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.uid;
    if (userId == null) {
      AppToast.error(context, 'Sign in to save this journey.');
      return;
    }

    final savedJourney = await journeyController.saveJourney(
      userId,
      title: title,
      resetAfterSave: false,
    );
    if (!mounted) return;
    if (savedJourney == null) {
      AppToast.error(
        context,
        journeyController.errorMessage ?? 'Could not save journey.',
      );
      return;
    }

    final xpAwarded = await _awardReviewedJourneyXp(savedJourney);
    if (!mounted || !xpAwarded) return;

    journeyController.clearReviewedJourney();
    _activeJourneyPolyline = {};
    setState(() {});
    AppToast.show(context, 'Journey saved without activity');
  }

  Future<bool> _awardReviewedJourneyXp(Journey savedJourney) async {
    final journeyController = context.read<JourneyController>();
    if (journeyController.reviewedJourneyXpAwarded) return true;

    final xpToAward =
        savedJourney.journeyXpEarned ?? savedJourney.xpEarned ?? 0;
    if (xpToAward <= 0) {
      journeyController.markReviewedJourneyXpAwarded();
      return true;
    }

    final result = await context.read<AuthProvider>().addXp(
      xpToAward,
      source: XpEventSource.journey,
      sourceId: savedJourney.id,
    );
    if (!mounted) return false;
    if (!result.succeeded) {
      AppToast.error(context, 'Journey saved. Could not award XP.');
      return false;
    }

    journeyController.markReviewedJourneyXpAwarded();
    return true;
  }

  /// Get nearby saved custom locations (those without placeId) within a given radius.
  Future<List<NearbyPlace>> _getNearbySavedLocations({
    required LatLng currentPosition,
    required int radiusMeters,
    required String? userId,
    required JourneyController journeyController,
  }) async {
    if (userId == null) return [];

    final journeys = await journeyController.getJourneys(userId);
    final customLocations = <NearbyPlace>[];
    final seenCoordinates = <String>{};

    for (final journey in journeys) {
      // Check start location
      if (journey.startLocation.placeId == null) {
        final startLatLng = journey.startLocation.latLng;
        final distance = _haversineDistance(currentPosition, startLatLng);
        final coordKey = '${startLatLng.latitude},${startLatLng.longitude}';

        if (distance <= radiusMeters && !seenCoordinates.contains(coordKey)) {
          seenCoordinates.add(coordKey);
          customLocations.add(
            NearbyPlace(
              placeId: null,
              name: journey.startLocation.name,
              address: 'Saved Location',
              latLng: startLatLng,
              distanceMeters: distance.round(),
              isCustomLocation: true,
            ),
          );
        }
      }

      // Check end location
      if (journey.endLocation.placeId == null) {
        final endLatLng = journey.endLocation.latLng;
        final distance = _haversineDistance(currentPosition, endLatLng);
        final coordKey = '${endLatLng.latitude},${endLatLng.longitude}';

        if (distance <= radiusMeters && !seenCoordinates.contains(coordKey)) {
          seenCoordinates.add(coordKey);
          customLocations.add(
            NearbyPlace(
              placeId: null,
              name: journey.endLocation.name,
              address: 'Saved Location',
              latLng: endLatLng,
              distanceMeters: distance.round(),
              isCustomLocation: true,
            ),
          );
        }
      }
    }

    return customLocations;
  }

  // Build the map page UI from the controller's current state. The controller
  // uses the shell [Scaffold] only — a nested scaffold here duplicates snackbars.
  @override
  Widget build(BuildContext context) {
    final journeyController = context.watch<JourneyController>();
    final isTracking = journeyController.currentPhase == JourneyPhase.tracking;
    final isPaused = journeyController.currentPhase == JourneyPhase.paused;
    final isLiveJourneyActive = isTracking || isPaused;
    final isCompleting =
        journeyController.currentPhase == JourneyPhase.completing;
    final isReviewing =
        journeyController.currentPhase == JourneyPhase.reviewing &&
        !_isSavingReviewedJourneyActivity;
    final canStartJourney = journeyController.currentPhase == JourneyPhase.idle;

    // Combine active journey polyline with saved journey polylines
    final allPolylines = <Polyline>{
      ..._savedJourneyPolylines,
      ..._activeJourneyPolyline,
    };

    // Combine map markers with journey start/end markers
    final allMarkers = <Marker>{..._mapController.markers, ..._journeyMarkers};

    return Stack(
      children: [
        MapRender(
          initialCenter: _mapController.center,
          polygons: _mapController.polygons,
          mapStyle: _mapController.mapStyle,
          markers: allMarkers,
          polylines: allPolylines,
          myLocationEnabled: _mapController.myLocationEnabled,
          onMapCreated: _mapController.onMapCreated,
          // Load or refresh visible regions after the user stops moving the map.
          onCameraIdle: _mapController.onCameraIdle,
          onCameraMove: _mapController.onCameraMove,
          onCameraMoveStarted: _mapController.onCameraMoveStarted,
        ),
        if (_mapController.myLocationEnabled)
          Positioned(
            right: 16,
            bottom: isLiveJourneyActive ? 220 : 120,
            child: FloatingActionButton.small(
              heroTag: 'recenter_map',
              tooltip: 'Centre on my location',
              onPressed: _mapController.recenterOnUser,
              backgroundColor: AppSurfaces.card(context),
              foregroundColor: AppSurfaces.textPrimary(context),
              child: const Icon(Icons.my_location),
            ),
          ),
        // Start Journey is available only while no Journey is active.
        if (canStartJourney)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: StartJourneyChip(onPressed: _startJourneyFlow),
            ),
          ),
        // A lock-screen Stop action ends tracking immediately. The Journey
        // remains available here so the user can choose its end location and
        // review/save it after returning to the app.
        if (isCompleting && !_isOpeningJourneyCompletionFlow)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: FilledButton.icon(
                onPressed: _completeStoppedJourneyFlow,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Finish Journey'),
              ),
            ),
          ),
        if (isReviewing)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: FilledButton.icon(
                onPressed: _showJourneyReviewFlow,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Review Journey'),
              ),
            ),
          ),
        if (_mapController.isHeatmapEnabled)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 16,
            child: const _HeatmapLegend(),
          ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 16,
          right: 16,
          child: _HeatmapToggleButton(
            isEnabled: _mapController.isHeatmapEnabled,
            onPressed: _mapController.toggleHeatmap,
          ),
        ),
        // Journey tracking card remains available while tracking is paused.
        if (isLiveJourneyActive)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: JourneyTrackingCard(
              distanceMeters: journeyController.distanceMeters,
              elapsedTime: journeyController.formattedElapsedTime,
              transportMode: journeyController.transportMode,
              isPaused: isPaused,
              onPauseResume: () {
                if (isPaused) {
                  journeyController.resumeTracking();
                } else {
                  journeyController.pauseTracking();
                }
              },
              onEndJourney: _endJourneyFlow,
            ),
          ),
      ],
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heatmap legend',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const _LegendRow(color: Color(0xFFFFF176), label: '1–2 entries'),
            const SizedBox(height: 6),
            const _LegendRow(color: Color(0xFFFFC247), label: '3–4 entries'),
            const SizedBox(height: 6),
            const _LegendRow(color: Color(0xFFE53935), label: '5+ entries'),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.14),
              width: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black),
          ),
        ),
      ],
    );
  }
}

class _HeatmapToggleButton extends StatelessWidget {
  const _HeatmapToggleButton({
    required this.isEnabled,
    required this.onPressed,
  });

  final bool isEnabled;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = Colors.deepOrange.shade600;
    final inactiveColor = theme.colorScheme.surface;

    return Tooltip(
      message: isEnabled ? 'Hide heatmap' : 'Show heatmap',
      child: Material(
        color: isEnabled ? activeColor : inactiveColor,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: () {
            onPressed();
          },
          icon: const Icon(Icons.local_fire_department_rounded),
          color: isEnabled ? Colors.white : theme.colorScheme.onSurface,
          iconSize: 26,
        ),
      ),
    );
  }
}
