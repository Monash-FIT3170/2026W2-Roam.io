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

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'fog_atlas.dart';
import 'fog_controller.dart';
import 'fog_field.dart';
import 'fog_painter.dart';
import 'fog_palette.dart';

/// Animated cloud fog drawn over the map.
///
/// Must be placed directly above the map in a [Stack] and below any UI chrome.
/// It is wrapped in an [IgnorePointer] so map gestures pass straight through.
class FogOverlay extends StatefulWidget {
  const FogOverlay({
    super.key,
    required this.controller,
    this.isActive = true,
    this.atlasOverride,
  });

  final FogController controller;

  /// Whether the map is the visible tab. False stops the ticker.
  final bool isActive;

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

  Duration _elapsed = Duration.zero;
  Duration _lastPaint = Duration.zero;

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
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final controller = widget.controller;

    // Resting clouds drift slowly enough that 30fps is indistinguishable from
    // 60. Full rate is reserved for camera movement and dissipation, where the
    // difference is visible.
    final isBusy =
        controller.isCameraMoving || controller.dissolveSet.isNotEmpty;
    final targetFps = isBusy
        ? FogPalette.activeFramesPerSecond
        : FogPalette.restingFramesPerSecond;
    final minimumInterval = Duration(
      microseconds: Duration.microsecondsPerSecond ~/ targetFps,
    );

    if (elapsed - _lastPaint < minimumInterval) return;

    _lastPaint = elapsed;
    controller.tick(elapsed);
    controller.pruneCompletedDissolves();

    setState(() => _elapsed = elapsed);
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
            atlas: atlas,
            userSpeedMetresPerSecond: controller.userSpeedMetresPerSecond,
            isNight: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
      ),
    );
  }
}
