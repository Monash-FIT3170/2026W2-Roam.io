import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colours.dart';
import '../../auth/providers/auth_provider.dart';
import '../../hazards/data/hazard_controller.dart';
import '../../hazards/domain/hazard_report.dart';
import '../../roammate/domain/roammate_message.dart';
import '../../roammate/services/roammate_voice_service.dart';
import '../data/map_controller.dart';
import '../data/place_of_interest.dart';
import '../data/places_service.dart';

class RoammateOverlay extends StatefulWidget {
  final MapController mapController;
  final HazardController? hazardController;
  final void Function(HazardReport report)? onHazardSelected;
  final RoammateVoiceService? voiceService;
  final double proximityRadiusMeters;

  const RoammateOverlay({
    super.key,
    required this.mapController,
    this.hazardController,
    this.onHazardSelected,
    this.voiceService,
    this.proximityRadiusMeters = 500.0,
  });

  @override
  State<RoammateOverlay> createState() => _RoammateOverlayState();
}

class _RoammateOverlayState extends State<RoammateOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;

  String? _lastRegionId;
  bool _showDetails = false;
  bool _isHazardsExpanded = false;

  List<PlaceOfInterest> _allPlaces = [];
  final Set<String> _spokenHazardIds = {};

  final PlacesService _placesService = PlacesService();

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
    _onMapControllerChanged();
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
  }

  @override
  void dispose() {
    widget.mapController.removeListener(_onMapControllerChanged);
    widget.hazardController?.removeListener(_onHazardControllerChanged);
    _breathingController.dispose();
    _canScrollUp.dispose();
    _canScrollDown.dispose();
    super.dispose();
  }

  void _onMapControllerChanged() {
    final currentRegion = widget.mapController.currentRegion;
    if (currentRegion != null && currentRegion.id != _lastRegionId) {
      _lastRegionId = currentRegion.id;
      _fetchRegionData(currentRegion.id, currentRegion.name);
    }
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
        });
      }
    } catch (e) {
      // ignore
    }
  }

  void _toggleDetails() {
    setState(() {
      _showDetails = !_showDetails;
    });
  }

  void _handleHazardTapped(HazardReport report) {
    widget.mapController.animateToLocation(report.location);
    widget.onHazardSelected?.call(report);
    setState(() {
      _showDetails = false;
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

    // Clean, flat box appearance using AppColors
    final boxBackgroundColor = isDark ? AppColors.ink : AppColors.cream;
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
              child: Container(
                width: 280,
                constraints: const BoxConstraints(maxHeight: 440),
                decoration: BoxDecoration(
                  color: boxBackgroundColor,
                  borderRadius: BorderRadius.circular(
                    24,
                  ), // Heavily rounded corners
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                          color: titleColor.withOpacity(0.6),
                        ),
                      )
                    else
                      Flexible(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.axis == Axis.vertical) {
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
                                                    ? Colors.black.withOpacity(
                                                        0.4,
                                                      )
                                                    : Colors.black.withOpacity(
                                                        0.1,
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
                                                    ? Colors.black.withOpacity(
                                                        0.4,
                                                      )
                                                    : Colors.black.withOpacity(
                                                        0.1,
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

        // The breathing avatar
        GestureDetector(
          onTap: _toggleDetails,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ],
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
