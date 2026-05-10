import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/mapfeature/region_polygon.dart';
import 'package:roam_io/features/mapfeature/region_polygon_cache.dart';

// Fake data class to mirror Firestore

class FakeVisitedPolygonsDoc {
  final String userId;
  final Map<String, DateTime> visitedPolygons;

  const FakeVisitedPolygonsDoc({
    required this.userId,
    required this.visitedPolygons,
  });

  bool hasVisited(String polygonId) => visitedPolygons.containsKey(polygonId);

  // Throws if the polygon ID is not registered in the system at all
  DateTime visitedAtOrThrow(String polygonId) {
    if (!visitedPolygons.containsKey(polygonId)) {
      throw ArgumentError('Polygon $polygonId does not exist in visited data.');
    }
    return visitedPolygons[polygonId]!;
  }
}

// Fake Firestore document — matches the shape (id: date/time)
final fakeDoc = FakeVisitedPolygonsDoc(
  userId: 'fake-user-123',
  visitedPolygons: {
    '212051322': DateTime.parse('2026-05-10 01:49:50'),
    '212051324': DateTime.parse('2026-05-04 19:15:43'),
    '212051327': DateTime.parse('2026-05-10 01:48:17'),
    '212051567': DateTime.parse('2026-05-04 19:17:04'),
    '212051568': DateTime.parse('2026-05-07 15:01:12'),
  },
);

// A polygon ID that exists in fakeDoc.
const VisitedPolygonId = '212051322';

// A polygon ID that is NOT in fakeDoc (unvisited, but valid geometry).
const UnvisitedPolygonId = '999999999';

// A polygon ID that doesn't exist anywhere — used for error-path tests.
const NonExistentPolygonId = '000000000';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RegionPolygon _makeRegion(String id) => RegionPolygon(
  id: id,
  name: 'Test Region ($id)',
  geometry: {
    'type': 'Polygon',
    'coordinates': [
      [
        [144.9631, -37.8136],
        [144.9731, -37.8136],
        [144.9731, -37.8036],
        [144.9631, -37.8036],
        [144.9631, -37.8136],
      ],
    ],
  },
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FakeVisitedPolygonsDoc (data layer)', () {
    test('correctly identifies a visited polygon', () {
      expect(fakeDoc.hasVisited(VisitedPolygonId), isTrue);
    });

    test('correctly identifies an unvisited polygon', () {
      expect(fakeDoc.hasVisited(UnvisitedPolygonId), isFalse);
    });

    test('throws ArgumentError for a polygon that does not exist', () {
      expect(
        () => fakeDoc.visitedAtOrThrow(NonExistentPolygonId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns the correct visit timestamp for a visited polygon', () {
      final visitedAt = fakeDoc.visitedAtOrThrow(VisitedPolygonId);
      expect(visitedAt, equals(DateTime.parse('2026-05-10 01:49:50')));
    });
  });

  group('Polygon rendering (driven by fake Firestore data)', () {
    test('visited polygon renders as transparent', () {
      final cache = RegionPolygonCache();
      final region = _makeRegion(VisitedPolygonId);

      cache.cacheRegion(
        region: region,
        isVisited: fakeDoc.hasVisited(region.id),
        isCurrentRegion: false,
        onRegionTapped: (_, __) {},
      );

      final polygon = cache.polygons.first;
      expect(polygon.fillColor, const Color(0x00000000)); // transparent
      expect(polygon.strokeColor, const Color(0x80F3D27A)); // visited stroke
      expect(polygon.strokeWidth, 3);
    });

    test('unvisited polygon renders as dark', () {
      final cache = RegionPolygonCache();
      final region = _makeRegion(UnvisitedPolygonId);

      cache.cacheRegion(
        region: region,
        isVisited: fakeDoc.hasVisited(region.id),
        isCurrentRegion: false,
        onRegionTapped: (_, __) {},
      );

      final polygon = cache.polygons.first;
      expect(polygon.fillColor, const Color(0xCC080808)); // dark fill
      expect(polygon.strokeColor, const Color(0xFF4A4A4A)); // unvisited stroke
      expect(polygon.strokeWidth, 2);
    });

    test('polygon rendering updates correctly when visited status changes', () {
      final cache = RegionPolygonCache();
      final region = _makeRegion(UnvisitedPolygonId);

      // Initially unvisited
      cache.cacheRegion(
        region: region,
        isVisited: false,
        isCurrentRegion: false,
        onRegionTapped: (_, __) {},
      );
      expect(cache.polygons.first.fillColor, const Color(0xCC080808));

      // Simulate the user visiting the polygon — doc gains the new ID
      final updatedDoc = FakeVisitedPolygonsDoc(
        userId: fakeDoc.userId,
        visitedPolygons: {
          ...fakeDoc.visitedPolygons,
          UnvisitedPolygonId: DateTime.now(),
        },
      );

      cache.refreshStyles(
        shouldRenderAsVisited: (regionId) => updatedDoc.hasVisited(regionId),
        isCurrentRegion: (_) => false,
        onRegionTapped: (_, __) {},
      );

      final polygon = cache.polygons.first;
      expect(polygon.fillColor, const Color(0x00000000));
      expect(polygon.strokeColor, const Color(0x80F3D27A));
      expect(polygon.strokeWidth, 3);
    });
  });
}
