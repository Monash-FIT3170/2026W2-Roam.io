import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../../map/data/geolocator_service.dart';
import '../providers/stats_analytics_provider.dart';
import 'stats_section_card.dart';

/// Home base setup card for distance-based location insights.
class HomeBaseCard extends StatefulWidget {
  const HomeBaseCard({
    super.key,
    required this.analytics,
    this.geoLocatorService,
  });

  final StatsAnalyticsProvider analytics;
  final GeoLocatorService? geoLocatorService;

  @override
  State<HomeBaseCard> createState() => _HomeBaseCardState();
}

class _HomeBaseCardState extends State<HomeBaseCard> {
  bool _isSaving = false;
  String? _errorMessage;

  GeoLocatorService get _geoLocatorService =>
      widget.geoLocatorService ?? GeoLocatorService();

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final position = await _geoLocatorService.getCurrentLocation();
      await widget.analytics.setHomeBase(
        lat: position.latitude,
        lng: position.longitude,
        label: 'Current location',
      );
    } catch (error) {
      setState(() {
        _errorMessage = 'Could not set home base. Check location permissions.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _clearHomeBase() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.analytics.clearHomeBase();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final homeBase = widget.analytics.homeBase;

    return StatsSectionCard(
      title: 'Home base',
      subtitle: 'Unlock distance-from-home insights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (homeBase != null) ...[
            Text(
              homeBase.label ?? 'Pinned location',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppSurfaces.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${homeBase.lat.toStringAsFixed(4)}, '
              '${homeBase.lng.toStringAsFixed(4)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppSurfaces.textMuted(context),
              ),
            ),
            const SizedBox(height: 12),
          ] else
            Text(
              'Set a home pin to see how far your explorations take you.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _useCurrentLocation,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(
                    homeBase == null ? 'Use current location' : 'Update',
                  ),
                ),
              ),
              if (homeBase != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isSaving ? null : _clearHomeBase,
                  child: const Text('Clear'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
