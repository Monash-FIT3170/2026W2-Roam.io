/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Google Polyline Algorithm implementation for encoding and decoding
 *   route coordinates. This achieves ~75% compression compared to storing
 *   raw coordinate arrays.
 *
 *   Reference: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
 */

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Utility class for encoding and decoding polylines using Google's algorithm.
class PolylineCodec {
  /// Encodes a list of LatLng points into a compressed polyline string.
  static String encode(List<LatLng> points) {
    if (points.isEmpty) return '';

    final buffer = StringBuffer();
    int prevLat = 0;
    int prevLng = 0;

    for (final point in points) {
      final lat = (point.latitude * 1e5).round();
      final lng = (point.longitude * 1e5).round();

      _encodeValue(lat - prevLat, buffer);
      _encodeValue(lng - prevLng, buffer);

      prevLat = lat;
      prevLng = lng;
    }

    return buffer.toString();
  }

  /// Decodes a polyline string back into a list of LatLng points.
  static List<LatLng> decode(String encoded) {
    if (encoded.isEmpty) return [];

    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      int shift = 0;
      int result = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Decode longitude
      shift = 0;
      result = 0;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  /// Encodes a single coordinate difference value.
  static void _encodeValue(int value, StringBuffer buffer) {
    int v = value < 0 ? ~(value << 1) : (value << 1);

    while (v >= 0x20) {
      buffer.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }

    buffer.writeCharCode(v + 63);
  }
}
