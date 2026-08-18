import 'dart:math' as math;

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

/// Stats tab shell: scrollable title + XP hero, sticky full-width pill tabs.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.profile});

  final ProfileModel? profile;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const _categories = ['Locations', 'Tiles', 'Journeys', 'XP'];
  static const double _pillsHeight = 56;

  int _categoryIndex = 0;
  final _scrollController = ScrollController();
  final _scrollOffset = ValueNotifier<double>(0);
  final _heroKey = GlobalKey();
  double _heroHeight = 180;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHero());
  }

  @override
  void didUpdateWidget(covariant StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHero());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  void _onScroll() {
    _scrollOffset.value = _scrollController.offset;
  }

  void _measureHero() {
    final box = _heroKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final height = box.size.height;
    if ((height - _heroHeight).abs() > 1) {
      setState(() => _heroHeight = height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<StatsAnalyticsProvider>();
    final bottomClearance = AppBottomNavBar.clearanceFromScreenBottom(context);
    final sectionStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: AppSurfaces.textPrimary(context),
      fontWeight: FontWeight.w900,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Use metrics.pixels so overscroll (negative) is tracked during bounce.
            if (notification.metrics.axis == Axis.vertical) {
              _scrollOffset.value = notification.metrics.pixels;
            }
            return false;
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KeyedSubtree(
                      key: _heroKey,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Stats', style: sectionStyle),
                            const SizedBox(height: 12),
                            StatsHeroStrip(
                              profile: widget.profile,
                              analytics: analytics,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    // Reserve space where the overlay pills sit at rest.
                    const SizedBox(height: _pillsHeight),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, bottomClearance + 24),
                sliver: SliverToBoxAdapter(
                  child: KeyedSubtree(
                    key: ValueKey<int>(_categoryIndex),
                    child: switch (_categoryIndex) {
                      0 => LocationsStatsView(
                        analytics: analytics,
                        embedded: true,
                      ),
                      1 => TilesStatsView(analytics: analytics, embedded: true),
                      2 => JourneysStatsView(
                        analytics: analytics,
                        embedded: true,
                      ),
                      _ => XpStatsView(analytics: analytics, embedded: true),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _scrollOffset,
          builder: (context, offset, _) {
            // Follow overscroll past the top (negative offset) so pills stay
            // glued to the hero; only pin when scrolled past the hero.
            final top = math.max(0.0, _heroHeight - offset);
            final compact = offset >= _heroHeight - 0.5;
            return Positioned(
              top: top,
              left: 0,
              right: 0,
              height: _pillsHeight,
              child: _StatsPillBar(
                labels: _categories,
                selectedIndex: _categoryIndex,
                compact: compact,
                onSelected: (index) {
                  if (index == _categoryIndex) return;
                  setState(() => _categoryIndex = index);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StatsPillBar extends StatelessWidget {
  const _StatsPillBar({
    required this.labels,
    required this.selectedIndex,
    required this.compact,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final bool compact;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final pageBg = AppSurfaces.pageBackground(context);
    final theme = Theme.of(context);
    // Compact only tightens chrome (padding / elevation), not type size.
    final verticalInset = compact ? 6.0 : 8.0;

    return Material(
      color: pageBg.withValues(alpha: compact ? 0.94 : 1.0),
      elevation: compact ? 3 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, verticalInset, 20, verticalInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppSurfaces.softCard(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppSurfaces.border(context)),
            boxShadow: compact
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Material(
                      color: i == selectedIndex
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        onTap: () => onSelected(i),
                        borderRadius: BorderRadius.circular(999),
                        child: Center(
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: i == selectedIndex
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              fontSize: 14,
                              height: 1.0,
                              color: i == selectedIndex
                                  ? theme.colorScheme.onPrimary
                                  : AppSurfaces.textMuted(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
