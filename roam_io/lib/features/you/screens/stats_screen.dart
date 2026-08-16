import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../theme/app_surfaces.dart';
import '../../profile/domain/profile_model.dart';
import '../providers/stats_analytics_provider.dart';
import '../stats/journeys_stats_view.dart';
import '../stats/locations_stats_view.dart';
import '../stats/tiles_stats_view.dart';
import '../stats/xp_stats_view.dart';
import '../widgets/stats_hero_row.dart';

/// Stats tab shell with hero strip and category sub-tabs.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.profile});

  final ProfileModel? profile;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _categoryController;

  @override
  void initState() {
    super.initState();
    _categoryController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<StatsAnalyticsProvider>();
    final bottomClearance = AppBottomNavBar.clearanceFromScreenBottom(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stats',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppSurfaces.textPrimary(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              StatsHeroStrip(profile: widget.profile, analytics: analytics),
              const SizedBox(height: 16),
              _StatsCategoryTabBar(controller: _categoryController),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _categoryController,
            children: [
              LocationsStatsView(analytics: analytics),
              TilesStatsView(analytics: analytics),
              JourneysStatsView(analytics: analytics),
              XpStatsView(analytics: analytics),
            ],
          ),
        ),
        SizedBox(height: bottomClearance),
      ],
    );
  }
}

class _StatsCategoryTabBar extends StatelessWidget {
  const _StatsCategoryTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: AppSurfaces.textMuted(context),
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        tabs: const [
          Tab(text: 'Locations'),
          Tab(text: 'Tiles'),
          Tab(text: 'Journeys'),
          Tab(text: 'XP'),
        ],
      ),
    );
  }
}
