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

  static const flagAnchor = Offset(0.5, 28 / 34);

  static BitmapDescriptor? _startFlag;
  static BitmapDescriptor? _finishFlag;

  static Future<BitmapDescriptor> startFlag() async {
    return _startFlag ??= await _drawFlag(isFinish: false);
  }

  static Future<BitmapDescriptor> finishFlag() async {
    return _finishFlag ??= await _drawFlag(isFinish: true);
  }

  static Future<RouteEndpointMarkerIcons> endpoints() async {
    final icons = await Future.wait([startFlag(), finishFlag()]);
    return RouteEndpointMarkerIcons(start: icons[0], finish: icons[1]);
  }

  static Future<BitmapDescriptor> _drawFlag({required bool isFinish}) async {
    const width = 40.0;
    const height = 34.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final flagPaint = Paint()
      ..color = isFinish ? Colors.white : const Color(0xFFE94E5D)
      ..style = PaintingStyle.fill;
    final flagBorderPaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeJoin = StrokeJoin.round;

    final flagPath = Path()
      ..moveTo(8, 7)
      ..quadraticBezierTo(18, 3.5, 31, 7)
      ..lineTo(31, 20)
      ..quadraticBezierTo(22, 17, 12, 21)
      ..lineTo(20, 28)
      ..lineTo(15, 21.5)
      ..quadraticBezierTo(11, 22.5, 8, 24)
      ..close();
    canvas.drawPath(flagPath.shift(const Offset(1.2, 1.2)), shadowPaint);
    canvas.drawPath(flagPath, flagPaint);

    if (isFinish) {
      final checkPaint = Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.fill;
      canvas.drawRect(const Rect.fromLTWH(10, 8, 5.5, 5.5), checkPaint);
      canvas.drawRect(const Rect.fromLTWH(20.5, 8, 5.5, 5.5), checkPaint);
      canvas.drawRect(const Rect.fromLTWH(15.25, 13.5, 5.5, 5.5), checkPaint);
      canvas.drawRect(const Rect.fromLTWH(25.75, 13.5, 4, 5.5), checkPaint);
    }

    canvas.drawPath(flagPath, flagBorderPaint);
    canvas.drawCircle(
      const Offset(20, 28),
      2.8,
      Paint()..color = AppColors.ink,
    );

    final image = await recorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: width,
      height: height,
    );
  }
}
