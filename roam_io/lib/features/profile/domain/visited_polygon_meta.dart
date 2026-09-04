import 'package:cloud_firestore/cloud_firestore.dart';

/// Enriched metadata for a first-time tile unlock.
class VisitedPolygonMeta {
  const VisitedPolygonMeta({
    required this.polygonId,
    required this.visitedAt,
    this.areaSquareMetres,
    this.name,
    this.lastEnteredAt,
  });

  final String polygonId;
  final DateTime visitedAt;
  final double? areaSquareMetres;
  final String? name;
  final DateTime? lastEnteredAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'visitedAt': Timestamp.fromDate(visitedAt),
      if (areaSquareMetres != null) 'areaSquareMetres': areaSquareMetres,
      if (name != null) 'name': name,
      if (lastEnteredAt != null)
        'lastEnteredAt': Timestamp.fromDate(lastEnteredAt!),
    };
  }

  factory VisitedPolygonMeta.fromMap(
    String polygonId,
    Map<String, dynamic> map,
  ) {
    return VisitedPolygonMeta(
      polygonId: polygonId,
      visitedAt: parseTimestamp(map['visitedAt']) ?? DateTime.now(),
      areaSquareMetres: (map['areaSquareMetres'] as num?)?.toDouble(),
      name: map['name'] as String?,
      lastEnteredAt: parseTimestamp(map['lastEnteredAt']),
    );
  }

  static DateTime? parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
