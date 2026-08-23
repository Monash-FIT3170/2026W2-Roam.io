/*
 * Description:
 *   Draws the fog: a flat wash for opacity, a scatter of cloud sprites for
 *   texture, and cleared holes punched out of both.
 *
 *   Everything happens inside one saveLayer so the holes remove the wash and
 *   the clouds together. Clouds and holes are drawn under the world transform
 *   rather than in screen space, which keeps the per-frame cost independent of
 *   how much geometry the user has explored.
 */

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'fog_atlas.dart';
import 'fog_dissolve.dart';
import 'fog_field.dart';
import 'fog_geometry.dart';
import 'fog_palette.dart';
import 'fog_projection.dart';
import 'fog_return_transition.dart';

/// Renders the cloud fog sheet over the map.
class FogPainter extends CustomPainter {
  FogPainter({
    required this.projection,
    required this.geometry,
    required this.field,
    required this.camera,
    required this.elapsed,
    required this.dissolves,
    this.returnTransition,
    required this.atlas,
    required this.userSpeedMetresPerSecond,
    this.isNight = false,
    super.repaint,
  });

  final FogProjection projection;
  final FogGeometry geometry;
  final FogField field;
  final CameraPosition camera;
  final Duration elapsed;
  final List<FogDissolve> dissolves;
  final FogReturnTransition? returnTransition;
  final FogAtlas? atlas;
  final double userSpeedMetresPerSecond;
  final bool isNight;

  @override
  void paint(Canvas canvas, Size size) {
    final atlas = this.atlas;
    if (atlas == null || atlas.isEmpty) return;
    if (size.isEmpty) return;

    final screenRect = Offset.zero & size;
    final matrix = projection.matrixFor(camera: camera, size: size);
    final worldBounds = projection.visibleWorldBounds(
      camera: camera,
      size: size,
    );
    final mapScale = FogProjection.scaleForZoom(camera.zoom);

    canvas.saveLayer(screenRect, Paint());

    canvas.drawRect(
      screenRect,
      Paint()
        ..color = (isNight ? FogPalette.nightWashColor : FogPalette.washColor)
            .withValues(
              alpha: isNight
                  ? FogPalette.nightWashOpacity
                  : FogPalette.washOpacity,
            ),
    );

    canvas
      ..save()
      ..transform(matrix.storage);

    _drawClouds(
      canvas: canvas,
      atlas: atlas,
      worldBounds: worldBounds,
      parallax: true,
      size: size,
    );
    _drawClouds(
      canvas: canvas,
      atlas: atlas,
      worldBounds: worldBounds,
      parallax: false,
      size: size,
    );

    _punchHoles(canvas: canvas, worldBounds: worldBounds, mapScale: mapScale);

    canvas
      ..restore()
      ..restore();
  }

  void _drawClouds({
    required Canvas canvas,
    required FogAtlas atlas,
    required Rect worldBounds,
    required bool parallax,
    required Size size,
  }) {
    final batch = field.build(
      camera: camera,
      size: size,
      atlas: atlas,
      elapsed: elapsed,
      dissolves: dissolves,
      userSpeedMetresPerSecond: userSpeedMetresPerSecond,
      parallax: parallax,
      spriteTint: isNight ? FogPalette.nightSpriteTint : FogPalette.spriteTint,
    );

    if (batch.isEmpty) return;

    canvas.drawAtlas(
      atlas.image,
      batch.transforms,
      batch.rects,
      batch.colors,
      // Modulate multiplies the sprite by the per-instance colour, which is how
      // each cloud gets its own opacity and the shared tint at the same time.
      BlendMode.modulate,
      worldBounds,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  /// Clears explored ground out of the fog.
  void _punchHoles({
    required Canvas canvas,
    required Rect worldBounds,
    required double mapScale,
  }) {
    // Sigma is specified in local coordinates and scaled by the canvas
    // transform, so dividing by the map scale keeps the feather a constant
    // width on screen at every zoom.
    final sigma = _radiusToSigma(FogPalette.holeFeatherRadius / mapScale);

    final clearPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = const Color(0xFF000000)
      ..maskFilter = ui.MaskFilter.blur(BlurStyle.normal, sigma);

    final dissolving = <String>{
      for (final dissolve in dissolves) dissolve.regionId,
    };

    for (final path in geometry.pathsIntersecting(
      worldBounds,
      excluding: <String>{...dissolving, ...?returnTransition?.regionIds},
    )) {
      canvas.drawPath(path, clearPaint);
    }

    final returning = returnTransition;
    if (returning != null) {
      final opacity = returning.clearOpacityAt(elapsed);
      if (opacity > 0) {
        for (final id in returning.regionIds) {
          final path = geometry.pathFor(id);
          if (path == null || !path.getBounds().overlaps(worldBounds)) continue;
          canvas.drawPath(
            path,
            Paint()
              ..blendMode = BlendMode.dstOut
              ..color = const Color(0xFF000000).withValues(alpha: opacity)
              ..maskFilter = ui.MaskFilter.blur(BlurStyle.normal, sigma),
          );
        }
      }
    }

    // A region mid-dissipation clears gradually, so the map is revealed behind
    // the departing clouds rather than before or after them.
    for (final dissolve in dissolves) {
      final path = geometry.pathFor(dissolve.regionId);
      if (path == null) continue;

      final progress = FogDissolve.easeOut(dissolve.progressAt(elapsed));
      if (progress <= 0.0) continue;

      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..color = const Color(0xFF000000).withValues(alpha: progress)
          ..maskFilter = ui.MaskFilter.blur(BlurStyle.normal, sigma),
      );
    }
  }

  static double _radiusToSigma(double radius) {
    if (radius <= 0) return 0.0;
    return radius * 0.57735 + 0.5;
  }

  @override
  bool shouldRepaint(FogPainter oldDelegate) {
    return oldDelegate.elapsed != elapsed ||
        oldDelegate.camera != camera ||
        oldDelegate.atlas != atlas ||
        oldDelegate.geometry.length != geometry.length ||
        oldDelegate.dissolves.length != dissolves.length ||
        oldDelegate.returnTransition != returnTransition ||
        oldDelegate.userSpeedMetresPerSecond != userSpeedMetresPerSecond ||
        oldDelegate.isNight != isNight;
  }
}
