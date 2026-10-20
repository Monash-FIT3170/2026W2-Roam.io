/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Generates reusable flag-style bitmap markers for Journey route maps.
 */

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../theme/app_colours.dart';

/// Resolved endpoint marker icons used by route maps.
class RouteEndpointMarkerIcons {
  const RouteEndpointMarkerIcons({required this.start, required this.finish});

  final BitmapDescriptor start;
  final BitmapDescriptor finish;
}

/// Cached bitmap descriptors for route endpoint flags.
class RouteMarkerIcons {
  RouteMarkerIcons._();

  static const flagAnchor = Offset(0.5, 0.5);

  static BitmapDescriptor? _startFlag;
  static BitmapDescriptor? _finishFlag;

  static Future<BitmapDescriptor> startFlag() async {
    return _startFlag ??= await _drawMarker(isFinish: false);
  }

  static Future<BitmapDescriptor> finishFlag() async {
    return _finishFlag ??= await _drawMarker(isFinish: true);
  }

  static Future<RouteEndpointMarkerIcons> endpoints() async {
    final icons = await Future.wait([startFlag(), finishFlag()]);
    return RouteEndpointMarkerIcons(start: icons[0], finish: icons[1]);
  }

  /// Simple Roam-style circular endpoint marker: a solid olive dot for the
  /// start of a route and a cream-cored ring for its finish, so the two ends
  /// read as a matched pair rather than competing flag icons.
  static Future<BitmapDescriptor> _drawMarker({required bool isFinish}) async {
    const size = 22.0;
    const center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(center.translate(0, 1), 8, shadowPaint);

    final ringPaint = Paint()
      ..color = AppColors.cream
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8.5, ringPaint);

    final corePaint = Paint()
      ..color = AppColors.sage
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, isFinish ? 4.2 : 6.5, corePaint);

    final borderPaint = Paint()
      ..color = AppColors.sage
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, 8.5, borderPaint);

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: size,
      height: size,
    );
  }
}
