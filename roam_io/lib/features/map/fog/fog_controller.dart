/*
 * Description:
 *   Owns fog state and the bridge between MapController and the fog overlay.
 *
 *   Camera updates deliberately do not go through notifyListeners. MapPage
 *   rebuilds its whole subtree on every MapController notification, and the
 *   camera changes on every frame of every gesture, so routing it that way
 *   would rebuild the map, markers and chrome sixty times a second. The overlay
 *   reads the camera directly from here on its own ticker instead.
 */

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/region_polygon.dart';
import 'fog_dissolve.dart';
import 'fog_geometry.dart';
import 'fog_palette.dart';
import 'fog_projection.dart';

/// Fog state shared between the map controller and the fog overlay.
class FogController extends ChangeNotifier {
  FogProjection? _projection;
  FogGeometry? _geometry;

  final FogDissolveSet dissolveSet = FogDissolveSet();

  CameraPosition? _camera;
  bool _isCameraMoving = false;
  bool _hasLoadedViewport = false;
  double _userSpeedMetresPerSecond = 0.0;

  /// Animation clock, pushed in by the overlay's ticker.
  ///
  /// Dissolves are timed against this rather than wall time so they share one
  /// clock with the frames that draw them. A region unlocked while the ticker
  /// is stopped therefore completes instantly once it resumes, which is the
  /// right outcome: nobody was there to watch it.
  Duration _clock = Duration.zero;

  Duration get clock => _clock;

  FogProjection? get projection => _projection;

  FogGeometry? get geometry => _geometry;

  CameraPosition? get camera => _camera;

  bool get isCameraMoving => _isCameraMoving;

  double get userSpeedMetresPerSecond => _userSpeedMetresPerSecond;

  /// Whether the overlay has enough information to draw.
  ///
  /// Tracked explicitly rather than inferred from an empty hole set: a brand
  /// new account legitimately has zero visited regions, and inferring readiness
  /// would leave those users looking at a permanently unfogged map. Equally, a
  /// failed load must leave this false so the fog stays off rather than hiding
  /// the whole map behind cloud.
  bool get isReady =>
      _hasLoadedViewport && _projection != null && _geometry != null;

  /// Establishes the world-space origin.
  ///
  /// Called once with the first resolved camera target. World coordinates are
  /// relative to it so path coordinates stay small enough to keep Float32
  /// precision at maximum zoom.
  void setAnchor(LatLng anchor) {
    if (_projection != null) return;

    final projection = FogProjection(anchor: anchor);
    _projection = projection;
    _geometry = FogGeometry(projection: projection);
    notifyListeners();
  }

  /// Advances the animation clock. Called once per painted frame.
  void tick(Duration elapsed) {
    _clock = elapsed;
  }

  void updateCamera(CameraPosition camera, {bool isMoving = false}) {
    _camera = camera;
    _isCameraMoving = isMoving;
  }

  void setCameraMoving(bool isMoving) {
    _isCameraMoving = isMoving;
  }

  void setUserSpeed(double metresPerSecond) {
    _userSpeedMetresPerSecond = metresPerSecond.isFinite
        ? metresPerSecond.abs()
        : 0.0;
  }

  /// Marks the first successful viewport load.
  void markViewportLoaded() {
    if (_hasLoadedViewport) return;
    _hasLoadedViewport = true;
    notifyListeners();
  }

  /// Adds a cleared region. Safe to call repeatedly; geometry is built once.
  void addClearedRegion(RegionPolygon region) {
    final geometry = _geometry;
    if (geometry == null) return;
    if (geometry.contains(region.id)) return;

    geometry.add(region);
    notifyListeners();
  }

  void addClearedRegions(Iterable<RegionPolygon> regions) {
    final geometry = _geometry;
    if (geometry == null) return;

    var added = false;
    for (final region in regions) {
      if (geometry.contains(region.id)) continue;
      geometry.add(region);
      added = true;
    }

    if (added) notifyListeners();
  }

  /// Starts the blow-away animation for a newly unlocked region.
  ///
  /// [userLatLng] is the tear origin, so the clouds part from where the user
  /// actually is rather than from the region's centroid.
  void startDissolve({
    required RegionPolygon region,
    required LatLng userLatLng,
  }) {
    final projection = _projection;
    final geometry = _geometry;
    if (projection == null || geometry == null) return;

    geometry.add(region);
    final bounds = geometry.boundsFor(region.id);
    if (bounds == null || bounds.isEmpty) return;

    dissolveSet.start(
      FogDissolve(
        regionId: region.id,
        worldCentre: projection.latLngToWorld(
          userLatLng.latitude,
          userLatLng.longitude,
        ),
        regionBounds: bounds,
        wind: FogPalette.windVelocity,
        startedAt: _clock,
      ),
    );

    notifyListeners();
  }

  /// Drops finished dissolves so their regions become permanent holes.
  ///
  /// Returns true when anything completed, which the overlay uses to decide
  /// whether it can drop back to the resting frame rate.
  bool pruneCompletedDissolves() {
    return dissolveSet.pruneCompleted(_clock).isNotEmpty;
  }

  /// Clears all fog state, for sign-out or account switch.
  void reset() {
    _geometry?.clear();
    dissolveSet.clear();
    _hasLoadedViewport = false;
    notifyListeners();
  }
}
