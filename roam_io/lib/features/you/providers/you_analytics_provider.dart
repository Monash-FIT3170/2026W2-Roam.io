/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Session-scoped analytics for the You destination. Holds the latest visits,
 *   tile records, and XP events from live Firestore watches so Profile data
 *   survives TabBarView dispose/remount (Activities ↔ Profile) and Activity
 *   Detail push/pop. Prefer this over caching .asBroadcastStream() on the
 *   screen — broadcast streams do not replay the last snapshot.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/profile_service.dart';
import '../../map/data/visit.dart';
import '../../map/data/visit_service.dart';
import '../../map/data/visited_region_service.dart';
import '../../profile/domain/visited_polygon_record.dart';
import '../../profile/domain/xp_event.dart';

/// Owns You Profile analytics subscriptions for the signed-in uid.
class YouAnalyticsProvider extends ChangeNotifier {
  YouAnalyticsProvider({
    VisitService? visitService,
    VisitedRegionService? visitedRegionService,
    ProfileService? profileService,
    Stream<List<XpEvent>>? xpEventsStream,
  }) : _visitService = visitService ?? VisitService(),
       _visitedRegionService = visitedRegionService ?? VisitedRegionService(),
       _profileService = profileService,
       _injectedXpEventsStream = xpEventsStream;

  final VisitService _visitService;
  final VisitedRegionService _visitedRegionService;
  final ProfileService? _profileService;
  final Stream<List<XpEvent>>? _injectedXpEventsStream;

  String? _boundUid;
  StreamSubscription<List<Visit>>? _visitsSub;
  StreamSubscription<List<Visit>>? _recentVisitsSub;
  StreamSubscription<List<VisitedPolygonRecord>>? _tileRecordsSub;
  StreamSubscription<List<XpEvent>>? _xpEventsSub;

  List<Visit> _visits = const <Visit>[];
  List<Visit> _recentVisits = const <Visit>[];
  List<VisitedPolygonRecord> _tileRecords = const <VisitedPolygonRecord>[];
  List<XpEvent> _xpEvents = const <XpEvent>[];
  bool _visitsReady = false;
  bool _recentVisitsReady = false;
  bool _tileRecordsReady = false;
  bool _xpEventsReady = false;
  Object? _recentVisitsError;

  List<Visit> get visits => _visits;
  List<Visit> get recentVisits => _recentVisits;
  List<VisitedPolygonRecord> get tileRecords => _tileRecords;
  List<XpEvent> get xpEvents => _xpEvents;

  bool get visitsReady => _visitsReady;
  bool get recentVisitsReady => _recentVisitsReady;
  bool get tileRecordsReady => _tileRecordsReady;
  bool get xpEventsReady => _xpEventsReady;
  Object? get recentVisitsError => _recentVisitsError;

  String? get boundUid => _boundUid;

  /// Binds (or rebinds) live watches to [uid]. No-ops when uid is unchanged.
  void bindUid(String? uid) {
    if (_boundUid == uid && uid == null) {
      return;
    }
    if (_boundUid == uid &&
        _visitsSub != null &&
        _recentVisitsSub != null &&
        _tileRecordsSub != null &&
        _xpEventsSub != null) {
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

    // Expose empty latest lists immediately so remounts / widget tests never
    // stick on an infinite waiting spinner if the first snapshot is delayed.
    _markAllReady();
    notifyListeners();

    _visitsSub = _visitService
        .watchAllVisits(uid)
        .listen(
          (value) {
            _visits = value;
            _visitsReady = true;
            notifyListeners();
          },
          onError: (_) {
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
            _recentVisitsError = error;
            _recentVisitsReady = true;
            notifyListeners();
          },
        );

    _tileRecordsSub = _visitedRegionService.watchVisitedPolygonRecords().listen(
      (value) {
        _tileRecords = value;
        _tileRecordsReady = true;
        notifyListeners();
      },
      onError: (_) {
        _tileRecordsReady = true;
        notifyListeners();
      },
    );

    _xpEventsSub = _xpEventsStreamForUid(uid).listen(
      (value) {
        _xpEvents = value;
        _xpEventsReady = true;
        notifyListeners();
      },
      onError: (_) {
        _xpEventsReady = true;
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

  void _resetData() {
    _visits = const <Visit>[];
    _recentVisits = const <Visit>[];
    _tileRecords = const <VisitedPolygonRecord>[];
    _xpEvents = const <XpEvent>[];
    _visitsReady = false;
    _recentVisitsReady = false;
    _tileRecordsReady = false;
    _xpEventsReady = false;
    _recentVisitsError = null;
  }

  void _markAllReady() {
    _visitsReady = true;
    _recentVisitsReady = true;
    _tileRecordsReady = true;
    _xpEventsReady = true;
  }

  void _cancelSubscriptions() {
    _visitsSub?.cancel();
    _recentVisitsSub?.cancel();
    _tileRecordsSub?.cancel();
    _xpEventsSub?.cancel();
    _visitsSub = null;
    _recentVisitsSub = null;
    _tileRecordsSub = null;
    _xpEventsSub = null;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
