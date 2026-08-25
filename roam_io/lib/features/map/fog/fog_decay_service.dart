import '../../profile/domain/visited_polygon_meta.dart';
import 'fog_decay_difficulty.dart';

/// Computes visual fog state from persisted exploration timestamps.
///
/// This service is deliberately clock-independent: callers provide [now], so
/// the same calculation works during a session and after an application restart.
class FogDecayService {
  const FogDecayService();

  DateTime calculateDecayDate({
    required DateTime lastExploredAt,
    required FogDecayDifficulty difficulty,
  }) {
    return lastExploredAt.add(getFogDecayDuration(difficulty));
  }

  bool isLocationDecayed({
    required DateTime lastExploredAt,
    required FogDecayDifficulty difficulty,
    required DateTime now,
  }) {
    final decayAt = calculateDecayDate(
      lastExploredAt: lastExploredAt,
      difficulty: difficulty,
    );
    return !now.isBefore(decayAt);
  }

  /// Returns explored region IDs whose visual clearing has expired.
  Set<String> getLocationsDueForDecay({
    required Iterable<VisitedPolygonMeta> locations,
    required FogDecayDifficulty difficulty,
    required DateTime now,
  }) {
    return locations
        .where(
          (location) => isLocationDecayed(
            lastExploredAt: location.lastEnteredAt ?? location.visitedAt,
            difficulty: difficulty,
            now: now,
          ),
        )
        .map((location) => location.polygonId)
        .toSet();
  }

  /// Returns region IDs that should currently remain clear of fog.
  Set<String> refreshFogDecayState({
    required Iterable<VisitedPolygonMeta> locations,
    required FogDecayDifficulty difficulty,
    required DateTime now,
  }) {
    final decayed = getLocationsDueForDecay(
      locations: locations,
      difficulty: difficulty,
      now: now,
    );
    return locations
        .map((location) => location.polygonId)
        .where((id) => !decayed.contains(id))
        .toSet();
  }

  /// Finds expired decay events whose exact [decayAt] has not been presented.
  Map<String, DateTime> getUnpresentedDecayEvents({
    required Iterable<VisitedPolygonMeta> locations,
    required Map<String, DateTime> presentedDecayAtByLocation,
    required FogDecayDifficulty difficulty,
    required DateTime now,
  }) {
    final pending = <String, DateTime>{};
    for (final location in locations) {
      final decayAt = calculateDecayDate(
        lastExploredAt: location.lastEnteredAt ?? location.visitedAt,
        difficulty: difficulty,
      );
      if (now.isBefore(decayAt)) continue;
      final presentedAt = presentedDecayAtByLocation[location.polygonId];
      if (presentedAt != null && presentedAt.isAtSameMomentAs(decayAt)) {
        continue;
      }
      pending[location.polygonId] = decayAt;
    }
    return pending;
  }
}
