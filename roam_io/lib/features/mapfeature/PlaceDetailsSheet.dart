import 'package:flutter/material.dart';

import '../../theme/app_colours.dart';
import 'MapController.dart';
import 'PlaceOfInterest.dart';

/// Bottom sheet displayed when a place marker is tapped.
/// Shows place details and allows marking the place as visited.
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
      builder: (context) => PlaceDetailsSheet(
        place: place,
        mapController: mapController,
      ),
    );
  }

  @override
  State<PlaceDetailsSheet> createState() => _PlaceDetailsSheetState();
}

class _PlaceDetailsSheetState extends State<PlaceDetailsSheet> {
  bool _isLoading = false;
  double? _distance;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDistance();
  }

  Future<void> _loadDistance() async {
    final distance = await widget.mapController.getDistanceToPlace(widget.place);
    if (mounted) {
      setState(() {
        _distance = distance;
      });
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.mapController.markPlaceAsVisited(widget.place);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    switch (result) {
      case VisitResult.success:
        // Show success and close sheet
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Visited ${widget.place.name}!'),
            backgroundColor: AppColors.sage,
          ),
        );
        break;
      case VisitResult.tooFar:
        setState(() {
          _errorMessage = 'You need to be within ${MapController.visitProximityThreshold.round()}m to visit this place';
        });
        break;
      case VisitResult.notLoggedIn:
        setState(() {
          _errorMessage = 'Please log in to mark places as visited';
        });
        break;
      case VisitResult.alreadyVisited:
        // Should not happen, button is hidden
        break;
      case VisitResult.error:
        setState(() {
          _errorMessage = 'Something went wrong. Please try again.';
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNearby = _distance != null && _distance! <= MapController.visitProximityThreshold;

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
                      color: _isVisited
                          ? const Color(0xFF6B7280)
                          : widget.place.category.markerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.place.name,
                          style: theme.textTheme.titleLarge,
                        ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.sage.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
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

              // Rating and distance row
              Row(
                children: [
                  // Rating
                  if (widget.place.rating != null) ...[
                    Icon(
                      Icons.star,
                      size: 18,
                      color: Colors.amber[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.place.rating!.toStringAsFixed(1),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.place.userRatingsTotal != null) ...[
                      Text(
                        ' (${widget.place.userRatingsTotal})',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(width: 16),
                  ],

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
                        fontWeight: isNearby ? FontWeight.w600 : FontWeight.normal,
                      ),
                    )
                  else
                    SizedBox(
                      width: 60,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.grey[300],
                        color: AppColors.sage,
                      ),
                    ),
                ],
              ),

              // Address if available
              if (widget.place.address != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.place.address!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.clay.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
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

              // Mark as Visited button (only show if not already visited)
              if (!_isVisited)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleMarkVisited,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isLoading ? 'Saving...' : 'Mark as Visited'),
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
