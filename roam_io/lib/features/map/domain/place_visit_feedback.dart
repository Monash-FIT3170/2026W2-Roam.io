/// Visit history and current proximity are independent: leaving a place's
/// radius never removes its recorded visit.
class PlaceVisitFeedback {
  const PlaceVisitFeedback({required this.isVisited, double? distanceMetres})
    : _distanceMetres = distanceMetres;

  static const double visitRadiusMetres = 100;

  final bool isVisited;
  final double? _distanceMetres;

  double? get distanceMetres {
    final distance = _distanceMetres;
    return distance != null && distance.isFinite && distance >= 0
        ? distance
        : null;
  }

  bool get hasLocation => distanceMetres != null;
  bool get isInRange => hasLocation && distanceMetres! <= visitRadiusMetres;
  bool get canVisit => !isVisited && isInRange;

  PlaceMarkerState get markerState => isVisited
      ? PlaceMarkerState.visited
      : isInRange
      ? PlaceMarkerState.inRange
      : PlaceMarkerState.unvisited;

  String get rangeLabel => !hasLocation
      ? 'Location unavailable'
      : isInRange
      ? 'In range'
      : 'Out of range';

  String? get distanceLabel {
    final metres = distanceMetres;
    if (metres == null) return null;
    // Round up so 100.1m never reads as an eligible 100m.
    return metres < 1000
        ? '${metres.ceil()}m away'
        : '${(metres / 1000).toStringAsFixed(1)}km away';
  }
}

enum PlaceMarkerState { unvisited, inRange, visited }
