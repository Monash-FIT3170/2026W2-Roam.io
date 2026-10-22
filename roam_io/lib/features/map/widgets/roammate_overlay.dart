import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/liquid_glass.dart';
import '../../../theme/app_colours.dart';
import '../../auth/providers/auth_provider.dart';
import '../../hazards/data/hazard_controller.dart';
import '../../hazards/domain/hazard_report.dart';
import '../../roammate/domain/roammate_message.dart';
import '../../roammate/services/roammate_voice_service.dart';
import '../data/map_controller.dart';
import '../data/place_of_interest.dart';
import '../data/places_service.dart';
import '../../journeys/data/journey_controller.dart';
import '../data/region_polygon.dart';

class _TileBannerData {
  final String regionId;
  final String regionName;

  const _TileBannerData({required this.regionId, required this.regionName});
}

class _RecommendationData {
  final PlaceOfInterest place;
  final int distanceMeters;
  final String regionName;

  const _RecommendationData({
    required this.place,
    required this.distanceMeters,
    required this.regionName,
  });
}

class RoammateOverlay extends StatefulWidget {
  final MapController mapController;
  final HazardController? hazardController;
  final JourneyController? journeyController;
  final void Function(HazardReport report)? onHazardSelected;
  final void Function(PlaceOfInterest place)? onPlaceSelected;
  final RoammateVoiceService? voiceService;
  final PlacesService? placesService;
  final double proximityRadiusMeters;
  final Duration tileDwellDuration;
  final Duration autoCollapseDuration;
  final Duration recommendationAutoCollapseDuration;
  final Duration tileAnnouncementCooldown;
  final double maxSpeedMpsForPopup;

  const RoammateOverlay({
    super.key,
    required this.mapController,
    this.hazardController,
    this.journeyController,
    this.onHazardSelected,
    this.onPlaceSelected,
    this.voiceService,
    this.placesService,
    this.proximityRadiusMeters = 500.0,
    this.tileDwellDuration = const Duration(milliseconds: 3500),
    this.autoCollapseDuration = const Duration(seconds: 5),
    this.recommendationAutoCollapseDuration = const Duration(seconds: 8),
    this.tileAnnouncementCooldown = const Duration(minutes: 3),
    this.maxSpeedMpsForPopup = 25.0 / 3.6,
  });

  @override
  State<RoammateOverlay> createState() => _RoammateOverlayState();
}

class _RoammateOverlayState extends State<RoammateOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;

  String? _lastRegionId;
  String? _currentRegionId;
  bool _hasAnnouncedCurrentTileVisit = false;
  Timer? _tileEntryDwellTimer;
  Timer? _autoCollapseTimer;
  final Map<String, DateTime> _tileLastAnnouncedAt = {};
  _TileBannerData? _tileBannerData;

  bool _firstTileUnlockTriggered = false;
  double _lastMilestoneDistanceMeters = 0.0;
  final Set<int> _recommendedPlaceIds = {};
  final Map<String, List<PlaceOfInterest>> _cachedPlacesByTile = {};
  _RecommendationData? _recommendationData;

  bool _showDetails = false;
  bool _isHazardsExpanded = false;

  List<PlaceOfInterest> _allPlaces = [];
  final Set<String> _spokenHazardIds = {};

  late final PlacesService _placesService =
      widget.placesService ?? PlacesService();

  // ValueNotifiers for dynamic scroll shadows
  final ValueNotifier<bool> _canScrollUp = ValueNotifier(false);
  final ValueNotifier<bool> _canScrollDown = ValueNotifier(true);

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    widget.mapController.addListener(_onMapControllerChanged);
    widget.hazardController?.addListener(_onHazardControllerChanged);
    widget.journeyController?.addListener(_onJourneyControllerChanged);
    _onMapControllerChanged();
    _checkJourneyRecommendations();
  }

  @override
  void didUpdateWidget(RoammateOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapController != widget.mapController) {
      oldWidget.mapController.removeListener(_onMapControllerChanged);
      widget.mapController.addListener(_onMapControllerChanged);
    }
    if (oldWidget.hazardController != widget.hazardController) {
      oldWidget.hazardController?.removeListener(_onHazardControllerChanged);
      widget.hazardController?.addListener(_onHazardControllerChanged);
      _checkAndAnnounceHazards();
    }
    if (oldWidget.journeyController != widget.journeyController) {
      oldWidget.journeyController?.removeListener(_onJourneyControllerChanged);
      widget.journeyController?.addListener(_onJourneyControllerChanged);
      _checkJourneyRecommendations();
    }
  }

  @override
  void dispose() {
    widget.mapController.removeListener(_onMapControllerChanged);
    widget.hazardController?.removeListener(_onHazardControllerChanged);
    widget.journeyController?.removeListener(_onJourneyControllerChanged);
    _cancelDwellTimer();
    _cancelAutoCollapseTimer();
    _breathingController.dispose();
    _canScrollUp.dispose();
    _canScrollDown.dispose();
    super.dispose();
  }

  void _onJourneyControllerChanged() {
    _checkJourneyRecommendations();
  }

  void _cancelDwellTimer() {
    _tileEntryDwellTimer?.cancel();
    _tileEntryDwellTimer = null;
  }

  void _startAutoCollapseTimer() {
    _cancelAutoCollapseTimer();
    _autoCollapseTimer = Timer(widget.autoCollapseDuration, () {
      if (!mounted) return;
      setState(() {
        _showDetails = false;
        _tileBannerData = null;
        _recommendationData = null;
      });
    });
  }

  void _startRecommendationAutoCollapseTimer() {
    _cancelAutoCollapseTimer();
    _autoCollapseTimer = Timer(widget.recommendationAutoCollapseDuration, () {
      if (!mounted) return;
      setState(() {
        _showDetails = false;
        _recommendationData = null;
      });
    });
  }

  void _cancelAutoCollapseTimer() {
    _autoCollapseTimer?.cancel();
    _autoCollapseTimer = null;
  }

  void _checkTileEntryNotification(RegionPolygon? currentRegion) {
    if (currentRegion == null) {
      _currentRegionId = null;
      _hasAnnouncedCurrentTileVisit = false;
      _cancelDwellTimer();
      return;
    }

    // Entering a new tile
    if (currentRegion.id != _currentRegionId) {
      _currentRegionId = currentRegion.id;
      _hasAnnouncedCurrentTileVisit = false;
      _cancelDwellTimer();
    }

    // If already announced for this current visit, do nothing
    if (_hasAnnouncedCurrentTileVisit) {
      return;
    }

    // Check cooldown for this tile
    final lastAnnounced = _tileLastAnnouncedAt[currentRegion.id];
    if (lastAnnounced != null &&
        DateTime.now().difference(lastAnnounced) <
            widget.tileAnnouncementCooldown) {
      return;
    }

    // Check travel speed
    final speed = widget.mapController.userSpeedMps;
    if (speed > widget.maxSpeedMpsForPopup) {
      _cancelDwellTimer();
      return;
    }

    // If dwell timer is already active for this region, let it run
    if (_tileEntryDwellTimer != null) {
      return;
    }

    // Start dwell timer
    _tileEntryDwellTimer = Timer(widget.tileDwellDuration, () {
      _tileEntryDwellTimer = null;
      if (!mounted) return;

      // Verify user is still in the same region
      final activeRegion = widget.mapController.currentRegion;
      if (activeRegion == null || activeRegion.id != currentRegion.id) {
        return;
      }

      // Verify speed is still within limits
      if (widget.mapController.userSpeedMps > widget.maxSpeedMpsForPopup) {
        return;
      }

      _hasAnnouncedCurrentTileVisit = true;
      _tileLastAnnouncedAt[currentRegion.id] = DateTime.now();

      final wasAlreadyOpen = _showDetails;
      setState(() {
        _tileBannerData = _TileBannerData(
          regionId: currentRegion.id,
          regionName: currentRegion.name,
        );
        _showDetails = true;
      });

      if (!wasAlreadyOpen) {
        _startAutoCollapseTimer();
      }
    });
  }

  void _onMapControllerChanged() {
    final currentRegion = widget.mapController.currentRegion;
    if (currentRegion != null && currentRegion.id != _lastRegionId) {
      _lastRegionId = currentRegion.id;
      _fetchRegionData(currentRegion.id, currentRegion.name);
    } else if (currentRegion == null && _lastRegionId != null) {
      _lastRegionId = null;
    }
    _checkTileEntryNotification(currentRegion);
    _checkAndAnnounceHazards();
    if (mounted) {
      setState(() {});
    }
  }

  void _onHazardControllerChanged() {
    _checkAndAnnounceHazards();
    if (mounted) {
      setState(() {});
    }
  }

  LatLng get _currentLocation =>
      widget.mapController.latestUserLatLng ?? widget.mapController.center;

  static double _haversineDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000;
    final double lat1Rad = p1.latitude * math.pi / 180;
    final double lat2Rad = p2.latitude * math.pi / 180;
    final double dLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final double dLng = (p2.longitude - p1.longitude) * math.pi / 180;

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  List<({HazardReport report, double distance})> get _nearbyHazards {
    final hazardController = widget.hazardController;
    if (hazardController == null) return const [];

    final userLocation = _currentLocation;
    final nearby = <({HazardReport report, double distance})>[];

    for (final report in hazardController.activeReports) {
      final distance = _haversineDistance(userLocation, report.location);
      if (distance <= widget.proximityRadiusMeters) {
        nearby.add((report: report, distance: distance));
      }
    }

    nearby.sort((a, b) => a.distance.compareTo(b.distance));
    return nearby;
  }

  void _checkAndAnnounceHazards() {
    final nearby = _nearbyHazards;
    if (nearby.isEmpty) return;

    final voiceService = widget.voiceService ?? RoammateVoiceService.instance;
    bool voiceEnabled = false;
    try {
      voiceEnabled = context.read<AuthProvider>().roammateVoiceEnabled;
    } catch (_) {
      voiceEnabled = false;
    }

    if (!voiceEnabled) return;

    for (final item in nearby) {
      if (!_spokenHazardIds.contains(item.report.id)) {
        _spokenHazardIds.add(item.report.id);
        final distanceRounded = item.distance.round();
        final message = RoammateMessage.hazardNearby(
          hazardCategoryLabel: item.report.category.displayLabel,
          distanceMeters: distanceRounded,
        );
        unawaited(voiceService.speak(message.speech));
        break;
      }
    }
  }

  Future<void> _fetchRegionData(String regionId, String regionName) async {
    try {
      final places = await _placesService.getPlacesForRegion(
        regionId: regionId,
      );
      if (mounted) {
        setState(() {
          // Filter out public transport (like bus stops) from the locations list
          _allPlaces = places
              .where((p) => p.category != PlaceCategory.publicTransport)
              .toList();
          _cachedPlacesByTile[regionId] = _allPlaces;
        });
        _checkJourneyRecommendations();
      }
    } catch (e) {
      // ignore
    }
  }

  void _toggleDetails() {
    _cancelAutoCollapseTimer();
    setState(() {
      _showDetails = !_showDetails;
      if (!_showDetails) {
        _tileBannerData = null;
        _recommendationData = null;
      }
    });
  }

  void _handleHazardTapped(HazardReport report) {
    _cancelAutoCollapseTimer();
    widget.mapController.animateToLocation(report.location);
    widget.onHazardSelected?.call(report);
    setState(() {
      _showDetails = false;
      _tileBannerData = null;
      _recommendationData = null;
    });
  }

  List<PlaceOfInterest> get _sortedPlaces {
    final places = List<PlaceOfInterest>.from(_allPlaces);
    places.sort((a, b) {
      final aVisited = widget.mapController.isPlaceVisited(a.id);
      final bVisited = widget.mapController.isPlaceVisited(b.id);
      if (aVisited == bVisited) return a.name.compareTo(b.name);
      return aVisited ? 1 : -1;
    });
    return places;
  }

  Widget _buildLocationCard(
    PlaceOfInterest p,
    bool isVisited,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    // Colors matching AppColors
    final unvisitedBg = isDark ? Colors.white10 : Colors.white;
    final unvisitedText = isDark ? AppColors.cream : AppColors.ink;
    final unvisitedBorder = isDark ? Colors.white24 : AppColors.sand;

    final visitedBg = isDark ? AppColors.lightSage : AppColors.sage;
    final visitedText = isDark ? AppColors.ink : AppColors.cream;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isVisited ? visitedBg : unvisitedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVisited ? Colors.transparent : unvisitedBorder,
          width: 1,
        ),
      ),
      child: Text(
        p.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isVisited ? visitedText : unvisitedText,
          fontWeight: isVisited ? FontWeight.bold : FontWeight.w500,
          decoration: isVisited ? TextDecoration.lineThrough : null,
          decorationColor: isVisited ? visitedText : null,
          decorationThickness: isVisited ? 2.0 : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleColor = isDark ? AppColors.cream : AppColors.ink;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // The detail box morphing up
        if (_showDetails)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  alignment: Alignment.bottomRight,
                  child: child,
                );
              },
              child: Listener(
                onPointerDown: (_) => _cancelAutoCollapseTimer(),
                behavior: HitTestBehavior.translucent,
                child: LiquidGlass(
                  tint: null,
                  borderRadius: BorderRadius.circular(24),
                  opacity: isDark ? 0.18 : 0.78,
                  child: Container(
                    width: 280,
                    constraints: const BoxConstraints(maxHeight: 440),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Active contextual recommendation banner
                        if (_recommendationData != null) ...[
                          _buildRecommendationBanner(
                            theme: theme,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                        ] else if (_tileBannerData != null) ...[
                          _buildTileEntryBanner(theme: theme, isDark: isDark),
                          const SizedBox(height: 12),
                        ],

                        // Active community hazards section
                        if (_nearbyHazards.isNotEmpty) ...[
                          _buildHazardSection(theme: theme, isDark: isDark),
                          const SizedBox(height: 16),
                        ],

                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Locations in this tile',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),

                        if (_allPlaces.isEmpty)
                          Text(
                            'No locations available.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: titleColor.withValues(alpha: 0.6),
                            ),
                          )
                        else
                          Flexible(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification.metrics.axis ==
                                    Axis.vertical) {
                                  _canScrollUp.value =
                                      notification.metrics.extentBefore > 0;
                                  _canScrollDown.value =
                                      notification.metrics.extentAfter > 0;
                                }
                                return false; // Let the scrollbar handle it too
                              },
                              child: Stack(
                                children: [
                                  Scrollbar(
                                    thumbVisibility: true,
                                    child: ListView(
                                      padding: const EdgeInsets.only(
                                        right: 8,
                                      ), // Padding for scrollbar
                                      shrinkWrap: true,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      children: _sortedPlaces.map((p) {
                                        final isVisited = widget.mapController
                                            .isPlaceVisited(p.id);
                                        return _buildLocationCard(
                                          p,
                                          isVisited,
                                          theme,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  // Top Scroll Shadow
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: ValueListenableBuilder<bool>(
                                      valueListenable: _canScrollUp,
                                      builder: (context, canScrollUp, child) {
                                        return IgnorePointer(
                                          child: AnimatedOpacity(
                                            opacity: canScrollUp ? 1.0 : 0.0,
                                            duration: const Duration(
                                              milliseconds: 150,
                                            ),
                                            child: Container(
                                              height: 12,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    isDark
                                                        ? Colors.black
                                                              .withValues(
                                                                alpha: 0.4,
                                                              )
                                                        : Colors.black
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Bottom Scroll Shadow
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: ValueListenableBuilder<bool>(
                                      valueListenable: _canScrollDown,
                                      builder: (context, canScrollDown, child) {
                                        return IgnorePointer(
                                          child: AnimatedOpacity(
                                            opacity: canScrollDown ? 1.0 : 0.0,
                                            duration: const Duration(
                                              milliseconds: 150,
                                            ),
                                            child: Container(
                                              height: 12,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    isDark
                                                        ? Colors.black
                                                              .withValues(
                                                                alpha: 0.4,
                                                              )
                                                        : Colors.black
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // The breathing avatar
        GestureDetector(
          onTap: _toggleDetails,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: LiquidGlass(
              borderRadius: BorderRadius.circular(24),
              child: const SizedBox.square(
                dimension: 48,
                child: Center(
                  child: Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationBanner({
    required ThemeData theme,
    required bool isDark,
  }) {
    final rec = _recommendationData;
    if (rec == null) return const SizedBox.shrink();

    final ratingText = rec.place.rating != null ? ' ★ ${rec.place.rating}' : '';
    final distanceText = ' • ${rec.distanceMeters}m away';
    final bannerText =
        'Roammate suggests: ${rec.place.name}$ratingText$distanceText';

    final bannerBg = isDark
        ? AppColors.lightSage.withValues(alpha: 0.22)
        : AppColors.sage.withValues(alpha: 0.15);
    final bannerBorder = isDark
        ? AppColors.lightSage.withValues(alpha: 0.5)
        : AppColors.sage;
    final iconColor = isDark ? AppColors.lightSage : AppColors.sage;
    final textColor = isDark ? AppColors.cream : AppColors.ink;

    return Container(
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerBorder, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _cancelAutoCollapseTimer();
                  widget.mapController.animateToLocation(rec.place.location);
                  widget.onPlaceSelected?.call(rec.place);
                  setState(() {
                    _showDetails = false;
                    _recommendationData = null;
                  });
                },
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: iconColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bannerText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: iconColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _cancelAutoCollapseTimer();
                  setState(() {
                    _recommendationData = null;
                    _showDetails = false;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PlaceOfInterest? _selectBestRecommendation(List<PlaceOfInterest> places) {
    final candidates = places.where((p) {
      if (widget.mapController.isPlaceVisited(p.id)) return false;
      if (p.category == PlaceCategory.publicTransport) return false;
      if (_recommendedPlaceIds.contains(p.id)) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    final userLoc = _currentLocation;

    candidates.sort((a, b) {
      // 1. Rating descending
      final aRating = a.rating ?? -1.0;
      final bRating = b.rating ?? -1.0;
      if (aRating != bRating) {
        return bRating.compareTo(aRating);
      }
      // 2. Proximity to user (closest first)
      final aDist = _haversineDistance(userLoc, a.location);
      final bDist = _haversineDistance(userLoc, b.location);
      return aDist.compareTo(bDist);
    });

    return candidates.first;
  }

  Future<List<PlaceOfInterest>> _getPlacesForTile(String tileId) async {
    if (widget.mapController.currentRegion?.id == tileId &&
        _allPlaces.isNotEmpty) {
      return _allPlaces;
    }
    if (_cachedPlacesByTile.containsKey(tileId)) {
      return _cachedPlacesByTile[tileId]!;
    }
    try {
      final places = await _placesService.getPlacesForRegion(regionId: tileId);
      final filtered = places
          .where((p) => p.category != PlaceCategory.publicTransport)
          .toList();
      _cachedPlacesByTile[tileId] = filtered;
      return filtered;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _checkJourneyRecommendations() async {
    final journey = widget.journeyController;
    if (journey == null) return;

    if (!journey.isTracking) {
      _firstTileUnlockTriggered = false;
      _lastMilestoneDistanceMeters = 0.0;
      _recommendedPlaceIds.clear();
      return;
    }

    if (_recommendationData != null) return;

    // Trigger 1: First tile unlock of the journey
    if (!_firstTileUnlockTriggered && journey.unlockedTileIds.isNotEmpty) {
      final tileId = journey.unlockedTileIds.last;
      final regionName = widget.mapController.currentRegion?.id == tileId
          ? widget.mapController.currentRegion?.name ?? 'your journey'
          : 'your journey';

      final places = await _getPlacesForTile(tileId);
      final best = _selectBestRecommendation(places);
      if (best != null) {
        _firstTileUnlockTriggered = true;
        _triggerRecommendation(best, regionName: regionName);
        return;
      }
    }

    // Trigger 2: 1 km (1,000 m) distance milestones
    final distance = journey.distanceMeters;
    final currentMilestone = (distance / 1000.0).floor() * 1000.0;
    if (currentMilestone >= 1000.0 &&
        currentMilestone > _lastMilestoneDistanceMeters) {
      _lastMilestoneDistanceMeters = currentMilestone;

      for (final tileId in journey.unlockedTileIds) {
        final places = await _getPlacesForTile(tileId);
        final best = _selectBestRecommendation(places);
        if (best != null) {
          _triggerRecommendation(best, regionName: 'your journey');
          return;
        }
      }
    }
  }

  void _triggerRecommendation(
    PlaceOfInterest place, {
    required String regionName,
  }) {
    _recommendedPlaceIds.add(place.id);
    final dist = _haversineDistance(_currentLocation, place.location).round();

    setState(() {
      _recommendationData = _RecommendationData(
        place: place,
        distanceMeters: dist,
        regionName: regionName,
      );
      _showDetails = true;
    });

    _startRecommendationAutoCollapseTimer();

    final voiceService = widget.voiceService ?? RoammateVoiceService.instance;
    bool voiceEnabled = false;
    try {
      voiceEnabled = context.read<AuthProvider>().roammateVoiceEnabled;
    } catch (_) {
      voiceEnabled = false;
    }

    if (voiceEnabled) {
      final message = RoammateMessage.journeyRecommendation(
        placeName: place.name,
        rating: place.rating,
        distanceMeters: dist,
        regionName: regionName,
      );
      unawaited(voiceService.speak(message.speech));
    }
  }

  Widget _buildTileEntryBanner({
    required ThemeData theme,
    required bool isDark,
  }) {
    final banner = _tileBannerData;
    if (banner == null) return const SizedBox.shrink();

    final locationsCount = _allPlaces.length;
    final hazardsCount = _nearbyHazards.length;
    final locText =
        '$locationsCount ${locationsCount == 1 ? 'location' : 'locations'}';
    final hazText = '$hazardsCount ${hazardsCount == 1 ? 'hazard' : 'hazards'}';
    final bannerText = 'Entered ${banner.regionName} • $locText, $hazText';

    final bannerBg = isDark
        ? AppColors.lightSage.withValues(alpha: 0.18)
        : AppColors.sage.withValues(alpha: 0.12);
    final bannerBorder = isDark
        ? AppColors.lightSage.withValues(alpha: 0.35)
        : AppColors.sage.withValues(alpha: 0.35);
    final iconColor = isDark ? AppColors.lightSage : AppColors.sage;
    final textColor = isDark ? AppColors.cream : AppColors.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.explore_rounded, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bannerText,
              style: theme.textTheme.labelMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _cancelAutoCollapseTimer();
                setState(() {
                  _tileBannerData = null;
                  _showDetails = false;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHazardSection({required ThemeData theme, required bool isDark}) {
    final nearby = _nearbyHazards;
    if (nearby.isEmpty) return const SizedBox.shrink();

    final hazardBg = isDark ? const Color(0x33EF4444) : const Color(0xFFFEF2F2);
    final hazardBorder = isDark
        ? const Color(0x66EF4444)
        : const Color(0xFFFECACA);
    final hazardTitleColor = isDark
        ? const Color(0xFFFCA5A5)
        : const Color(0xFF7F1D1D);
    final hazardSubtitleColor = isDark
        ? const Color(0xFFF87171)
        : const Color(0xFF991B1B);
    final hazardIconColor = isDark
        ? const Color(0xFFF87171)
        : const Color(0xFFDC2626);

    if (nearby.length == 1) {
      return _buildHazardItemCard(
        item: nearby.first,
        theme: theme,
        isDark: isDark,
        hazardBg: hazardBg,
        hazardBorder: hazardBorder,
        hazardTitleColor: hazardTitleColor,
        hazardSubtitleColor: hazardSubtitleColor,
        hazardIconColor: hazardIconColor,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _isHazardsExpanded = !_isHazardsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: hazardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hazardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: hazardIconColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${nearby.length} Hazards Nearby',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: hazardTitleColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Closest ${nearby.first.distance.round()}m away',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: hazardSubtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isHazardsExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: hazardIconColor,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isHazardsExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: nearby.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = nearby[index];
                  return _buildHazardItemCard(
                    item: item,
                    theme: theme,
                    isDark: isDark,
                    hazardBg: hazardBg,
                    hazardBorder: hazardBorder,
                    hazardTitleColor: hazardTitleColor,
                    hazardSubtitleColor: hazardSubtitleColor,
                    hazardIconColor: hazardIconColor,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHazardItemCard({
    required ({HazardReport report, double distance}) item,
    required ThemeData theme,
    required bool isDark,
    required Color hazardBg,
    required Color hazardBorder,
    required Color hazardTitleColor,
    required Color hazardSubtitleColor,
    required Color hazardIconColor,
  }) {
    final report = item.report;
    final distanceMeters = item.distance.round();
    final description = report.description?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleHazardTapped(report),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: hazardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hazardBorder),
          ),
          child: Row(
            children: [
              Icon(report.category.icon, color: hazardIconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            report.category.displayLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: hazardTitleColor,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${distanceMeters}m away',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: hazardSubtitleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: hazardSubtitleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: hazardIconColor,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
