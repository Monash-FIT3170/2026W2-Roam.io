import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../domain/journey.dart';
import '../data/polyline_codec.dart';

class JourneyShareCard extends StatelessWidget {
  const JourneyShareCard({
    super.key,
    required this.journey,
    this.backgroundColor = AppColors.ink,
  });

  final Journey journey;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    // 9:16 Aspect ratio for stories
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          // Add a subtle gradient for depth
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundColor.withValues(alpha: 0.8),
              backgroundColor,
              backgroundColor.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: Stack(
          children: [
            // The main card
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The map area
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            color: AppColors.cream.withValues(alpha: 0.5),
                            child: CustomPaint(
                              painter: RoutePainter(
                                encodedRoute: journey.encodedRoute,
                                routeColor: AppColors.clay,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Stats area
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              journey.displayTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _StatWidget(
                                  value: journey.formattedDistance.split(' ').first,
                                  unit: journey.formattedDistance.split(' ').last,
                                ),
                                _StatWidget(
                                  value: journey.durationSeconds >= 3600 
                                      ? (journey.durationSeconds / 3600).toStringAsFixed(1)
                                      : (journey.durationSeconds / 60).toStringAsFixed(0),
                                  unit: journey.durationSeconds >= 3600 ? 'hrs' : 'min',
                                ),
                                if (journey.xpEarned != null)
                                  _StatWidget(
                                    value: '${journey.xpEarned}',
                                    unit: 'xp',
                                  )
                                else
                                  _StatWidget(
                                    value: '${journey.tilesUnlocked}',
                                    unit: 'tiles',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Divider(color: Colors.grey.withValues(alpha: 0.2)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  journey.transportMode.icon,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  journey.transportMode.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.explore,
                                      size: 14,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Roam.io',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatWidget extends StatelessWidget {
  const _StatWidget({required this.value, required this.unit});
  
  final String value;
  final String unit;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

class RoutePainter extends CustomPainter {
  final String encodedRoute;
  final Color routeColor;

  RoutePainter({required this.encodedRoute, required this.routeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final points = PolylineCodec.decode(encodedRoute);
    if (points.isEmpty) return;

    // Find bounds
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Add padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;
    minLat -= latPadding;
    maxLat += latPadding;
    minLng -= lngPadding;
    maxLng += lngPadding;

    final latRange = maxLat - minLat == 0 ? 0.0001 : maxLat - minLat;
    final lngRange = maxLng - minLng == 0 ? 0.0001 : maxLng - minLng;

    // We need to scale to fit while maintaining aspect ratio
    final double scaleX = size.width / lngRange;
    final double scaleY = size.height / latRange;
    final double scale = math.min(scaleX, scaleY);
    
    // Center the map in the canvas
    final mapWidth = lngRange * scale;
    final mapHeight = latRange * scale;
    final offsetX = (size.width - mapWidth) / 2.0;
    final offsetY = (size.height - mapHeight) / 2.0;

    final paint = Paint()
      ..color = routeColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool first = true;
    for (var p in points) {
      // For latitude, larger values (North) should be drawn higher (smaller y)
      final x = offsetX + (p.longitude - minLng) * scale;
      final y = offsetY + (maxLat - p.latitude) * scale;
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw a subtle shadow under the route
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
      
    final shadowPath = path.shift(const Offset(0, 3));
    canvas.drawPath(shadowPath, shadowPaint);
    
    // Draw the actual route
    canvas.drawPath(path, paint);
    
    // Draw start/end markers
    if (points.isNotEmpty) {
      final startP = points.first;
      final startX = offsetX + (startP.longitude - minLng) * scale;
      final startY = offsetY + (maxLat - startP.latitude) * scale;
      
      final endP = points.last;
      final endX = offsetX + (endP.longitude - minLng) * scale;
      final endY = offsetY + (maxLat - endP.latitude) * scale;
      
      final startMarkerPaint = Paint()..color = AppColors.sage;
      canvas.drawCircle(Offset(startX, startY), 6.0, startMarkerPaint);
      canvas.drawCircle(Offset(startX, startY), 3.0, Paint()..color = Colors.white);
      
      final endMarkerPaint = Paint()..color = AppColors.clay;
      canvas.drawCircle(Offset(endX, endY), 6.0, endMarkerPaint);
      canvas.drawCircle(Offset(endX, endY), 3.0, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.encodedRoute != encodedRoute || oldDelegate.routeColor != routeColor;
  }
}
