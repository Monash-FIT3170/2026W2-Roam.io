import 'package:flutter/material.dart';

import '../../map/widgets/media_viewer.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../domain/journey_location.dart';
import 'custom_location_form_sheet.dart';

class CustomLocationDetailsSheet extends StatefulWidget {
  const CustomLocationDetailsSheet({
    super.key,
    required this.location,
    required this.distanceMeters,
    required this.userId,
    required this.onSave,
  });

  final JourneyLocation location;
  final double distanceMeters;
  final String userId;
  final Future<void> Function(JourneyLocation location) onSave;

  static Future<void> show({
    required BuildContext context,
    required JourneyLocation location,
    required double distanceMeters,
    required String userId,
    required Future<void> Function(JourneyLocation location) onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomLocationDetailsSheet(
        location: location,
        distanceMeters: distanceMeters,
        userId: userId,
        onSave: onSave,
      ),
    );
  }

  @override
  State<CustomLocationDetailsSheet> createState() =>
      _CustomLocationDetailsSheetState();
}

class _CustomLocationDetailsSheetState
    extends State<CustomLocationDetailsSheet> {
  late JourneyLocation _location;

  @override
  void initState() {
    super.initState();
    _location = widget.location;
  }

  String get _distance {
    if (widget.distanceMeters < 1000) {
      return '${widget.distanceMeters.round()}m away';
    }
    return '${(widget.distanceMeters / 1000).toStringAsFixed(1)}km away';
  }

  Future<void> _edit() async {
    final updated = await CustomLocationFormSheet.show(
      context: context,
      location: _location,
      userId: widget.userId,
    );
    if (updated == null) return;
    await widget.onSave(updated);
    if (mounted) setState(() => _location = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 7, right: 12),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_location.name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          'Custom',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 18,
                    color: AppColors.sage,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _distance,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.sage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (_location.description?.isNotEmpty == true) ...[
                const SizedBox(height: 18),
                Text('Description', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(_location.description!),
              ],
              if (_location.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Media', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _location.mediaUrls.length,
                    itemBuilder: (_, index) {
                      final url = _location.mediaUrls[index];
                      return GestureDetector(
                        onTap: () => MediaViewer.show(
                          context: context,
                          mediaUrls: _location.mediaUrls,
                          initialIndex: index,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 8),
                            color: Colors.grey[300],
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.videocam),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit location'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
