import 'dart:async';

import '../../journeys/data/journey_service.dart';
import '../../journeys/domain/journey.dart';
import '../../map/domain/visit_event.dart';
import '../../profile/domain/home_base.dart';
import '../../profile/domain/stats_summary.dart';
import '../../profile/domain/visited_polygon_meta.dart';
import '../providers/you_analytics_provider.dart';
import '../services/home_base_service.dart';
import '../services/stats_summary_service.dart';

/// Extended analytics provider for the Stats tab and profile header counts.
class StatsAnalyticsProvider extends YouAnalyticsProvider {
  StatsAnalyticsProvider({
    super.visitService,
    super.visitedRegionService,
    super.profileService,
    super.followService,
    super.xpEventsStream,
    JourneyService? journeyService,
    StatsSummaryService? statsSummaryService,
    HomeBaseService? homeBaseService,
  }) : _journeyService = journeyService ?? JourneyService(),
       _statsSummaryService = statsSummaryService ?? StatsSummaryService(),
       _homeBaseService = homeBaseService ?? HomeBaseService();

  final JourneyService _journeyService;
  final StatsSummaryService _statsSummaryService;
  final HomeBaseService _homeBaseService;

  StreamSubscription<List<VisitEvent>>? _visitEventsSub;
  StreamSubscription<List<Journey>>? _journeysSub;
  StreamSubscription<StatsSummary>? _summarySub;
  StreamSubscription<HomeBase?>? _homeBaseSub;
  StreamSubscription<Map<String, VisitedPolygonMeta>>? _polygonMetaSub;
  StreamSubscription<Map<String, int>>? _entryCountsSub;

  List<VisitEvent> _visitEvents = const <VisitEvent>[];
  List<Journey> _journeys = const <Journey>[];
  StatsSummary _statsSummary = const StatsSummary();
  HomeBase? _homeBase;
  Map<String, VisitedPolygonMeta> _polygonMeta =
      const <String, VisitedPolygonMeta>{};
  Map<String, int> _entryCounts = const <String, int>{};
  bool _visitEventsReady = false;
  bool _journeysReady = false;
  bool _summaryReady = false;
  bool _homeBaseReady = false;
  bool _polygonMetaReady = false;
  bool _entryCountsReady = false;

  List<VisitEvent> get visitEvents => _visitEvents;
  List<Journey> get journeys => _journeys;
  StatsSummary get statsSummary => _statsSummary;
  HomeBase? get homeBase => _homeBase;
  Map<String, VisitedPolygonMeta> get polygonMeta => _polygonMeta;
  Map<String, int> get entryCounts => _entryCounts;

  bool get visitEventsReady => _visitEventsReady;
  bool get journeysReady => _journeysReady;
  bool get summaryReady => _summaryReady;
  bool get homeBaseReady => _homeBaseReady;
  bool get polygonMetaReady => _polygonMetaReady;
  bool get entryCountsReady => _entryCountsReady;

  Future<void> setHomeBase({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final uid = boundUid;
    if (uid == null) return;

    await _homeBaseService.setHomeBase(
      uid: uid,
      lat: lat,
      lng: lng,
      label: label,
    );
  }

  Future<void> clearHomeBase() async {
    final uid = boundUid;
    if (uid == null) return;
    await _homeBaseService.clearHomeBase(uid);
  }

  @override
  void bindUid(String? uid) {
    super.bindUid(uid);

    _cancelExtendedSubscriptions();

    if (uid == null) {
      _resetExtendedData();
      _markExtendedReady();
      notifyListeners();
      return;
    }

    _resetExtendedData();
    _markExtendedReady();
    notifyListeners();

    _visitEventsSub = visitService
        .watchVisitEvents(uid)
        .listen(
          (value) {
            _visitEvents = value;
            _visitEventsReady = true;
            notifyListeners();
          },
          onError: (_) {
            _visitEventsReady = true;
            notifyListeners();
          },
        );

    _journeysSub = _journeyService
        .getJourneysStream(uid)
        .listen(
          (value) {
            _journeys = value;
            _journeysReady = true;
            notifyListeners();
          },
          onError: (_) {
            _journeysReady = true;
            notifyListeners();
          },
        );

    _summarySub = _statsSummaryService
        .watchSummary(uid)
        .listen(
          (value) {
            _statsSummary = value;
            _summaryReady = true;
            notifyListeners();
          },
          onError: (_) {
            _summaryReady = true;
            notifyListeners();
          },
        );

    _homeBaseSub = _homeBaseService
        .watchHomeBase(uid)
        .listen(
          (value) {
            _homeBase = value;
            _homeBaseReady = true;
            notifyListeners();
          },
          onError: (_) {
            _homeBaseReady = true;
            notifyListeners();
          },
        );

    _polygonMetaSub = visitedRegionService.watchVisitedPolygonMeta().listen(
      (value) {
        _polygonMeta = value;
        _polygonMetaReady = true;
        notifyListeners();
      },
      onError: (_) {
        _polygonMetaReady = true;
        notifyListeners();
      },
    );

    _entryCountsSub = visitedRegionService.watchPolygonEntryCounts().listen(
      (value) {
        _entryCounts = value;
        _entryCountsReady = true;
        notifyListeners();
      },
      onError: (_) {
        _entryCountsReady = true;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _cancelExtendedSubscriptions();
    super.dispose();
  }

  void _resetExtendedData() {
    _visitEvents = const <VisitEvent>[];
    _journeys = const <Journey>[];
    _statsSummary = const StatsSummary();
    _homeBase = null;
    _polygonMeta = const <String, VisitedPolygonMeta>{};
    _entryCounts = const <String, int>{};
    _visitEventsReady = false;
    _journeysReady = false;
    _summaryReady = false;
    _homeBaseReady = false;
    _polygonMetaReady = false;
    _entryCountsReady = false;
  }

  void _markExtendedReady() {
    _visitEventsReady = true;
    _journeysReady = true;
    _summaryReady = true;
    _homeBaseReady = true;
    _polygonMetaReady = true;
    _entryCountsReady = true;
  }

  void _cancelExtendedSubscriptions() {
    _visitEventsSub?.cancel();
    _journeysSub?.cancel();
    _summarySub?.cancel();
    _homeBaseSub?.cancel();
    _polygonMetaSub?.cancel();
    _entryCountsSub?.cancel();
    _visitEventsSub = null;
    _journeysSub = null;
    _summarySub = null;
    _homeBaseSub = null;
    _polygonMetaSub = null;
    _entryCountsSub = null;
  }
}
