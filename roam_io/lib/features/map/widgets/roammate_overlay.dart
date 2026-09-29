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
  bool _showBubble = false;
  Timer? _bubbleTimer;

  List<PlaceOfInterest> _placesToVisit = [];
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
    _bubbleTimer?.cancel();
    super.dispose();
  }

  void _onMapControllerChanged() {
    final currentRegion = widget.mapController.currentRegion;
    if (currentRegion != null && currentRegion.id != _lastRegionId) {
      _lastRegionId = currentRegion.id;
      _triggerNotification(currentRegion.id, currentRegion.name);
    }
  }

  Future<void> _triggerNotification(String regionId, String regionName) async {
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
          // Take up to 3 unvisited places
          _placesToVisit = places
              .where((p) => !widget.mapController.isPlaceVisited(p.id))
              .take(3)
              .toList();
          _showBubble = true;
        });

        _bubbleTimer?.cancel();
        _bubbleTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showBubble = false;
            });
          }
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The breathing avatar
        ScaleTransition(
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

        // The chat bubble notification
        if (_showBubble)
          Positioned(
            bottom: 64, // Above the avatar
            right: 0,
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
                  width: 240,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Tile Entered',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_placesToVisit.isNotEmpty) ...[
                        Text(
                          'Places to visit:',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ..._placesToVisit.map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '• ${p.name}',
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                        const SizedBox(height: 8),
                      ] else ...[
                        Text(
                          'No new places nearby.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _mockedSafetyIssue,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
