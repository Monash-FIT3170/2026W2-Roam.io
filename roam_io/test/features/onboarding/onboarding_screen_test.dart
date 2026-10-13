import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/onboarding/screens/onboarding_screen.dart';
import 'package:roam_io/theme/app_theme.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    FutureOr<void> Function()? onComplete,
    bool dark = false,
    bool reducedMotion = false,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: tester.view.physicalSize / tester.view.devicePixelRatio,
            disableAnimations: reducedMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: OnboardingScreen(onComplete: onComplete ?? () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'saving prevents duplicate completions and allows retry after failure',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await open(
        tester,
        onComplete: () {
          calls++;
          if (calls == 1) return pending.future;
        },
      );
      await tester.tap(find.text('Skip tour'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(find.text('Skip tour'));
      expect(calls, 1);
      pending.completeError(StateError('Offline'));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t save your progress. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Skip tour'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(
        find.text('Couldn’t save your progress. Please try again.'),
        findsNothing,
      );
    },
  );

  testWidgets('waits for viewport metrics during Android startup', (
    tester,
  ) async {
    tester.view.physicalSize = Size.zero;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(PageView), findsNothing);
    tester.view.physicalSize = const Size(390, 844);
    await open(tester);
    expect(find.text('1 / 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipes both ways and keeps navigation and progress in sync', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('A world waiting\nto be uncovered.'), findsOneWidget);
    expect(find.text('1 / 6'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Your everyday.\nAn adventure.'), findsOneWidget);
    expect(find.text('2 / 6'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous chapter'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 6'), findsOneWidget);
    await tester.tap(find.text('Next chapter'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 / 6'), findsOneWidget);
  });

  testWidgets('covers all six chapters and finishes only on explicit action', (
    tester,
  ) async {
    var completions = 0;
    await open(tester, onComplete: () => completions++);
    for (final topic in [
      'JOURNEYS',
      'LOCATIONS',
      'SIDEQUESTS',
      'SOCIAL',
      'PROGRESSION',
    ]) {
      await tester.tap(find.text('Next chapter'));
      await tester.pumpAndSettle();
      expect(find.textContaining('/  $topic'), findsOneWidget);
      expect(completions, 0);
    }
    expect(find.text('6 / 6'), findsOneWidget);
    expect(find.text('Next chapter'), findsNothing);
    await tester.tap(find.text('Let’s roam'));
    await tester.tap(find.text('Let’s roam'));
    expect(completions, 1);
  });

  testWidgets('skip invokes the same completion callback once', (tester) async {
    var completions = 0;
    await open(tester, onComplete: () => completions++);
    await tester.tap(find.text('Skip tour'));
    await tester.tap(find.text('Skip tour'));
    expect(completions, 1);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'all chapters fit narrow screens and large text in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(tester, dark: dark, textScale: 2, reducedMotion: true);
        for (var chapter = 0; chapter < 6; chapter++) {
          expect(tester.takeException(), isNull);
          expect(find.text('${chapter + 1} / 6'), findsOneWidget);
          await tester.drag(
            find.byType(SingleChildScrollView).last,
            const Offset(0, -900),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (chapter < 5) {
            await tester.tap(find.text('Next chapter'));
            await tester.pumpAndSettle();
          }
        }
        expect(find.text('Let’s roam').hitTestable(), findsOneWidget);
      },
    );
  }

  testWidgets('announces current chapter and settles with reduced motion', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await open(tester, reducedMotion: true);
      expect(find.bySemanticsLabel('Page 1 of 6, exploration'), findsOneWidget);
      await tester.tap(find.text('Next chapter'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Page 2 of 6, journeys'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    } finally {
      semantics.dispose();
    }
  });
}
