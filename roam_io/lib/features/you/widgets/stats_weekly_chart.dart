import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../models/stats_metric_bucket.dart';

/// Interactive weekly line chart used across Stats category pages.
class StatsWeeklyChart extends StatefulWidget {
  const StatsWeeklyChart({
    super.key,
    required this.buckets,
    required this.emptyMessage,
    this.detailLabelBuilder,
  });

  final List<StatsMetricBucket> buckets;
  final String emptyMessage;
  final String Function(StatsMetricBucket bucket)? detailLabelBuilder;

  @override
  State<StatsWeeklyChart> createState() => _StatsWeeklyChartState();
}

class _StatsWeeklyChartState extends State<StatsWeeklyChart> {
  int? _selectedPointIndex;

  @override
  void didUpdateWidget(covariant StatsWeeklyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buckets != widget.buckets) {
      _selectedPointIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = widget.buckets.any((bucket) => bucket.value > 0);
    final selectedIndex = _selectedPointIndex;
    final selectedBucket =
        selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < widget.buckets.length
        ? widget.buckets[selectedIndex]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 28,
          child: selectedBucket == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.center,
                  child: Text(
                    widget.detailLabelBuilder?.call(selectedBucket) ??
                        '${selectedBucket.label} · ${selectedBucket.value}',
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
                    final chart = _StatsLineChartPainter(
                      buckets: widget.buckets,
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
                              key: ValueKey<String>('stats-graph-point-$index'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _selectedPointIndex = index;
                                });
                              },
                              child: const SizedBox(width: 44, height: 44),
                            ),
                          ),
                      ],
                    );
                  },
                )
              : Center(
                  child: Text(
                    widget.emptyMessage,
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
}

class _StatsLineChartPainter extends CustomPainter {
  const _StatsLineChartPainter({
    required this.buckets,
    required this.selectedIndex,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelColor,
    required this.axisLabelColor,
  });

  final List<StatsMetricBucket> buckets;
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
