/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Ensures flat visit XP is granted only after a successful visit save, never
 *   from failed saves, and scales linearly with distinct visits (not polygon area).
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/map/data/geolocator_service.dart';
import 'package:roam_io/features/map/data/map_controller.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/features/map/data/visited_region_service.dart';
import 'package:roam_io/features/map/data/visit_service.dart';
import 'package:roam_io/features/profile/domain/xp_reward_config.dart';

void main() {
  group('MapController visit XP', () {
    test('successful save invokes awarder once with flat 50 XP', () async {
      final awards = <int>[];
      final controller = await _buildController(
        visitService: VisitService(firestore: FakeFirebaseFirestore()),
        onVisitXpAwarded: (xp) async => awards.add(xp),
      );

      final result = await controller.markPlaceAsVisited(
        _place(id: 1, regionId: 'REG_A'),
      );

      expect(result, VisitResult.success);
      expect(awards, <int>[XpRewardConfig.visitXpReward]);
    });

    test('failed save invokes awarder zero times', () async {
      final awards = <int>[];
      final controller = await _buildController(
        visitService: _AlwaysThrowingVisitService(),
        onVisitXpAwarded: (xp) async => awards.add(xp),
      );

      final result = await controller.markPlaceAsVisited(
        _place(id: 2, regionId: 'REG_B'),
      );

      expect(result, VisitResult.error);
      expect(awards, isEmpty);
    });

    test('visit XP amount is flat 50 regardless of region id', () async {
      final awards = <int>[];
      final controller = await _buildController(
        visitService: VisitService(firestore: FakeFirebaseFirestore()),
        onVisitXpAwarded: (xp) async => awards.add(xp),
      );

      await controller.markPlaceAsVisited(
        _place(
          id: 3,
          regionId: 'VERY_LARGE_SA2_IDENTIFIER_NOT_USED_IN_XP_CALC',
        ),
      );

      expect(awards, <int>[XpRewardConfig.visitXpReward]);
    });

    test('two distinct successful visits award 50 XP each', () async {
      final awards = <int>[];
      final controller = await _buildController(
        visitService: VisitService(firestore: FakeFirebaseFirestore()),
        onVisitXpAwarded: (xp) async => awards.add(xp),
      );

      await controller.markPlaceAsVisited(_place(id: 10, regionId: 'R1'));
      await controller.markPlaceAsVisited(_place(id: 11, regionId: 'R2'));

      expect(awards, <int>[
        XpRewardConfig.visitXpReward,
        XpRewardConfig.visitXpReward,
      ]);
    });

    test('award callback sees cumulative XP when it tracks profile state',
        () async {
      var runningXp = 0;
      final controller = await _buildController(
        visitService: VisitService(firestore: FakeFirebaseFirestore()),
        onVisitXpAwarded: (xp) async {
          runningXp += xp;
        },
      );

      expect(runningXp, 0);
      await controller.markPlaceAsVisited(_place(id: 20, regionId: 'R1'));
      expect(runningXp, XpRewardConfig.visitXpReward);
      await controller.markPlaceAsVisited(_place(id: 21, regionId: 'R2'));
      expect(runningXp, XpRewardConfig.visitXpReward * 2);
    });

    test('retry after failure awards XP only on successful persist', () async {
      final awards = <int>[];
      final visitService = _FailOnceThenSucceedVisitService(
        FakeFirebaseFirestore(),
      );
      final controller = await _buildController(
        visitService: visitService,
        onVisitXpAwarded: (xp) async => awards.add(xp),
      );

      expect(await controller.markPlaceAsVisited(_place(id: 30, regionId: 'R')),
          VisitResult.error);
      expect(awards, isEmpty);

      expect(await controller.markPlaceAsVisited(_place(id: 30, regionId: 'R')),
          VisitResult.success);
      expect(awards, <int>[XpRewardConfig.visitXpReward]);
    });
  });
}

PlaceOfInterest _place({required int id, required String regionId}) {
  return PlaceOfInterest(
    id: id,
    googlePlaceId: 'place_$id',
    name: 'Test place $id',
    category: PlaceCategory.other,
    types: const <String>[],
    location: const LatLng(-37.8136, 144.9631),
    regionId: regionId,
  );
}

/// Avoids Firebase in unit tests (default [VisitedRegionService] reads FirebaseAuth).
class _TestVisitedRegionService implements VisitedRegionService {
  @override
  Future<Set<String>> loadVisitedRegionIds() async => <String>{};

  @override
  Future<bool> markVisited(String regionId, {DateTime? visitedAt}) async =>
      true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<MapController> _buildController({
  required VisitService visitService,
  required Future<void> Function(int amount) onVisitXpAwarded,
}) async {
  final geo = _FixedPositionGeo(
    Position(
      latitude: -37.8136,
      longitude: 144.9631,
      timestamp: DateTime.utc(2026, 5, 12),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    ),
  );

  final controller = MapController(
    geoLocatorService: geo,
    visitService: visitService,
    visitedRegionService: _TestVisitedRegionService(),
  );
  controller.bindVisitXpAwarding(onVisitXpAwarded);
  await controller.setUserId('user-visit-xp-test');
  return controller;
}

class _FixedPositionGeo extends GeoLocatorService {
  _FixedPositionGeo(this._position);

  final Position _position;

  @override
  Future<Position> getCurrentLocation() async => _position;

  @override
  Future<Stream<Position>> getLocationUpdates() async =>
      Stream<Position>.fromIterable(const <Position>[]);
}

class _AlwaysThrowingVisitService extends VisitService {
  _AlwaysThrowingVisitService() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<void> markVisited({
    required String userId,
    required PlaceOfInterest place,
  }) async {
    throw Exception('save failed');
  }
}

class _FailOnceThenSucceedVisitService extends VisitService {
  _FailOnceThenSucceedVisitService(FirebaseFirestore firestore)
    : super(firestore: firestore);

  var _fail = true;

  @override
  Future<void> markVisited({
    required String userId,
    required PlaceOfInterest place,
  }) async {
    if (_fail) {
      _fail = false;
      throw Exception('transient');
    }
    return super.markVisited(userId: userId, place: place);
  }
}
