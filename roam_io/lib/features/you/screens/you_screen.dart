/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Provides the You destination with Profile and Activities tabs. Profile
 *   analytics are owned by YouAnalyticsProvider (latest lists + live watches)
 *   so XP graph, visits, and tiles survive Activities ↔ Profile remounts and
 *   Activity Detail navigation. Profile uses a densified header (64px avatar +
 *   identity/XP) above a full-width stats row. Activities shows a personal stub
 *   via shared activity_feed cards (temporary; not persisted). Personal detail
 *   has no engagement controls.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/profile_service.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/data/stub_activity_feed_data.dart';
import '../../activity_feed/screens/activity_detail_screen.dart';
import '../../activity_feed/widgets/activity_feed_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../map/data/visit.dart';
import '../../map/data/visit_service.dart';
import '../../map/data/visited_region_service.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/domain/visited_polygon_record.dart';
import '../../profile/domain/xp_event.dart';
import '../providers/you_analytics_provider.dart';
import '../widgets/recent_visited_locations_card.dart';
import '../widgets/xp_progress_section.dart';

/// Displays personal profile analytics and the user's own activity area.
class YouScreen extends StatefulWidget {
  const YouScreen({
    super.key,
    this.visitService,
    this.visitedRegionService,
    this.profileService,
    this.xpEventsStream,
  });

  /// Injected for tests; production uses the default [VisitService].
  final VisitService? visitService;

  /// Injected for tests; production uses the default [VisitedRegionService].
  final VisitedRegionService? visitedRegionService;

  /// Injected for tests; production uses the default [ProfileService].
  final ProfileService? profileService;

  /// Injected XP event stream for tests; production watches Firestore.
  final Stream<List<XpEvent>>? xpEventsStream;

  @override
  State<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends State<YouScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final YouAnalyticsProvider _analytics;
  _GraphMetric _selectedGraphMetric = _GraphMetric.locationsVisited;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // When tests inject VisitService without ProfileService, skip Firebase XP.
    final profileService =
        widget.profileService ??
        (widget.visitService != null ? null : ProfileService());
    _analytics = YouAnalyticsProvider(
      visitService: widget.visitService,
      visitedRegionService: widget.visitedRegionService,
      profileService: profileService,
      xpEventsStream: widget.xpEventsStream,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _analytics.dispose();
    super.dispose();
  }

  void _selectGraphMetric(_GraphMetric metric) {
    if (_selectedGraphMetric == metric) return;
    setState(() {
      _selectedGraphMetric = metric;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<YouAnalyticsProvider>.value(
      value: _analytics,
      child: Container(
        color: AppSurfaces.pageBackground(context),
        child: SafeArea(
          bottom: false,
          child: Consumer2<AuthProvider, YouAnalyticsProvider>(
            builder: (context, auth, analytics, _) {
              final profile = auth.currentProfile;
              final uid = auth.currentUser?.uid;
              if (analytics.boundUid != uid) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _analytics.bindUid(uid);
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _YouTabBar(controller: _tabController),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _ProfileTab(
                          profile: profile,
                          selectedGraphMetric: _selectedGraphMetric,
                          onGraphMetricSelected: _selectGraphMetric,
                        ),
                        _ActivitiesTab(profile: profile),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _YouTabBar extends StatelessWidget {
  const _YouTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: AppSurfaces.textMuted(context),
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          dividerColor: AppSurfaces.border(context),
          labelStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
          unselectedLabelStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Activities'),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.profile,
    required this.selectedGraphMetric,
    required this.onGraphMetricSelected,
  });

  final ProfileModel? profile;
  final _GraphMetric selectedGraphMetric;
  final ValueChanged<_GraphMetric> onGraphMetricSelected;

  @override
  Widget build(BuildContext context) {
    final bottomClearance = AppBottomNavBar.clearanceFromScreenBottom(context);
    final analytics = context.watch<YouAnalyticsProvider>();
    final visits = analytics.visits;
    final tileRecords = analytics.tileRecords;
    final xpEvents = analytics.xpEvents;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomClearance + 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ProfileHeader(
              profile: profile,
              tileCount: tileRecords.length,
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _MetricLineGraphSection(
              visits: visits,
              tileRecords: tileRecords,
              xpEvents: xpEvents,
              selectedMetric: selectedGraphMetric,
              onMetricSelected: onGraphMetricSelected,
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle(title: 'Most Visited Location'),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _MostVisitedLocationBubble(visits: visits),
          ),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'Recent Visited Locations'),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: RecentVisitedLocationsCard(
              visits: analytics.recentVisits,
              isLoading: !analytics.recentVisitsReady,
              error: analytics.recentVisitsError,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitiesTab extends StatelessWidget {
  const _ActivitiesTab({required this.profile});

  final ProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    final bottomClearance =
        AppBottomNavBar.clearanceFromScreenBottom(context) + 12;
    final activity = StubActivityFeedData.personalJourney.copyWith(
      displayName: profile?.displayName ?? 'Traveller',
      username: profile?.username,
      photoUrl: profile?.photoUrl,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomClearance),
      child: ActivityFeedCard.fromItem(
        activity,
        onOverflowTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ActivityDetailScreen(activity: activity),
            ),
          );
        },
        onKudosTap: () {},
        onCommentTap: () {},
        onShareTap: () {},
      ),
    );
  }
}

/// Densified identity header: 64px avatar with name/username/XP, then a
/// full-width five-stat row beneath.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.tileCount});

  final ProfileModel? profile;
  final int tileCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = profile?.displayName ?? '-';
    final username = profile?.username ?? '-';
    final photoUrl = profile?.photoUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppSurfaces.softCard(context),
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary, width: 2),
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person_rounded,
                          color: colorScheme.primary,
                        ),
                      )
                    : Icon(Icons.person_rounded, color: colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppSurfaces.textPrimary(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppSurfaces.textMuted(context),
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  if (profile != null) ...[
                    const SizedBox(height: 4),
                    XpProgressSection(profile: profile!, compact: true),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ProfileStatsRow(tileCount: tileCount),
      ],
    );
  }
}

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({required this.tileCount});

  final int tileCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ProfileStat(label: 'Following', value: '0'),
        const _ProfileStat(label: 'Followers', value: '0'),
        _ProfileStat(label: 'Tiles', value: _formatNumber(tileCount)),
        const _ProfileStat(label: 'Journeys', value: '0'),
        const _ProfileStat(label: 'Sidequests', value: '0'),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w600,
                fontSize: 9,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppSurfaces.textPrimary(context),
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricLineGraphSection extends StatefulWidget {
  const _MetricLineGraphSection({
    required this.visits,
    required this.tileRecords,
    required this.xpEvents,
    required this.selectedMetric,
    required this.onMetricSelected,
  });

  final List<Visit> visits;
  final List<VisitedPolygonRecord> tileRecords;
  final List<XpEvent> xpEvents;
  final _GraphMetric selectedMetric;
  final ValueChanged<_GraphMetric> onMetricSelected;

  @override
  State<_MetricLineGraphSection> createState() =>
      _MetricLineGraphSectionState();
}

class _MetricLineGraphSectionState extends State<_MetricLineGraphSection> {
  int? _selectedPointIndex;

  @override
  void didUpdateWidget(covariant _MetricLineGraphSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMetric != widget.selectedMetric) {
      _selectedPointIndex = null;
    }
  }

  void _selectPoint(int index) {
    setState(() {
      _selectedPointIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = _bucketsForMetric(widget.selectedMetric);
    final hasData = buckets.any((bucket) => bucket.value > 0);
    final selectedIndex = _selectedPointIndex;
    final selectedBucket =
        selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < buckets.length
        ? buckets[selectedIndex]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppSurfaces.card(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppSurfaces.border(context)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _GraphMetric.values.map((metric) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _MetricPill(
                    label: metric.label,
                    selected: widget.selectedMetric == metric,
                    onTap: () => widget.onMetricSelected(metric),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 28,
          child: selectedBucket == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.center,
                  child: Text(
                    selectedBucket.detailLabel(widget.selectedMetric),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppSurfaces.textPrimary(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ),
        SizedBox(
          height: 210,
          width: double.infinity,
          child: hasData
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final chart = _ActivityLineChartPainter(
                      buckets: buckets,
                      selectedIndex: selectedIndex,
                      lineColor: theme.colorScheme.primary,
                      fillColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      gridColor: AppSurfaces.border(context),
                      labelColor: AppSurfaces.textMuted(context),
                      axisLabelColor: AppSurfaces.textMuted(context),
                    );
                    final points = chart.pointOffsets(
                      Size(constraints.maxWidth, constraints.maxHeight),
                    );

                    return Stack(
                      children: [
                        CustomPaint(size: Size.infinite, painter: chart),
                        for (var index = 0; index < points.length; index += 1)
                          Positioned(
                            left: points[index].dx - 22,
                            top: points[index].dy - 22,
                            child: GestureDetector(
                              key: ValueKey<String>('graph-point-$index'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _selectPoint(index),
                              child: const SizedBox(width: 44, height: 44),
                            ),
                          ),
                      ],
                    );
                  },
                )
              : Center(
                  child: Text(
                    widget.selectedMetric.emptyMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppSurfaces.textMuted(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  List<_MetricBucket> _bucketsForMetric(_GraphMetric metric) {
    switch (metric) {
      case _GraphMetric.locationsVisited:
        return _weeklyBucketsFromDates(
          widget.visits.map((visit) => visit.visitedAt).toList(),
        );
      case _GraphMetric.tilesUnlocked:
        return _weeklyBucketsFromDates(
          widget.tileRecords.map((record) => record.visitedAt).toList(),
        );
      case _GraphMetric.journeysCompleted:
      case _GraphMetric.sidequestsCompleted:
        return _emptyRecentBuckets();
      case _GraphMetric.xpGained:
        if (widget.xpEvents.isEmpty) {
          return _emptyRecentBuckets();
        }
        return _weeklyBucketsFromXpEvents(widget.xpEvents);
    }
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;

    return Material(
      color: selected ? selectedColor : AppSurfaces.softCard(context),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? selectedColor : AppSurfaces.border(context),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _MostVisitedLocationBubble extends StatelessWidget {
  const _MostVisitedLocationBubble({required this.visits});

  final List<Visit> visits;

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) {
      return _LocationBubble(
        title: 'No locations yet',
        subtitle:
            'Visit places on the map to see your most visited location here.',
        bubbleIcon: Icons.location_off,
        bubbleColor: AppColors.sage.withValues(alpha: 0.24),
      );
    }

    final topLocation = _selectMostVisitedLocation(visits);
    return _LocationBubble(
      title: 'Your top location',
      subtitle: topLocation.displayName,
      bubbleIcon: Icons.location_on,
      bubbleColor: AppColors.sage,
    );
  }

  Visit _selectMostVisitedLocation(List<Visit> visits) {
    final counts = <int, int>{};

    for (final visit in visits) {
      counts.update(visit.placeId, (count) => count + 1, ifAbsent: () => 1);
    }

    Visit? best;
    var bestCount = 0;

    for (final visit in visits) {
      final count = counts[visit.placeId] ?? 0;
      if (best == null ||
          count > bestCount ||
          (count == bestCount && visit.visitedAt.isAfter(best.visitedAt))) {
        best = visit;
        bestCount = count;
      }
    }

    return best!;
  }
}

class _LocationBubble extends StatelessWidget {
  const _LocationBubble({
    required this.title,
    required this.subtitle,
    required this.bubbleIcon,
    this.bubbleColor = AppColors.sage,
  });

  final String title;
  final String subtitle;
  final IconData bubbleIcon;
  final Color bubbleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bubbleColor.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bubbleColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(bubbleIcon, color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppSurfaces.textPrimary(context),
        ),
      ),
    );
  }
}

class _ActivityLineChartPainter extends CustomPainter {
  const _ActivityLineChartPainter({
    required this.buckets,
    required this.selectedIndex,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelColor,
    required this.axisLabelColor,
  });

  final List<_MetricBucket> buckets;
  final int? selectedIndex;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color labelColor;
  final Color axisLabelColor;

  static const double _leftPad = 34;
  static const double _rightPad = 8;
  static const double _topPad = 12;
  static const double _bottomPad = 30;

  List<Offset> pointOffsets(Size size) {
    final chartLeft = _leftPad;
    final chartRight = size.width - _rightPad;
    final chartTop = _topPad;
    final chartBottom = size.height - _bottomPad;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;
    final maxValue = _maxValue();
    final points = <Offset>[];

    for (var index = 0; index < buckets.length; index += 1) {
      final bucket = buckets[index];
      final x = buckets.length == 1
          ? chartLeft + chartWidth / 2
          : chartLeft + chartWidth * index / (buckets.length - 1);
      final y = chartBottom - (chartHeight * bucket.value / maxValue);
      points.add(Offset(x, y));
    }
    return points;
  }

  int _maxValue() {
    return buckets
        .map((bucket) => bucket.value)
        .fold<int>(1, (max, value) => value > max ? value : max);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartLeft = _leftPad;
    final chartRight = size.width - _rightPad;
    final chartTop = _topPad;
    final chartBottom = size.height - _bottomPad;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;
    final maxValue = _maxValue();
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final guidePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.45)
      ..strokeWidth = 1.5;
    final labelStyle = TextStyle(
      color: labelColor,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );
    final yLabelStyle = TextStyle(
      color: axisLabelColor,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );

    for (var i = 0; i < 3; i += 1) {
      final fraction = i / 2;
      final y = chartTop + chartHeight * fraction;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);

      final tickValue = (maxValue * (1 - fraction)).round();
      final yPainter = TextPainter(
        text: TextSpan(text: '$tickValue', style: yLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _leftPad - 4);
      yPainter.paint(
        canvas,
        Offset(chartLeft - yPainter.width - 6, y - yPainter.height / 2),
      );
    }

    final points = pointOffsets(size);

    if (points.isNotEmpty) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        linePath.lineTo(point.dx, point.dy);
      }

      final fillPath = Path.from(linePath)
        ..lineTo(points.last.dx, chartBottom)
        ..lineTo(points.first.dx, chartBottom)
        ..close();

      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(linePath, linePaint);

      for (var index = 0; index < points.length; index += 1) {
        final point = points[index];
        final isSelected = selectedIndex == index;
        if (isSelected) {
          canvas.drawLine(
            Offset(point.dx, chartTop),
            Offset(point.dx, chartBottom),
            guidePaint,
          );
        }
        final radius = isSelected ? 6.5 : 4.5;
        canvas.drawCircle(point, radius, pointPaint);
        canvas.drawCircle(point, radius, pointBorderPaint);
      }
    }

    final slotWidth = buckets.length <= 1
        ? chartWidth
        : chartWidth / (buckets.length - 1);

    for (var index = 0; index < buckets.length; index += 1) {
      final bucket = buckets[index];
      final labelPainter = TextPainter(
        text: TextSpan(text: bucket.label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slotWidth + 16);
      final x = buckets.length == 1
          ? chartLeft + chartWidth / 2
          : chartLeft + chartWidth * index / (buckets.length - 1);
      labelPainter.paint(
        canvas,
        Offset(
          (x - labelPainter.width / 2).clamp(
            chartLeft,
            chartRight - labelPainter.width,
          ),
          chartBottom + 10,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityLineChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.axisLabelColor != axisLabelColor;
  }
}

enum _GraphMetric {
  locationsVisited,
  tilesUnlocked,
  journeysCompleted,
  sidequestsCompleted,
  xpGained,
}

extension _GraphMetricLabel on _GraphMetric {
  String get label {
    switch (this) {
      case _GraphMetric.locationsVisited:
        return 'Locations Visited';
      case _GraphMetric.tilesUnlocked:
        return 'Tiles Unlocked';
      case _GraphMetric.journeysCompleted:
        return 'Journeys Completed';
      case _GraphMetric.sidequestsCompleted:
        return 'Sidequests Completed';
      case _GraphMetric.xpGained:
        return 'XP Gained';
    }
  }

  String get emptyMessage {
    switch (this) {
      case _GraphMetric.locationsVisited:
        return 'No locations to chart yet';
      case _GraphMetric.tilesUnlocked:
        return 'No unlocked tiles to chart yet';
      case _GraphMetric.journeysCompleted:
        return 'Journey completion history is not available yet';
      case _GraphMetric.sidequestsCompleted:
        return 'Sidequest completion history is not available yet';
      case _GraphMetric.xpGained:
        return 'No XP gained yet this period';
    }
  }
}

class _MetricBucket {
  const _MetricBucket({
    required this.label,
    required this.value,
    required this.weekStart,
  });

  final String label;
  final int value;
  final DateTime weekStart;

  String detailLabel(_GraphMetric metric) {
    final weekLabel = _weekAxisLabel(weekStart);
    switch (metric) {
      case _GraphMetric.locationsVisited:
        return 'Week of $weekLabel · $value Locations Visited';
      case _GraphMetric.tilesUnlocked:
        return 'Week of $weekLabel · $value Tiles Unlocked';
      case _GraphMetric.journeysCompleted:
        return 'Week of $weekLabel · $value Journeys Completed';
      case _GraphMetric.sidequestsCompleted:
        return 'Week of $weekLabel · $value Sidequests Completed';
      case _GraphMetric.xpGained:
        return 'Week of $weekLabel · $value XP';
    }
  }
}

/// Monday-start local week buckets covering the latest six weeks.
///
/// Events are assigned by calendar date so the same timestamp always maps to
/// the same week without timezone off-by-one flips within local wall time.
List<_MetricBucket> _weeklyBucketsFromDates(List<DateTime> dates) {
  final anchor = dates.isEmpty
      ? _startOfWeek(DateTime.now())
      : _startOfWeek(
          dates.reduce(
            (latest, value) => value.isAfter(latest) ? value : latest,
          ),
        );
  final starts = List<DateTime>.generate(
    6,
    (index) => anchor.subtract(Duration(days: 7 * (5 - index))),
  );

  return starts.map((start) {
    final end = start.add(const Duration(days: 7));
    final count = dates
        .where((date) => !date.isBefore(start) && date.isBefore(end))
        .length;
    return _MetricBucket(
      label: _weekAxisLabel(start),
      value: count,
      weekStart: start,
    );
  }).toList();
}

List<_MetricBucket> _weeklyBucketsFromXpEvents(List<XpEvent> events) {
  final dates = events.map((event) => event.earnedAt).toList();
  final anchor = dates.isEmpty
      ? _startOfWeek(DateTime.now())
      : _startOfWeek(
          dates.reduce(
            (latest, value) => value.isAfter(latest) ? value : latest,
          ),
        );
  final starts = List<DateTime>.generate(
    6,
    (index) => anchor.subtract(Duration(days: 7 * (5 - index))),
  );

  return starts.map((start) {
    final end = start.add(const Duration(days: 7));
    final total = events
        .where(
          (event) =>
              !event.earnedAt.isBefore(start) && event.earnedAt.isBefore(end),
        )
        .fold<int>(0, (sum, event) => sum + event.amount);
    return _MetricBucket(
      label: _weekAxisLabel(start),
      value: total,
      weekStart: start,
    );
  }).toList();
}

List<_MetricBucket> _emptyRecentBuckets() {
  final anchor = _startOfWeek(DateTime.now());
  return List<DateTime>.generate(
    6,
    (index) => anchor.subtract(Duration(days: 7 * (5 - index))),
  ).map((start) {
    return _MetricBucket(
      label: _weekAxisLabel(start),
      value: 0,
      weekStart: start,
    );
  }).toList();
}

DateTime _startOfWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

const _shortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _weekAxisLabel(DateTime start) =>
    '${start.day} ${_shortMonths[start.month - 1]}';

String _formatNumber(int value) {
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
