import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/fog/fog_decay_difficulty.dart';
import 'package:roam_io/features/map/fog/fog_decay_service.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_meta.dart';

void main() {
  const service = FogDecayService();
  final exploredAt = DateTime.utc(2026, 1, 1);

  test('location remains clear before its decay date', () {
    expect(
      service.isLocationDecayed(
        lastExploredAt: exploredAt,
        difficulty: FogDecayDifficulty.monthly,
        now: DateTime.utc(2026, 1, 30),
      ),
      isFalse,
    );
  });

  test('location is fogged at and after its decay date', () {
    expect(
      service.isLocationDecayed(
        lastExploredAt: exploredAt,
        difficulty: FogDecayDifficulty.monthly,
        now: DateTime.utc(2026, 1, 31),
      ),
      isTrue,
    );
  });

  test('monthly, quarterly, and yearly use their configured periods', () {
    expect(
      service.calculateDecayDate(
        lastExploredAt: exploredAt,
        difficulty: FogDecayDifficulty.monthly,
      ),
      DateTime.utc(2026, 1, 31),
    );
    expect(
      service.calculateDecayDate(
        lastExploredAt: exploredAt,
        difficulty: FogDecayDifficulty.quarterly,
      ),
      DateTime.utc(2026, 4, 1),
    );
    expect(
      service.calculateDecayDate(
        lastExploredAt: exploredAt,
        difficulty: FogDecayDifficulty.yearly,
      ),
      DateTime.utc(2027, 1, 1),
    );
  });

  test('revisiting a location resets its decay period', () {
    final location = VisitedPolygonMeta(
      polygonId: 'region-1',
      visitedAt: exploredAt,
      lastEnteredAt: DateTime.utc(2026, 2, 1),
    );

    final clearIds = service.refreshFogDecayState(
      locations: <VisitedPolygonMeta>[location],
      difficulty: FogDecayDifficulty.monthly,
      now: DateTime.utc(2026, 2, 15),
    );

    expect(clearIds, contains('region-1'));
  });

  test('a new service instance identifies persisted expired locations', () {
    final persistedLocation = VisitedPolygonMeta(
      polygonId: 'region-1',
      visitedAt: exploredAt,
      lastEnteredAt: DateTime.utc(2026, 2, 1),
    );

    const restartedService = FogDecayService();
    final clearIds = restartedService.refreshFogDecayState(
      locations: <VisitedPolygonMeta>[persistedLocation],
      difficulty: FogDecayDifficulty.monthly,
      now: DateTime.utc(2026, 3, 10),
    );

    expect(clearIds, isEmpty);
    expect(
      restartedService.getLocationsDueForDecay(
        locations: <VisitedPolygonMeta>[persistedLocation],
        difficulty: FogDecayDifficulty.monthly,
        now: DateTime.utc(2026, 3, 10),
      ),
      contains('region-1'),
    );
  });
}
