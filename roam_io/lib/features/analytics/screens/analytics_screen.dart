/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 12/05/2026
 * Description:
 *   Provides a vertically scrollable analytics UI for exploration progress,
 *   statistics, heatmap activity, and recent visited locations (bottom inset
 *   for the extended-body tab bar).
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../map/data/visit.dart';
import '../../map/data/visit_service.dart';
import '../../map/data/visited_region_service.dart';
import '../widgets/recent_visited_locations_card.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';

/// Displays exploration analytics, progress summaries, and visit history.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    super.key,
    this.visitService,
    this.visitedRegionService,
  });

  /// Injected for tests; production uses the default [VisitService].
  final VisitService? visitService;

  /// Injected for tests; production uses the default [VisitedRegionService].
  final VisitedRegionService? visitedRegionService;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  VisitService? _visitService;
  VisitedRegionService? _visitedRegionService;
  String? _tilesVisitedUserId;
  Future<int>? _tilesVisitedCountFuture;

  VisitService get _effectiveVisitService {
    return _visitService ??= widget.visitService ?? VisitService();
  }

  VisitedRegionService get _effectiveVisitedRegionService {
    return _visitedRegionService ??=
        widget.visitedRegionService ?? VisitedRegionService();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppSurfaces.pageBackground(context),
      child: SafeArea(
        child: SingleChildScrollView(
          // Clears the extended-body bottom nav (see JourneysScreen).
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Your Analytics',
                subtitle: 'Stats & progress',
              ),

              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Activity Map',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildHeatmap(context),
              ),

              const SizedBox(height: 22),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    final xp = auth.currentProfile?.xp;
                    final uid = auth.currentUser?.uid;
                    final tilesVisitedFuture = _tilesVisitedCountFutureFor(uid);

                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            title: 'XP Count',
                            value: xp == null ? '...' : _formatStatValue(xp),
                            icon: Icons.bolt,
                            color: AppColors.sage,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FutureBuilder<int>(
                            future: tilesVisitedFuture,
                            builder: (context, snapshot) {
                              return _buildStatCard(
                                context,
                                title: 'Tiles Visited',
                                value: snapshot.hasData
                                    ? _formatStatValue(snapshot.data!)
                                    : '...',
                                icon: Icons.map_outlined,
                                color: AppColors.clay,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            title: 'Total Visits',
                            value: '156',
                            icon: Icons.repeat,
                            color: AppColors.sage,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 22),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Recent Visited Locations',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    final uid = auth.currentUser?.uid;
                    final visitsStream = uid == null
                        ? Stream<List<Visit>>.value(const <Visit>[])
                        : _effectiveVisitService.watchRecentVisits(uid);

                    return RecentVisitedLocationsCard(
                      visitsStream: visitsStream,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeatmap(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: List.generate(91, (index) {
        final intensity = index % 7;

        final Color color = intensity == 0
            ? AppSurfaces.softCard(context)
            : Theme.of(context).colorScheme.primary.withValues(
                alpha: isDark
                    ? 0.16 + (intensity * 0.08)
                    : 0.12 + (intensity * 0.09),
              );

        return Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppSurfaces.shadow(context),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppSurfaces.textPrimary(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppSurfaces.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatValue(int value) {
    final sign = value < 0 ? '-' : '';
    final digits = value.abs().toString();
    final buffer = StringBuffer(sign);

    for (var index = 0; index < digits.length; index += 1) {
      final digitsRemaining = digits.length - index;
      buffer.write(digits[index]);
      if (digitsRemaining > 1 && digitsRemaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }

  Future<int> _tilesVisitedCountFutureFor(String? uid) {
    if (uid == null) {
      _tilesVisitedUserId = null;
      _tilesVisitedCountFuture = Future<int>.value(0);
      return _tilesVisitedCountFuture!;
    }

    if (_tilesVisitedUserId != uid || _tilesVisitedCountFuture == null) {
      _tilesVisitedUserId = uid;
      _tilesVisitedCountFuture = _effectiveVisitedRegionService
          .loadVisitedRegionIds()
          .then((regionIds) => regionIds.length);
    }

    return _tilesVisitedCountFuture!;
  }
}
