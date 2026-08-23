/*
 * Author: GitHub Copilot
 * Last Modified: 13/08/2026
 * Description:
 *   Floating stats card displayed during active journey tracking.
 *   Shows real-time distance, duration, and transport mode.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../domain/transport_mode.dart';

/// Floating card showing journey stats during tracking.
class JourneyTrackingCard extends StatelessWidget {
  const JourneyTrackingCard({
    super.key,
    required this.distanceMeters,
    required this.elapsedTime,
    required this.transportMode,
    required this.isPaused,
    required this.onPauseResume,
    required this.onEndJourney,
  });

  final double distanceMeters;
  final String elapsedTime;
  final TransportMode transportMode;
  final bool isPaused;
  final VoidCallback onPauseResume;
  final VoidCallback onEndJourney;

  String get _formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${distanceMeters.toInt()} m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppSurfaces.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppSurfaces.shadow(context),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with mode icon
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  transportMode.icon,
                  color: AppColors.sage,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPaused ? 'Journey Paused' : 'Journey in Progress',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppSurfaces.textPrimary(context),
                      ),
                    ),
                    Text(
                      transportMode.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppSurfaces.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Recording indicator reflects whether GPS tracking is active.
              if (isPaused)
                const Icon(
                  Icons.pause_circle_outline,
                  color: AppColors.clay,
                  size: 22,
                )
              else
                _RecordingIndicator(),
            ],
          ),

          const SizedBox(height: 16),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  icon: Icons.straighten,
                  value: _formattedDistance,
                  label: 'Distance',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppSurfaces.border(context),
              ),
              Expanded(
                child: _StatColumn(
                  icon: Icons.timer_outlined,
                  value: elapsedTime,
                  label: 'Time',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Live Journey controls.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPauseResume,
                  icon: Icon(
                    isPaused ? Icons.play_arrow : Icons.pause,
                    size: 20,
                  ),
                  label: Text(isPaused ? 'Resume' : 'Pause'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onEndJourney,
                  icon: const Icon(Icons.stop, size: 20),
                  label: const Text('End Journey'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.clay,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.sage),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppSurfaces.textPrimary(context),
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppSurfaces.textMuted(context),
          ),
        ),
      ],
    );
  }
}

class _RecordingIndicator extends StatefulWidget {
  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.clay.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
