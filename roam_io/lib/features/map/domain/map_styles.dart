/*
 * Author: [Amarprit Singh]
 * Last Modified: 11/05/2026
 * Description:
 *   Supplies Google Maps styling used by the map view.
 *   Applies a retro Google Maps theme while removing all
 *   native labels so custom polygons and markers remain clean.
 */

import 'package:flutter/material.dart';

/// Provides Google Maps style JSON for light and dark app themes.
class MapStyles {
  const MapStyles._();

  /// Retro light theme with all labels hidden.
  static const String light = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#ebe3cd" }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#c9b2a6" }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      { "color": "#dfd2ae" }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      { "color": "#dfd2ae" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#a5b076" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      { "color": "#f5f1e6" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      { "color": "#f8c967" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#b9d3c2" }
    ]
  },

  {
    "elementType": "labels",
    "stylers": [
      { "visibility": "off" }
    ]
  }
]
''';

  /// Retro dark theme with all labels hidden.
  static const String dark = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#242f3e" }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      { "color": "#2c3e35" }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      { "color": "#33463d" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#3f5f4a" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      { "color": "#38414e" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      { "color": "#746855" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      { "color": "#17263c" }
    ]
  },

  {
    "elementType": "labels",
    "stylers": [
      { "visibility": "off" }
    ]
  }
]
''';

  /// Returns the map style for the active app brightness.
  /// Returns [dark] for dark mode, [light] for light mode.
  /// Both styles hide all labels to keep polygons and markers clean.
  static String forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }
}
