/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Session-scoped analytics for an explicitly bound profile uid (You or an
 *   external selectedUserId). Holds the latest visits, tile records, XP events,
 *   and follow counts from live Firestore watches so Profile data survives
 *   TabBarView dispose/remount. Following/Followers seed to 0 and never expose
 *   null for display (empty relationships = 0). Other analytics still
 *   distinguish loading, real empty, and query failure.
 */

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../services/profile_service.dart';
import '../../map/data/visit.dart';
import '../../map/data/visit_service.dart';
import '../../map/data/visited_region_service.dart';
import '../../profile/domain/visited_polygon_record.dart';
import '../../profile/domain/xp_event.dart';
import '../../social/data/follow_service.dart';

/// Owns profile analytics subscriptions for an explicitly bound profile uid.
class YouAnalyticsProvider extends ChangeNotifier {
  YouAnalyticsProvider({
    VisitService? visitService,
    VisitedRegionService? visitedRegionService,
    ProfileService? profileService,
    FollowService? followService,
    Stream<List<XpEvent>>? xpEventsStream,
  }) : _visitService = visitService ?? VisitService(),
       _visitedRegionService = visitedRegionService ?? VisitedRegionService(),
       _profileService = profileService,
       _followService = followService ?? FollowService(),
       _injectedXpEventsStream = xpEventsStream;

  final VisitService _visitService;
  final VisitedRegionService _visitedRegionService;
  final ProfileService? _profileService;
  final FollowService _followService;
  final Stream<List<XpEvent>>? _injectedXpEventsStream;

  /// Exposed for [StatsAnalyticsProvider] subclasses.
  @protected
  VisitService get visitService => _visitService;

  /// Exposed for [StatsAnalyticsProvider] subclasses.
  @protected
  VisitedRegionService get visitedRegionService => _visitedRegionService;

  String? _boundUid;
  StreamSubscription<List<Visit>>? _visitsSub;
  StreamSubscription<List<Visit>>? _recentVisitsSub;
  StreamSubscription<List<VisitedPolygonRecord>>? _tileRecordsSub;
  StreamSubscription<List<XpEvent>>? _xpEventsSub;
  StreamSubscription<int>? _followingCountSub;
  StreamSubscription<int>? _followerCountSub;

  List<Visit> _visits = const <Visit>[];
  List<Visit> _recentVisits = const <Visit>[];
  List<VisitedPolygonRecord> _tileRecords = const <VisitedPolygonRecord>[];
  List<XpEvent> _xpEvents = const <XpEvent>[];
  int? _followingCount;
  int? _followerCount;
  bool _visitsReady = false;
  bool _recentVisitsReady = false;
  bool _tileRecordsReady = false;
  bool _xpEventsReady = false;
  bool _followingCountReady = false;
  bool _followerCountReady = false;
  Object? _visitsError;
  Object? _recentVisitsError;
  Object? _tileRecordsError;
  Object? _xpEventsError;
  Object? _followingCountError;
  Object? _followerCountError;

  List<Visit> get visits => _visits;
  List<Visit> get recentVisits => _recentVisits;
  List<VisitedPolygonRecord> get tileRecords => _tileRecords;
  List<XpEvent> get xpEvents => _xpEvents;

  /// Follow counts always expose a number for UI (empty / unset / error = 0).
  /// Errors remain available via [followingCountError] for diagnostics.
  int get followingCount =>
      _followingCountError != null ? 0 : (_followingCount ?? 0);

  /// See [followingCount].
  int get followerCount =>
      _followerCountError != null ? 0 : (_followerCount ?? 0);

  bool get visitsReady => _visitsReady;
  bool get recentVisitsReady => _recentVisitsReady;
  bool get tileRecordsReady => _tileRecordsReady;
  bool get xpEventsReady => _xpEventsReady;
  bool get followingCountReady => _followingCountReady;
  bool get followerCountReady => _followerCountReady;
  Object? get visitsError => _visitsError;
  Object? get recentVisitsError => _recentVisitsError;
  Object? get tileRecordsError => _tileRecordsError;
  Object? get xpEventsError => _xpEventsError;
  Object? get followingCountError => _followingCountError;
  Object? get followerCountError => _followerCountError;

  String? get boundUid => _boundUid;

  /// Tiles for stats: null when the tile query failed; otherwise list length.
  int? get tileCount {
    if (!_tileRecordsReady) return null;
    if (_tileRecordsError != null) return null;
    return _tileRecords.length;
  }

  /// Binds (or rebinds) live watches to [uid]. No-ops when uid is unchanged
  /// and all subscriptions (including follow counts) are already attached.
  void bindUid(String? uid) {
    if (_boundUid == uid && uid == null) {
      return;
    }
    if (_boundUid == uid &&
        _visitsSub != null &&
        _recentVisitsSub != null &&
        _tileRecordsSub != null &&
        _xpEventsSub != null &&
        _followingCountSub != null &&
        _followerCountSub != null) {
      return;
    }

    _cancelSubscriptions();
    _boundUid = uid;
    _resetData();

    if (uid == null) {
      _markAllReady();
      notifyListeners();
      return;
    }

    notifyListeners();

    _visitsSub = _visitService
        .watchAllVisits(uid)
        .listen(
          (value) {
            _visits = value;
            _visitsError = null;
            _visitsReady = true;
            notifyListeners();
          },
          onError: (Object error) {
            _logAnalyticsError(
              uid: uid,
              operation: 'watchAllVisits',
              collection: 'profiles/$uid/visits',
              error: error,
            );
            _visitsError = error;
            _visitsReady = true;
            notifyListeners();
          },
        );

    _recentVisitsSub = _visitService
        .watchRecentVisits(uid)
        .listen(
          (value) {
            _recentVisits = value;
            _recentVisitsError = null;
            _recentVisitsReady = true;
            notifyListeners();
          },
          onError: (Object error) {
            _logAnalyticsError(
              uid: uid,
              operation: 'watchRecentVisits',
              collection: 'profiles/$uid/visits',
              error: error,
            );
            _recentVisitsError = error;
            _recentVisitsReady = true;
            notifyListeners();
          },
        );

    _tileRecordsSub = _visitedRegionService
        .watchVisitedPolygonRecords(profileId: uid)
        .listen(
          (value) {
            _tileRecords = value;
            _tileRecordsError = null;
            _tileRecordsReady = true;
            notifyListeners();
          },
          onError: (Object error) {
            _logAnalyticsError(
              uid: uid,
              operation: 'watchVisitedPolygonRecords',
              collection: 'polygons_visited/$uid',
              error: error,
            );
            _tileRecordsError = error;
            _tileRecordsReady = true;
            notifyListeners();
          },
        );

    _xpEventsSub = _xpEventsStreamForUid(uid).listen(
      (value) {
        _xpEvents = value;
        _xpEventsError = null;
        _xpEventsReady = true;
        notifyListeners();
      },
      onError: (Object error) {
        _logAnalyticsError(
          uid: uid,
          operation: 'watchXpEvents',
          collection: 'profiles/$uid/xp_events',
          error: error,
        );
        _xpEventsError = error;
        _xpEventsReady = true;
        notifyListeners();
      },
    );

    _followingCountSub = _followService
        .watchFollowingCount(uid)
        .listen(
          (value) {
            _followingCount = value;
            _followingCountError = null;
            _followingCountReady = true;
            notifyListeners();
          },
          onError: (Object error) {
            _logAnalyticsError(
              uid: uid,
              operation: 'watchFollowingCount',
              collection: 'follows',
              error: error,
            );
            _followingCount = 0;
            _followingCountError = error;
            _followingCountReady = true;
            notifyListeners();
          },
        );

    _followerCountSub = _followService
        .watchFollowerCount(uid)
        .listen(
          (value) {
            _followerCount = value;
            _followerCountError = null;
            _followerCountReady = true;
            notifyListeners();
          },
          onError: (Object error) {
            _logAnalyticsError(
              uid: uid,
              operation: 'watchFollowerCount',
              collection: 'follows',
              error: error,
            );
            _followerCount = 0;
            _followerCountError = error;
            _followerCountReady = true;
            notifyListeners();
          },
        );
  }

  Stream<List<XpEvent>> _xpEventsStreamForUid(String uid) {
    final injected = _injectedXpEventsStream;
    if (injected != null) {
      return injected;
    }
    final profileService = _profileService;
    if (profileService == null) {
      // Widget tests often inject VisitService without Firebase ProfileService.
      return Stream<List<XpEvent>>.value(const <XpEvent>[]);
    }
    return profileService.watchXpEvents(uid);
  }

  void _logAnalyticsError({
    required String uid,
    required String operation,
    required String collection,
    required Object error,
  }) {
    final code = error is FirebaseException ? error.code : 'unknown';
    debugPrint(
      '[YouAnalytics] uid=$uid op=$operation collection=$collection '
      'code=$code error=$error',
    );
  }

  void _resetData() {
    _visits = const <Visit>[];
    _recentVisits = const <Visit>[];
    _tileRecords = const <VisitedPolygonRecord>[];
    _xpEvents = const <XpEvent>[];
    // Seed follow counts to 0 so ProfileStats never flash an em dash while
    // the first Firestore snapshot is in flight.
    _followingCount = 0;
    _followerCount = 0;
    _visitsReady = false;
    _recentVisitsReady = false;
    _tileRecordsReady = false;
    _xpEventsReady = false;
    _followingCountReady = true;
    _followerCountReady = true;
    _visitsError = null;
    _recentVisitsError = null;
    _tileRecordsError = null;
    _xpEventsError = null;
    _followingCountError = null;
    _followerCountError = null;
  }

  void _markAllReady() {
    _visitsReady = true;
    _recentVisitsReady = true;
    _tileRecordsReady = true;
    _xpEventsReady = true;
    _followingCountReady = true;
    _followerCountReady = true;
    _followingCount = 0;
    _followerCount = 0;
  }

  void _cancelSubscriptions() {
    _visitsSub?.cancel();
    _recentVisitsSub?.cancel();
    _tileRecordsSub?.cancel();
    _xpEventsSub?.cancel();
    _followingCountSub?.cancel();
    _followerCountSub?.cancel();
    _visitsSub = null;
    _recentVisitsSub = null;
    _tileRecordsSub = null;
    _xpEventsSub = null;
    _followingCountSub = null;
    _followerCountSub = null;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
