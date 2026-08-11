import '../../../services/polygon_service.dart';
import '../../map/data/region_polygon.dart';
import 'stats_summary_service.dart';

/// Central hook for exploration-related persistence used by map tracking.
///
/// Future comfort-zone, route-efficiency, and map-decay logic should extend
/// this service rather than scattering writes across [MapController].
class ExplorationStatsService {
  ExplorationStatsService({
    PolygonService? polygonService,
    StatsSummaryService? statsSummaryService,
  }) : _polygonService = polygonService ?? PolygonService(),
       _statsSummaryService = statsSummaryService ?? StatsSummaryService();

  final PolygonService _polygonService;
  final StatsSummaryService _statsSummaryService;

  /// Persists a first-time tile unlock with enriched metadata.
  ///
  /// Returns true only when this call created a new unlock record.
  Future<bool> recordUnlock({
    required String profileId,
    required RegionPolygon region,
    DateTime? visitedAt,
  }) async {
    final time = visitedAt ?? DateTime.now();
    final didUnlock = await _polygonService.upsertVisitedPolygon(
      profileId: profileId,
      polygonId: region.id,
      visitedAt: time,
      areaSquareMetres: region.areaSquareMetres,
      name: region.name,
    );

    if (didUnlock) {
      await _statsSummaryService.recordTileUnlock(
        uid: profileId,
        areaSquareMetres: region.areaSquareMetres ?? 0,
      );
    }

    return didUnlock;
  }

  /// Records a re-entry into an already unlocked tile.
  Future<void> recordReentry({
    required String profileId,
    required String polygonId,
    DateTime? enteredAt,
  }) async {
    await _polygonService.recordPolygonReentry(
      profileId: profileId,
      polygonId: polygonId,
      enteredAt: enteredAt ?? DateTime.now(),
    );
  }
}
