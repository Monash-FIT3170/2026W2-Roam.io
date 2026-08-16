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

enum _StatsCategory { locations, tiles, journeys, xp }

extension on _StatsCategory {
  String get label => switch (this) {
    _StatsCategory.locations => 'Locations',
    _StatsCategory.tiles => 'Tiles',
    _StatsCategory.journeys => 'Journeys',
    _StatsCategory.xp => 'XP',
  };
}

/// Stats tab shell with hero strip and category dropdown.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.profile});

  final ProfileModel? profile;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _StatsCategory _category = _StatsCategory.locations;

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<StatsAnalyticsProvider>();
    final bottomClearance = AppBottomNavBar.clearanceFromScreenBottom(context);
    final sectionStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: AppSurfaces.textPrimary(context),
      fontWeight: FontWeight.w900,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stats', style: sectionStyle),
              const SizedBox(height: 12),
              StatsHeroStrip(profile: widget.profile, analytics: analytics),
              const SizedBox(height: 16),
              _StatsCategoryDropdown(
                category: _category,
                style: sectionStyle,
                onChanged: (value) => setState(() => _category = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: IndexedStack(
            index: _category.index,
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

class _StatsCategoryDropdown extends StatelessWidget {
  const _StatsCategoryDropdown({
    required this.category,
    required this.style,
    required this.onChanged,
  });

  final _StatsCategory category;
  final TextStyle? style;
  final ValueChanged<_StatsCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_StatsCategory>(
      initialValue: category,
      onSelected: onChanged,
      padding: EdgeInsets.zero,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) {
        return [
          for (final option in _StatsCategory.values)
            PopupMenuItem<_StatsCategory>(
              value: option,
              child: Text(
                option.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: option == category
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: option == category
                      ? Theme.of(context).colorScheme.primary
                      : AppSurfaces.textPrimary(context),
                ),
              ),
            ),
        ];
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(category.label, style: style),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 28,
            color: AppSurfaces.textPrimary(context),
          ),
        ],
      ),
    );
  }
}
