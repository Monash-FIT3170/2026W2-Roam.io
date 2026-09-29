import 'dart:async';
import 'package:flutter/material.dart';
import '../data/map_controller.dart';
import '../data/places_service.dart';
import '../data/place_of_interest.dart';

class RoammateOverlay extends StatefulWidget {
  final MapController mapController;

  const RoammateOverlay({
    super.key,
    required this.mapController,
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

  List<PlaceOfInterest> _allPlaces = [];
  String _mockedSafetyIssue = '';

  final PlacesService _placesService = PlacesService();

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
    _mockedSafetyIssue = safetyIssues[regionId.hashCode.abs() % safetyIssues.length];

    try {
      final places = await _placesService.getPlacesForRegion(regionId: regionId);
      if (mounted) {
        setState(() {
          // Filter out public transport (like bus stops) from the locations list
          _allPlaces = places.where((p) => p.category != PlaceCategory.publicTransport).toList();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // The detail box morphing up
        if (_showDetails)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
              child: Material(
                elevation: 8,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
                color: theme.colorScheme.surface,
                child: Container(
                  width: 280,
                  constraints: const BoxConstraints(maxHeight: 400),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Red Box for safety features
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.security, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Safety Alert',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _mockedSafetyIssue.isNotEmpty ? _mockedSafetyIssue : 'No active safety alerts.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.red.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Locations in this tile',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_allPlaces.isEmpty)
                        Text(
                          'No locations available.',
                          style: theme.textTheme.bodySmall,
                        )
                      else
                        Flexible(
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: ListView(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: _sortedPlaces.map((p) {
                                final isVisited = widget.mapController.isPlaceVisited(p.id);
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: Icon(
                                    isVisited ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isVisited ? Colors.green : Colors.grey,
                                    size: 20,
                                  ),
                                  title: Text(
                                    p.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      decoration: isVisited ? TextDecoration.lineThrough : null,
                                      color: isVisited ? Colors.grey : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                    ],
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
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
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
