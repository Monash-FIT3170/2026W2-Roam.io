/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Unit tests for YouAnalyticsProvider follow counts, error handling, and
 *   selected-uid binding behaviour. Follow counts always expose 0 on empty
 *   or error for UI (errors remain on followingCountError).
 */

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/visit.dart';
import 'package:roam_io/features/map/data/visit_service.dart';
import 'package:roam_io/features/map/data/visited_region_service.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_record.dart';
import 'package:roam_io/features/profile/domain/xp_event.dart';
import 'package:roam_io/features/social/data/follow_service.dart';
import 'package:roam_io/features/you/providers/you_analytics_provider.dart';

void main() {
  test(
    'follow counts update from FollowService streams for bound uid',
    () async {
      final followService = _FakeFollowService();
      final provider = YouAnalyticsProvider(
        visitService: _EmptyVisitService(),
        visitedRegionService: _EmptyVisitedRegionService(),
        followService: followService,
        xpEventsStream: Stream<List<XpEvent>>.value(const <XpEvent>[]),
      );

      provider.bindUid('user-a');
      await Future<void>.delayed(Duration.zero);

      expect(provider.followingCount, 0);
      expect(provider.followerCount, 0);

      followService.emitFollowingCount(3);
      followService.emitFollowerCount(5);
      await Future<void>.delayed(Duration.zero);

      expect(provider.followingCount, 3);
      expect(provider.followerCount, 5);

      provider.dispose();
      await followService.dispose();
    },
  );

  test('follow count query errors surface as zero with error flag', () async {
    final followService = _FakeFollowService();
    final provider = YouAnalyticsProvider(
      visitService: _EmptyVisitService(),
      visitedRegionService: _EmptyVisitedRegionService(),
      followService: followService,
      xpEventsStream: Stream<List<XpEvent>>.value(const <XpEvent>[]),
    );

    provider.bindUid('user-a');
    await Future<void>.delayed(Duration.zero);

    followService.emitFollowingError(Exception('permission-denied'));
    await Future<void>.delayed(Duration.zero);

    expect(provider.followingCountReady, isTrue);
    expect(provider.followingCountError, isNotNull);
    expect(provider.followingCount, 0);

    provider.dispose();
    await followService.dispose();
  });

  test(
    'bindUid attaches follow subscriptions even when visit subs exist',
    () async {
      final followService = _FakeFollowService();
      final provider = YouAnalyticsProvider(
        visitService: _EmptyVisitService(),
        visitedRegionService: _EmptyVisitedRegionService(),
        followService: followService,
        xpEventsStream: Stream<List<XpEvent>>.value(const <XpEvent>[]),
      );

      provider.bindUid('user-a');
      await Future<void>.delayed(Duration.zero);
      expect(followService.followingWatchCount, 1);

      // Same uid with all subs present should no-op.
      provider.bindUid('user-a');
      expect(followService.followingWatchCount, 1);

      provider.dispose();
      await followService.dispose();
    },
  );
}

class _EmptyVisitService implements VisitService {
  @override
  Stream<List<Visit>> watchAllVisits(String userId) {
    return Stream<List<Visit>>.value(const <Visit>[]);
  }

  @override
  Stream<List<Visit>> watchRecentVisits(String userId, {int limit = 5}) {
    return Stream<List<Visit>>.value(const <Visit>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyVisitedRegionService implements VisitedRegionService {
  @override
  Stream<List<VisitedPolygonRecord>> watchVisitedPolygonRecords({
    String? profileId,
  }) {
    return Stream<List<VisitedPolygonRecord>>.value(
      const <VisitedPolygonRecord>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFollowService implements FollowService {
  final StreamController<int> _following = StreamController<int>.broadcast();
  final StreamController<int> _followers = StreamController<int>.broadcast();
  int followingWatchCount = 0;
  int followerWatchCount = 0;

  void emitFollowingCount(int value) => _following.add(value);
  void emitFollowerCount(int value) => _followers.add(value);
  void emitFollowingError(Object error) => _following.addError(error);

  @override
  Stream<int> watchFollowingCount(String uid) {
    followingWatchCount += 1;
    return Stream<int>.multi((controller) {
      controller.add(0);
      final sub = _following.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Stream<int> watchFollowerCount(String uid) {
    followerWatchCount += 1;
    return Stream<int>.multi((controller) {
      controller.add(0);
      final sub = _followers.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Stream<bool> watchIsFollowing({
    required String followerId,
    required String followeeId,
  }) {
    return Stream<bool>.value(false);
  }

  @override
  Future<void> follow({
    required String followerId,
    required String followeeId,
  }) async {}

  @override
  Future<void> unfollow({
    required String followerId,
    required String followeeId,
  }) async {}

  Future<void> dispose() async {
    await _following.close();
    await _followers.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
