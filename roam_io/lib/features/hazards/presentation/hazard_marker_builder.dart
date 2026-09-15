import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../theme/app_colours.dart';
import '../domain/hazard_category.dart';
import '../domain/hazard_report.dart';

/// Builds compact category-specific markers using the same canvas approach as
/// existing place and custom-location markers.
class HazardMarkerBuilder {
  static const double markerSize = 22;

  final Map<HazardCategory, BitmapDescriptor> _icons = {};

  Future<void> preload() async {
    for (final category in HazardCategory.values) {
      if (_icons.containsKey(category)) continue;
      try {
        _icons[category] = await _createIcon(category);
      } catch (error, stackTrace) {
        debugPrint(
          '[HazardMarkerBuilder] Could not generate ${category.id} icon: '
          '$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Marker build(
    HazardReport report, {
    required void Function(HazardReport report) onTap,
  }) {
    return Marker(
      markerId: MarkerId('hazard_${report.id}'),
      position: report.location,
      infoWindow: InfoWindow.noText,
      icon: _icons[report.category] ?? BitmapDescriptor.defaultMarker,
      onTap: () => onTap(report),
      zIndexInt: 1,
    );
  }

  Future<BitmapDescriptor> _createIcon(HazardCategory category) async {
    const size = markerSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);
    const strokeWidth = 1.5;
    const radius = size / 2 - 2;

    canvas.drawCircle(
      center + const Offset(1, 1),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );
    canvas.drawCircle(center, radius, Paint()..color = AppColors.sage);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(category.icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: category.icon.fontFamily,
          package: category.icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    picture.dispose();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    iconPainter.dispose();
    if (byteData == null) {
      throw StateError('Hazard marker image could not be encoded');
    }
    final bytes = byteData.buffer.asUint8List();
    return BitmapDescriptor.bytes(bytes, width: size, height: size);
  }
}
