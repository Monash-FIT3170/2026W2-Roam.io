import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/map_controller.dart';
import '../data/places_service.dart';
import '../data/place_of_interest.dart';
import '../../../theme/app_colours.dart';

class RoammateOverlay extends StatefulWidget {
  final MapController mapController;

  const RoammateOverlay({super.key, required this.mapController});

  @override
  State<RoammateOverlay> createState() => _RoammateOverlayState();
}

class _RoammateOverlayState extends State<RoammateOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;

  String? _lastRegionId;
  bool _showDetails = false;

  List<PlaceOfInterest> _allPlaces = [];
  String _mockedSafetyIssue = '';
  LatLng? _mockedHazardLocation;

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
    _onMapControllerChanged();
  }

  @override
  void dispose() {
    widget.mapController.removeListener(_onMapControllerChanged);
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
  }

  Future<void> _fetchRegionData(String regionId, String regionName) async {
    // Generate mocked safety issue based on region name length to make it deterministic but varied
    final safetyIssues = [
      'Slippery paths due to recent rain.',
      'Uneven pavement reported ahead.',
      'Construction work nearby, watch for detours.',
      'Dim lighting in some alleys.',
      'High traffic area, be careful crossing.',
    ];
    _mockedSafetyIssue =
        safetyIssues[regionId.hashCode.abs() % safetyIssues.length];

    // Mock a hazard location near the center of the current tile
    final center = widget.mapController.center;
    _mockedHazardLocation = LatLng(
      center.latitude + 0.001,
      center.longitude + 0.001,
    );

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

  void _onHazardTapped() {
    if (_mockedHazardLocation != null) {
      widget.mapController.animateToLocation(_mockedHazardLocation!);
      // Optionally hide details to let them see the map
      setState(() {
        _showDetails = false;
      });
    }
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
                    // Tappable Inline Hazard Banner
                    if (_mockedSafetyIssue.isNotEmpty)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _onHazardTapped,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hazard Nearby',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: Colors.red.shade900,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _mockedSafetyIssue,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: Colors.red.shade800,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

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
}
