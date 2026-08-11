/// User-defined home location for distance and comfort-zone analytics.
class HomeBase {
  const HomeBase({
    required this.lat,
    required this.lng,
    required this.setAt,
    this.label,
  });

  final double lat;
  final double lng;
  final DateTime setAt;
  final String? label;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'setAt': setAt.toIso8601String(),
      if (label != null) 'label': label,
    };
  }

  factory HomeBase.fromMap(Map<String, dynamic> map) {
    return HomeBase(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      setAt:
          DateTime.tryParse(map['setAt'] as String? ?? '') ?? DateTime.now(),
      label: map['label'] as String?,
    );
  }
}
