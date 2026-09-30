import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_surfaces.dart';
import '../models/stats_chart_scale.dart';
import '../models/stats_metric_bucket.dart';

/// Interactive trend chart with shared time filters and direct manipulation.
class StatsWeeklyChart extends StatefulWidget {
  const StatsWeeklyChart({
    super.key,
    required this.buckets,
    required this.emptyMessage,
    this.bucketsForRange,
    this.detailLabelBuilder,
    this.hasData = true,
    this.rangeStorageId,
  });

  final List<StatsMetricBucket> buckets;
  final List<StatsMetricBucket> Function(StatsTimeRange range)? bucketsForRange;
  final String emptyMessage;
  final String Function(StatsMetricBucket bucket)? detailLabelBuilder;

  /// Distinguishes a genuinely new account from a valid all-zero period.
  final bool hasData;

  /// Persists this chart's selected range while Statistics tabs are switched.
  final String? rangeStorageId;

  @override
  State<StatsWeeklyChart> createState() => _StatsWeeklyChartState();
}

class _StatsWeeklyChartState extends State<StatsWeeklyChart> {
  StatsTimeRange _range = StatsTimeRange.threeMonths;
  int? _selectedPointIndex;
  bool _restoredRange = false;

  List<StatsMetricBucket> get _buckets {
    final values = List<StatsMetricBucket>.of(
      widget.bucketsForRange?.call(_range) ?? widget.buckets,
    );
    values.sort((left, right) => left.weekStart.compareTo(right.weekStart));
    return values;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredRange) return;
    _restoredRange = true;
    final storageId = widget.rangeStorageId;
    if (storageId == null) return;
    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: storageId);
    if (saved is String) {
      for (final range in StatsTimeRange.values) {
        if (range.name == saved) {
          _range = range;
          break;
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant StatsWeeklyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buckets != widget.buckets ||
        oldWidget.bucketsForRange != widget.bucketsForRange ||
        oldWidget.hasData != widget.hasData) {
      _selectedPointIndex = null;
    }
    if (oldWidget.rangeStorageId != widget.rangeStorageId) {
      _restoredRange = false;
    }
  }

  void _selectRange(StatsTimeRange range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _selectedPointIndex = null;
    });
    final storageId = widget.rangeStorageId;
    if (storageId != null) {
      PageStorage.maybeOf(
        context,
      )?.writeState(context, range.name, identifier: storageId);
    }
  }

  void _selectPoint(int index) {
    if (_selectedPointIndex == index) return;
    setState(() => _selectedPointIndex = index);
    unawaited(HapticFeedback.selectionClick());
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _buckets;
    final chartSignature = Object.hash(
      _range,
      widget.hasData,
      Object.hashAll(
        buckets.map(
          (bucket) => Object.hash(bucket.weekStart, bucket.value, bucket.label),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimeRangeSelector(selected: _range, onSelected: _selectRange),
        const SizedBox(height: 6),
        SizedBox(
          height: 148,
          width: double.infinity,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: !widget.hasData
                ? _ChartEmptyState(
                    key: ValueKey<String>('empty-${_range.name}'),
                    message: widget.emptyMessage,
                  )
                : KeyedSubtree(
                    key: ValueKey<int>(chartSignature),
                    child: _InteractiveChart(
                      buckets: buckets,
                      selectedPointIndex: _selectedPointIndex,
                      detailLabelBuilder: widget.detailLabelBuilder,
                      onPointSelected: _selectPoint,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TimeRangeSelector extends StatelessWidget {
  const _TimeRangeSelector({required this.selected, required this.onSelected});

  final StatsTimeRange selected;
  final ValueChanged<StatsTimeRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          for (
            var index = 0;
            index < StatsTimeRange.values.length;
            index++
          ) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '·',
                  style: TextStyle(color: AppSurfaces.textSubtle(context)),
                ),
              ),
            Expanded(
              child: InkWell(
                key: ValueKey<String>(
                  'stats-range-${StatsTimeRange.values[index].label}',
                ),
                onTap: () => onSelected(StatsTimeRange.values[index]),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 160),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: selected == StatsTimeRange.values[index]
                          ? Theme.of(context).colorScheme.primary
                          : AppSurfaces.textMuted(context),
                      fontWeight: selected == StatsTimeRange.values[index]
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    child: Text(StatsTimeRange.values[index].label),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 24,
              color: AppSurfaces.textSubtle(context),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractiveChart extends StatelessWidget {
  const _InteractiveChart({
    required this.buckets,
    required this.selectedPointIndex,
    required this.detailLabelBuilder,
    required this.onPointSelected,
  });

  final List<StatsMetricBucket> buckets;
  final int? selectedPointIndex;
  final String Function(StatsMetricBucket bucket)? detailLabelBuilder;
  final ValueChanged<int> onPointSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedIndex = selectedPointIndex;
        final chart = _StatsLineChartPainter(
          buckets: buckets,
          selectedIndex: selectedIndex,
          lineColor: theme.colorScheme.primary,
          fillColor: theme.colorScheme.primary.withValues(alpha: 0.07),
          gridColor: AppSurfaces.border(context),
          labelColor: AppSurfaces.textMuted(context),
          axisLabelColor: AppSurfaces.textMuted(context),
        );
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final points = chart.pointOffsets(size);

        void selectNearest(double x) {
          if (points.isEmpty) return;
          var nearest = 0;
          var distance = double.infinity;
          for (var index = 0; index < points.length; index++) {
            final candidate = (points[index].dx - x).abs();
            if (candidate < distance) {
              nearest = index;
              distance = candidate;
            }
          }
          onPointSelected(nearest);
        }

        double pointHitWidth(int index) {
          if (points.length == 1) return 36;
          final previousGap = index == 0
              ? double.infinity
              : points[index].dx - points[index - 1].dx;
          final nextGap = index == points.length - 1
              ? double.infinity
              : points[index + 1].dx - points[index].dx;
          return math.min(36.0, math.max(4.0, math.min(previousGap, nextGap)));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => selectNearest(details.localPosition.dx),
          onHorizontalDragStart: (details) =>
              selectNearest(details.localPosition.dx),
          onHorizontalDragUpdate: (details) =>
              selectNearest(details.localPosition.dx),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(size: Size.infinite, painter: chart),
              for (var index = 0; index < points.length; index++)
                Positioned(
                  left: points[index].dx - pointHitWidth(index) / 2,
                  top: points[index].dy - 18,
                  child: Semantics(
                    button: true,
                    label:
                        detailLabelBuilder?.call(buckets[index]) ??
                        '${buckets[index].label}, ${formatExactStatNumber(buckets[index].value)}',
                    child: GestureDetector(
                      key: ValueKey<String>('stats-graph-point-$index'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onPointSelected(index),
                      child: SizedBox(width: pointHitWidth(index), height: 36),
                    ),
                  ),
                ),
              if (selectedIndex != null &&
                  selectedIndex >= 0 &&
                  selectedIndex < points.length)
                _ChartTooltip(
                  point: points[selectedIndex],
                  chartWidth: constraints.maxWidth,
                  label:
                      detailLabelBuilder?.call(buckets[selectedIndex]) ??
                      'Week of ${formatWeekDetailLabel(buckets[selectedIndex].weekStart)} · '
                          '${formatExactStatNumber(buckets[selectedIndex].value)}',
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ChartTooltip extends StatelessWidget {
  const _ChartTooltip({
    required this.point,
    required this.chartWidth,
    required this.label,
  });

  final Offset point;
  final double chartWidth;
  final String label;

  @override
  Widget build(BuildContext context) {
    final width = math.min(196.0, math.max(112.0, chartWidth - 8));
    final maxLeft = math.max(0.0, chartWidth - width);
    final left = (point.dx - width / 2).clamp(0.0, maxLeft);
    final top = math.max(0.0, point.dy - 40);
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppSurfaces.pageBackground(context),
            border: Border.all(color: AppSurfaces.border(context)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppSurfaces.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsLineChartPainter extends CustomPainter {
  _StatsLineChartPainter({
    required this.buckets,
    required this.selectedIndex,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelColor,
    required this.axisLabelColor,
  }) : scale = StatsChartScale.fromValues(
         buckets.map((bucket) => bucket.value),
       );

  final List<StatsMetricBucket> buckets;
  final int? selectedIndex;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color labelColor;
  final Color axisLabelColor;
  final StatsChartScale scale;

  static const double _leftPad = 44;
  static const double _rightPad = 8;
  static const double _topPad = 12;
  static const double _bottomPad = 32;

  List<Offset> pointOffsets(Size size) {
    if (buckets.isEmpty) return const <Offset>[];
    final chartLeft = _leftPad;
    final chartRight = math.max(chartLeft, size.width - _rightPad);
    final chartBottom = math.max(_topPad, size.height - _bottomPad);
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - _topPad;
    final first = buckets.first.weekStart.millisecondsSinceEpoch;
    final last = buckets.last.weekStart.millisecondsSinceEpoch;
    final span = last - first;

    return List<Offset>.generate(buckets.length, (index) {
      final xFraction = span <= 0
          ? 0.5
          : (buckets[index].weekStart.millisecondsSinceEpoch - first) / span;
      final x = chartLeft + chartWidth * xFraction.clamp(0.0, 1.0);
      final value = math.max(0, buckets[index].value);
      final y = chartBottom - chartHeight * value / scale.maxY;
      return Offset(x, y);
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartLeft = _leftPad;
    final chartRight = math.max(chartLeft, size.width - _rightPad);
    final chartTop = _topPad;
    final chartBottom = math.max(chartTop, size.height - _bottomPad);
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.7)
      ..strokeWidth = 0.65;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final labelStyle = TextStyle(
      color: labelColor,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );
    final yLabelStyle = TextStyle(
      color: axisLabelColor,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    for (final tick in scale.ticks) {
      final y = chartBottom - chartHeight * tick / scale.maxY;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
      final painter = TextPainter(
        text: TextSpan(text: formatStatsAxisValue(tick), style: yLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _leftPad - 6);
      painter.paint(
        canvas,
        Offset(chartLeft - painter.width - 6, y - painter.height / 2),
      );
    }

    final points = pointOffsets(size);
    if (points.length > 1) {
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
    }
    for (var index = 0; index < points.length; index++) {
      if (points.length <= 13 || index == selectedIndex) {
        canvas.drawCircle(
          points[index],
          index == selectedIndex ? 5.5 : 3.5,
          pointPaint,
        );
      }
    }

    for (final index in _xLabelIndexes(chartWidth)) {
      final painter = TextPainter(
        text: TextSpan(
          text: _axisLabel(buckets[index].weekStart),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
      )..layout();
      final x = points[index].dx;
      painter.paint(
        canvas,
        Offset(
          (x - painter.width / 2).clamp(chartLeft, chartRight - painter.width),
          chartBottom + 9,
        ),
      );
    }
  }

  Set<int> _xLabelIndexes(double chartWidth) {
    if (buckets.isEmpty) return const <int>{};
    if (buckets.length == 1) return const <int>{0};
    final maxLabels = (chartWidth / 66).floor().clamp(2, 5);
    if (buckets.length <= maxLabels) {
      return <int>{for (var index = 0; index < buckets.length; index++) index};
    }
    return <int>{
      for (var slot = 0; slot < maxLabels; slot++)
        (slot * (buckets.length - 1) / (maxLabels - 1)).round(),
    };
  }

  String _axisLabel(DateTime date) {
    final spansYears =
        buckets.isNotEmpty &&
        (buckets.first.weekStart.year != buckets.last.weekStart.year ||
            buckets.last.weekStart.difference(buckets.first.weekStart).inDays >
                330);
    final base = formatWeekAxisLabel(date);
    return spansYears ? "$base '${date.year.toString().substring(2)}" : base;
  }

  @override
  bool shouldRepaint(covariant _StatsLineChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.axisLabelColor != axisLabelColor;
  }
}
