import 'package:cloud_firestore/cloud_firestore.dart';

/// A single place visit event stored at `profiles/{uid}/visit_events/{id}`.
///
/// Append-only history used for analytics (revisit rate, timelines, category mix).
class VisitEvent {
  const VisitEvent({
    required this.id,
    required this.placeId,
    required this.googlePlaceId,
    required this.placeName,
    required this.regionId,
    required this.category,
    required this.lat,
    required this.lng,
    required this.visitedAt,
    this.source = VisitEventSource.map,
  });

  final String id;
  final int placeId;
  final String googlePlaceId;
  final String placeName;
  final String regionId;
  final String category;
  final double lat;
  final double lng;
  final DateTime visitedAt;
  final VisitEventSource source;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'placeId': placeId,
      'googlePlaceId': googlePlaceId,
      'placeName': placeName,
      'regionId': regionId,
      'category': category,
      'lat': lat,
      'lng': lng,
      'visitedAt': Timestamp.fromDate(visitedAt),
      'source': source.wireValue,
    };
  }

  factory VisitEvent.fromMap(String id, Map<String, dynamic> map) {
    return VisitEvent(
      id: id,
      placeId: (map['placeId'] as num).toInt(),
      googlePlaceId: map['googlePlaceId'] as String,
      placeName: map['placeName'] as String,
      regionId: map['regionId'] as String,
      category: map['category'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      visitedAt: (map['visitedAt'] as Timestamp).toDate(),
      source: VisitEventSource.fromWire(map['source'] as String?),
    );
  }
}

/// Origin of a recorded visit event.
enum VisitEventSource {
  map,
  unknown;

  String get wireValue {
    switch (this) {
      case VisitEventSource.map:
        return 'map';
      case VisitEventSource.unknown:
        return 'unknown';
    }
  }

  static VisitEventSource fromWire(String? value) {
    switch (value) {
      case 'map':
        return VisitEventSource.map;
      default:
        return VisitEventSource.unknown;
    }
  }
}
