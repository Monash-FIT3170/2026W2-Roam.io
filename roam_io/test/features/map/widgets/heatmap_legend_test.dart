import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/domain/exploration_overlay_style.dart';
import 'package:roam_io/features/map/widgets/heatmap_legend.dart';
import 'package:roam_io/theme/app_theme.dart';

void main() {
  testWidgets('uses readable dark text and the dark heatmap colours', (
    tester,
  ) async {
    await _pumpLegend(
      tester,
      theme: AppTheme.darkTheme,
      style: ExplorationOverlayStyle.dark,
    );

    final expectedTextColor = AppTheme.darkTheme.colorScheme.onSurface;
    for (final label in _labels) {
      expect(_text(tester, label).style?.color, expectedTextColor);
    }

    _expectSwatches(ExplorationOverlayStyle.dark);
    _expectLegendIsLocallyBounded(tester);
  });

  testWidgets('preserves light text and the light heatmap colours', (
    tester,
  ) async {
    await _pumpLegend(
      tester,
      theme: AppTheme.lightTheme,
      style: ExplorationOverlayStyle.light,
    );

    expect(
      _text(tester, 'Heatmap legend').style?.color,
      AppTheme.lightTheme.textTheme.labelLarge?.color,
    );
    for (final label in _entryLabels) {
      expect(_text(tester, label).style?.color, Colors.black);
    }

    _expectSwatches(ExplorationOverlayStyle.light);
    _expectLegendIsLocallyBounded(tester);
  });
}

const List<String> _labels = <String>['Heatmap legend', ..._entryLabels];

const List<String> _entryLabels = <String>[
  '1–2 entries',
  '3–4 entries',
  '5+ entries',
];

Future<void> _pumpLegend(
  WidgetTester tester, {
  required ThemeData theme,
  required ExplorationOverlayStyle style,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(child: HeatmapLegend(style: style)),
      ),
    ),
  );
}

Text _text(WidgetTester tester, String label) {
  return tester.widget<Text>(find.text(label));
}

void _expectSwatches(ExplorationOverlayStyle style) {
  for (final color in <Color>[
    style.heatmapColdColor,
    style.heatmapWarmColor,
    style.heatmapHotColor,
  ]) {
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == color;
      }),
      findsOneWidget,
    );
  }
}

void _expectLegendIsLocallyBounded(WidgetTester tester) {
  final legendSize = tester.getSize(find.byType(HeatmapLegend));

  expect(legendSize.width, lessThanOrEqualTo(200));
  expect(legendSize.height, lessThan(200));
}
