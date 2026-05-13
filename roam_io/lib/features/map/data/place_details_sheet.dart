import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../widgets/media_viewer.dart';
import 'map_controller.dart';
import 'place_of_interest.dart';
import 'visit.dart';
import 'visit_form_sheet.dart';
import 'visit_service.dart';

/// Bottom sheet displayed when a place marker is tapped.
/// Shows place details and allows marking the place as visited.
/// For visited places, shows custom name, description, and media.
class PlaceDetailsSheet extends StatefulWidget {
  const PlaceDetailsSheet({
    super.key,
    required this.place,
    required this.mapController,
  });

  final PlaceOfInterest place;
  final MapController mapController;

  /// Shows the place details sheet as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required PlaceOfInterest place,
    required MapController mapController,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          PlaceDetailsSheet(place: place, mapController: mapController),
    );
  }

  @override
  State<PlaceDetailsSheet> createState() => _PlaceDetailsSheetState();
}

class _PlaceDetailsSheetState extends State<PlaceDetailsSheet> {
  double? _distance;
  String? _errorMessage;
  Visit? _visitData;
  bool _isLoadingVisit = false;

  @override
  void initState() {
    super.initState();
    _loadDistance();
    if (_isVisited) {
      _loadVisitData();
    }
  }

  Future<void> _loadDistance() async {
    final distance = await widget.mapController.getDistanceToPlace(
      widget.place,
    );
    if (mounted) {
      setState(() {
        _distance = distance;
      });
    }
  }

  Future<void> _loadVisitData() async {
    final userId = widget.mapController.userId;
    if (userId == null) return;

    setState(() {
      _isLoadingVisit = true;
    });

    try {
      final visitService = VisitService();
      final visit = await visitService.getVisit(
        userId: userId,
        placeId: widget.place.id,
      );
      if (mounted) {
        setState(() {
          _visitData = visit;
          _isLoadingVisit = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVisit = false;
        });
      }
    }
  }

  bool get _isVisited => widget.mapController.isPlaceVisited(widget.place.id);

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m away';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km away';
    }
  }

  Future<void> _handleMarkVisited() async {
    // Check proximity first
    if (_distance != null &&
        _distance! > MapController.visitProximityThreshold) {
      setState(() {
        _errorMessage =
            'You need to be within ${MapController.visitProximityThreshold.round()}m to visit this place';
      });
      return;
    }

    final userId = widget.mapController.userId;
    if (userId == null) {
      setState(() {
        _errorMessage = 'Please log in to mark places as visited';
      });
      return;
    }

    // Navigate to visit form
    if (!mounted) return;
    Navigator.of(context).pop(); // Close current sheet

    final result = await VisitFormSheet.show(
      context: context,
      place: widget.place,
      userId: userId,
    );

    if (result == VisitFormResult.success) {
      // Refresh the map controller's visited places
      await widget.mapController.refreshVisitedPlaces();
    }
  }

  Future<void> _handleEditVisit() async {
    final userId = widget.mapController.userId;
    if (userId == null || _visitData == null) return;

    Navigator.of(context).pop(); // Close current sheet

    final result = await VisitFormSheet.show(
      context: context,
      place: widget.place,
      userId: userId,
      existingVisit: _visitData,
    );

    if (result == VisitFormResult.success) {
      // Refresh the map controller's visited places
      await widget.mapController.refreshVisitedPlaces();
    }
  }

  void _openMediaViewer(int index) {
    if (_visitData == null || _visitData!.mediaUrls.isEmpty) return;
    MediaViewer.show(
      context: context,
      mediaUrls: _visitData!.mediaUrls,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNearby =
        _distance != null &&
        _distance! <= MapController.visitProximityThreshold;

    // Use custom name if available, otherwise place name
    final displayName = _visitData?.displayName ?? widget.place.name;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Place name and category
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category color indicator
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 6, right: 12),
                    decoration: BoxDecoration(
                      color: widget.place.category.markerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          widget.place.category.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Visited badge
                  if (_isVisited)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sage.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.sage,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Visited',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.sage,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Distance row
              Row(
                children: [
                  // Distance
                  Icon(
                    Icons.location_on,
                    size: 18,
                    color: isNearby ? AppColors.sage : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  if (_distance != null)
                    Text(
                      _formatDistance(_distance!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isNearby ? AppColors.sage : Colors.grey[600],
                        fontWeight: isNearby
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    )
                  else
                    const SizedBox(
                      width: 60,
                      child: LinearProgressIndicator(
                        backgroundColor: Color(0xFFE0E0E0),
                        color: AppColors.sage,
                      ),
                    ),
                ],
              ),

              // Visit details (for visited places)
              if (_isVisited) ...[
                if (_isLoadingVisit) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ] else if (_visitData != null) ...[
                  // Description
                  if (_visitData!.description != null &&
                      _visitData!.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Description', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      _visitData!.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],

                  // Media gallery
                  if (_visitData!.mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Media', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _visitData!.mediaUrls.length,
                        itemBuilder: (context, index) {
                          final url = _visitData!.mediaUrls[index];
                          final isVideo =
                              url.toLowerCase().contains('.mp4') ||
                              url.toLowerCase().contains('.mov');
                          return GestureDetector(
                            onTap: () => _openMediaViewer(index),
                            child: Container(
                              width: 80,
                              height: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[300],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (isVideo)
                                      const Center(
                                        child: Icon(
                                          Icons.videocam,
                                          size: 32,
                                          color: Colors.grey,
                                        ),
                                      )
                                    else
                                      Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    if (isVideo)
                                      Positioned(
                                        right: 4,
                                        bottom: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ],

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.clay.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.clay,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.clay,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action buttons
              if (_isVisited)
                // Edit button for visited places
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleEditVisit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Visit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                // Mark as Visited button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleMarkVisited,
                    icon: const Icon(Icons.check),
                    label: const Text('Mark as Visited'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
