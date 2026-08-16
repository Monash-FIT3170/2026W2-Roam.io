/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Watches milestone claims and awards XP when a tier is claimed.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/providers/auth_provider.dart';
import '../../profile/domain/xp_award_result.dart';
import '../../profile/domain/xp_event.dart';
import '../providers/stats_analytics_provider.dart';
import '../services/stats_aggregation_service.dart';
import 'milestone_catalog.dart';
import 'milestone_progress.dart';
import 'milestone_service.dart';

/// Coordinates milestone progress evaluation and claim + XP award.
class MilestonesProvider extends ChangeNotifier {
  MilestonesProvider({
    required StatsAnalyticsProvider analytics,
    MilestoneService? milestoneService,
    StatsAggregationService aggregationService =
        const StatsAggregationService(),
    MilestoneProgressBuilder progressBuilder = const MilestoneProgressBuilder(),
  }) : _analytics = analytics,
       _milestoneService = milestoneService ?? MilestoneService(),
       _aggregationService = aggregationService,
       _progressBuilder = progressBuilder {
    _analytics.addListener(_onAnalyticsChanged);
  }

  final StatsAnalyticsProvider _analytics;
  final MilestoneService _milestoneService;
  final StatsAggregationService _aggregationService;
  final MilestoneProgressBuilder _progressBuilder;

  StreamSubscription<Map<MilestoneId, MilestoneClaimState>>? _claimsSub;
  String? _boundUid;
  Map<MilestoneId, MilestoneClaimState> _claims =
      const <MilestoneId, MilestoneClaimState>{};
  bool _claimsReady = false;
  bool _claimInFlight = false;
  String? _claimError;
  MilestoneId? _lastClaimedMilestoneId;
  int? _lastClaimedTier;

  String? get boundUid => _boundUid;
  bool get claimsReady => _claimsReady;
  bool get claimInFlight => _claimInFlight;
  String? get claimError => _claimError;
  MilestoneId? get lastClaimedMilestoneId => _lastClaimedMilestoneId;
  int? get lastClaimedTier => _lastClaimedTier;

  List<MilestoneProgress> get progressList {
    return _progressBuilder.buildAll(
      claims: _claims,
      metrics: _metricsFromAnalytics(),
    );
  }

  int get totalPendingClaims =>
      progressList.fold<int>(0, (sum, item) => sum + item.pendingClaimCount);

  void bindUid(String? uid) {
    if (_boundUid == uid) return;
    _boundUid = uid;
    _claimsSub?.cancel();
    _claimsSub = null;
    _claims = const <MilestoneId, MilestoneClaimState>{};
    _claimsReady = false;
    _claimError = null;

    if (uid == null) {
      _claimsReady = true;
      notifyListeners();
      return;
    }

    _claimsSub = _milestoneService.watchClaims(uid).listen(
      (claims) {
        _claims = claims;
        _claimsReady = true;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '[MilestonesProvider] claims watch failed: $error\n$stackTrace',
        );
        _claimsReady = true;
        notifyListeners();
      },
    );
    notifyListeners();
  }

  void clearClaimFlash() {
    _lastClaimedMilestoneId = null;
    _lastClaimedTier = null;
    notifyListeners();
  }

  /// Claims the next claimable tier for [milestoneId], then awards XP.
  /// Returns the award result on success, or null if the claim did not complete.
  Future<XpAwardResult?> claimNextTier({
    required MilestoneId milestoneId,
    required AuthProvider auth,
  }) async {
    final uid = _boundUid;
    if (uid == null || _claimInFlight) return null;

    final progress = progressList.firstWhere(
      (item) => item.definition.id == milestoneId,
    );
    final tier = progress.nextClaimableTier;
    if (tier == null) return null;

    // Re-validate against live metrics before writing.
    final earnedNow = progress.definition.earnedTier(
      _metricsFromAnalytics().valueFor(milestoneId),
    );
    if (tier > earnedNow) return null;

    final xp = progress.definition.tierDefinition(tier).xpReward;
    _claimInFlight = true;
    _claimError = null;
    notifyListeners();

    try {
      final claimed = await _milestoneService.claimTier(
        uid: uid,
        milestoneId: milestoneId,
        tier: tier,
      );
      if (!claimed) {
        _claimInFlight = false;
        notifyListeners();
        return null;
      }

      final XpAwardResult award = await auth.addXp(
        xp,
        source: XpEventSource.milestone,
        sourceId: '${milestoneId.wireValue}:$tier',
      );

      if (!award.succeeded) {
        await _milestoneService.unclaimTier(
          uid: uid,
          milestoneId: milestoneId,
          tier: tier,
        );
        _claimError = 'Could not award XP. Try again.';
        _claimInFlight = false;
        notifyListeners();
        return null;
      }

      _lastClaimedMilestoneId = milestoneId;
      _lastClaimedTier = tier;
      _claimInFlight = false;
      // Always celebrate milestone XP (level-ups are also queued by addXp).
      auth.requestXpCelebration(award);
      notifyListeners();
      return award;
    } catch (error, stackTrace) {
      debugPrint(
        '[MilestonesProvider] claim failed: $error\n$stackTrace',
      );
      _claimError = 'Claim failed. Try again.';
      _claimInFlight = false;
      notifyListeners();
      return null;
    }
  }

  MilestoneMetrics _metricsFromAnalytics() {
    final summary = _analytics.statsSummary;
    final revealed = _aggregationService.revealedAreaSquareMetres(
      summary: summary,
      polygonMeta: _analytics.polygonMeta,
      tileCount: _aggregationService.tileCountFromSummary(
        summary,
        _analytics.tileRecords,
      ),
    );
    final visits = _aggregationService.totalVisitEvents(_analytics.visits);
    final journeyCount = summary.totalJourneys > 0
        ? summary.totalJourneys
        : _analytics.journeys.length;
    final distanceMeters = summary.totalDistanceMeters > 0
        ? summary.totalDistanceMeters
        : _analytics.journeys.fold<double>(
            0,
            (sum, journey) => sum + journey.distanceMeters,
          );
    final journeySeconds = summary.totalJourneySeconds > 0
        ? summary.totalJourneySeconds
        : _analytics.journeys.fold<int>(
            0,
            (sum, journey) => sum + journey.durationSeconds,
          );

    return MilestoneMetrics(
      areaKm2: revealed.squareMetres / 1_000_000,
      tilesUnlocked: _aggregationService.tileCountFromSummary(
        summary,
        _analytics.tileRecords,
      ),
      totalVisits: visits,
      journeyCount: journeyCount,
      distanceKm: distanceMeters / 1000,
      journeyHours: journeySeconds / 3600,
      xpStreakDays: summary.currentXpStreakDays,
    );
  }

  void _onAnalyticsChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _analytics.removeListener(_onAnalyticsChanged);
    _claimsSub?.cancel();
    super.dispose();
  }
}
