/*
 * Description:
 *   The fog layer itself: a ticker-driven CustomPaint stacked over the map.
 *
 *   Lifecycle gating matters more here than it looks. MainShellScreen keeps
 *   every tab mounted inside an IndexedStack, so without explicit gating this
 *   ticker would keep animating clouds nobody can see for as long as the app is
 *   open. It stops when the map tab is not selected and when the app is not
 *   resumed.
 */

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'fog_atlas.dart';
import 'fog_controller.dart';
import 'fog_field.dart';
import 'fog_painter.dart';
import 'fog_palette.dart';
import 'fog_wind.dart';

/// Animated cloud fog drawn over the map.
///
/// Must be placed directly above the map in a [Stack] and below any UI chrome.
/// It is wrapped in an [IgnorePointer] so map gestures pass straight through.
class FogOverlay extends StatefulWidget {
  const FogOverlay({
    super.key,
    required this.controller,
    this.isActive = true,
    this.isJourneyActive = false,
    this.atlasOverride,
  });

  final FogController controller;

  /// Whether the map is the visible tab. False stops the ticker.
  final bool isActive;

  /// Whether a live journey is running.
  ///
  /// The map follows the user for the length of a journey, so the whole sheet
  /// is already sliding across the screen. Drifting the clouds on top of that
  /// reads as the fog moving twice, and the drift is the one part of it nobody
  /// is looking at while a route is being walked — so it is held still, which
  /// also lets a settled frame be skipped outright. See [_onTick].
  final bool isJourneyActive;

  /// Pre-baked atlas supplied by tests.
  ///
  /// Sprite decoding resolves on the real event loop, which flutter_test's fake
  /// async never advances, so a widget test that waited for the normal load
  /// would hang rather than fail. Injecting skips the bake entirely. The caller
  /// keeps ownership — this is never disposed here.
  final FogAtlas? atlasOverride;

  @override
  State<FogOverlay> createState() => _FogOverlayState();
}

class _FogOverlayState extends State<FogOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;

  FogAtlas? _loadedAtlas;
  FogField? _field;
  Brightness? _loadedBrightness;
  bool _isAppResumed = true;

  final FogWind _wind = FogWind();

  Duration _elapsed = Duration.zero;
  Duration _lastPaint = Duration.zero;

  /// Camera of the last painted frame, so a programmatic camera change is not
  /// skipped along with the frames that genuinely have nothing to redraw.
  CameraPosition? _paintedCamera;

  /// 1.0 while the camera is settled, 0.0 while it moves. See
  /// [_advanceMotionEase].
  double _motionEase = 1.0;
  Duration? _lastEaseTick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.atlasOverride != null) return;

    final brightness = Theme.of(context).brightness;
    if (brightness != _loadedBrightness) {
      _loadedBrightness = brightness;
      unawaited(_loadAtlas(brightness));
    }
  }

  /// The atlas in use, preferring an injected one.
  FogAtlas? get _atlas => widget.atlasOverride ?? _loadedAtlas;

  @override
  void didUpdateWidget(FogOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncTicker();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final isResumed = state == AppLifecycleState.resumed;
    if (isResumed == _isAppResumed) return;

    _isAppResumed = isResumed;
    _syncTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _loadedAtlas?.dispose();
    super.dispose();
  }

  Future<void> _loadAtlas(Brightness brightness) async {
    final assets = brightness == Brightness.dark
        ? (FogPalette.nightSprites.isEmpty
              ? FogPalette.daySprites
              : FogPalette.nightSprites)
        : FogPalette.daySprites;

    final atlas = await FogAtlas.load(assetPaths: assets);

    if (!mounted || brightness != _loadedBrightness) {
      atlas?.dispose();
      return;
    }

    setState(() {
      _loadedAtlas?.dispose();
      _loadedAtlas = atlas;
    });
  }

  void _syncTicker() {
    final shouldRun = widget.isActive && _isAppResumed;

    if (shouldRun && !_ticker.isActive) {
      // Ticker.start resets elapsed to zero, so carrying the old timestamps
      // across a stop would leave _lastPaint in the future and gate every frame
      // until elapsed caught up — the fog frozen for as long as the app had
      // previously been open.
      _lastPaint = Duration.zero;
      _lastEaseTick = null;
      _wind.resetTiming();
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final controller = widget.controller;

    final isBusy =
        controller.isCameraMoving || controller.dissolveSet.isNotEmpty;
    final hasReturnAnimation = controller.returnTransition != null;

    _advanceMotionEase(elapsed, isMoving: controller.isCameraMoving);
    _wind.advance(
      elapsed,
      userSpeedMetresPerSecond: controller.userSpeedMetresPerSecond,
      isHeld: widget.isJourneyActive,
    );

    // With the wind held for a journey and the camera settled, the sheet is
    // identical to the one already on screen, so the frame is dropped whole
    // rather than paced down. Two layers of translucent overdraw plus a blur
    // per visible hole is the most expensive thing on the map to repaint, and
    // a journey is when the phone can least afford it — GPS, the route stream
    // and the map's own camera animations are all running.
    //
    // The clock still advances so a region unlocked during the skip is timed
    // from now rather than from the last painted frame, which would otherwise
    // start its dissipation part-finished.
    if (widget.isJourneyActive &&
        !isBusy &&
        !hasReturnAnimation &&
        _motionEase >= 1.0 &&
        controller.camera == _paintedCamera) {
      controller.tick(elapsed);
      return;
    }

    // Resting clouds drift slowly enough that 30fps is indistinguishable from
    // 60, so idle frames are paced down.
    //
    // Anything animating paints every vsync instead. The gate used to apply at
    // a nominal 60fps too, but its interval was the vsync period itself: a
    // frame arriving even microseconds early was dropped whole, and because
    // _lastPaint took the frame's own timestamp rather than accumulating, the
    // phase drifted further into the drop each time. The fog ended up painting
    // at roughly half the map's rate — and on a 120Hz display, at exactly half
    // — which is what made the clouds visibly trail behind the map.
    if (!isBusy && !hasReturnAnimation) {
      const restingInterval = Duration(
        microseconds:
            Duration.microsecondsPerSecond ~/ FogPalette.restingFramesPerSecond,
      );
      if (elapsed - _lastPaint < restingInterval) return;
    }

    _lastPaint = elapsed;
    _paintedCamera = controller.camera;
    controller.tick(elapsed);
    controller.pruneCompletedDissolves();
    controller.pruneCompletedFogReturn();

    setState(() => _elapsed = elapsed);
  }

  /// Ramps [_motionEase] toward 0 while the camera moves and back to 1 at rest.
  ///
  /// The painter sheds work as this falls — the parallax cloud layer and most
  /// of the hole feather — and both would pop if they were switched straight
  /// off `isCameraMoving` the moment a finger landed.
  void _advanceMotionEase(Duration elapsed, {required bool isMoving}) {
    final previous = _lastEaseTick;
    _lastEaseTick = elapsed;
    if (previous == null) return;

    final deltaSeconds =
        (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond;
    if (deltaSeconds <= 0) return;

    final target = isMoving ? 0.0 : 1.0;
    final duration = isMoving
        ? FogPalette.motionEaseOut
        : FogPalette.motionEaseIn;
    final step =
        deltaSeconds * Duration.microsecondsPerSecond / duration.inMicroseconds;

    // A long gap — a janked frame, or a resume — simply snaps to the target
    // rather than easing from stale state.
    _motionEase = target > _motionEase
        ? math.min(target, _motionEase + step)
        : math.max(target, _motionEase - step);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final projection = controller.projection;
    final geometry = controller.geometry;
    final camera = controller.camera;
    final atlas = _atlas;

    if (!controller.isReady ||
        projection == null ||
        geometry == null ||
        camera == null ||
        atlas == null) {
      return const SizedBox.shrink();
    }

    final field = _field ??= FogField(projection: projection);

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: FogPainter(
            projection: projection,
            geometry: geometry,
            field: field,
            camera: camera,
            elapsed: _elapsed,
            dissolves: controller.dissolveSet.active,
            returnTransition: controller.returnTransition,
            atlas: atlas,
            windOffset: _wind.offset,
            isNight: Theme.of(context).brightness == Brightness.dark,
            motionEase: _motionEase,
          ),
        ),
      ),
    );
  }
}
