import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/you/milestones/milestone_card.dart';
import 'package:roam_io/features/you/milestones/milestone_catalog.dart';
import 'package:roam_io/features/you/milestones/milestone_progress.dart';

void main() {
  const longDefinition = MilestoneDefinition(
    id: MilestoneId.visitViking,
    title: 'An exceptionally long milestone name that needs two lines',
    subtitle:
        'A much longer milestone description that should remain aligned and readable even on a compact phone.',
    unit: MilestoneMetricUnit.count,
    tiers: <MilestoneTierDefinition>[
      MilestoneTierDefinition(tier: 1, threshold: 5, xpReward: 100),
      MilestoneTierDefinition(tier: 2, threshold: 15, xpReward: 400),
    ],
  );

  Future<void> pumpCard(
    WidgetTester tester,
    MilestoneProgress progress, {
    required Size size,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: MilestoneCard(
              progress: progress,
              claimInFlight: false,
              onClaim: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('long progress content stays aligned on a compact device', (
    tester,
  ) async {
    final progress = MilestoneProgress(
      definition: longDefinition,
      currentValue: 11,
      earnedTier: 1,
      claimedTiers: const <int>{1},
      claimableTiers: const <int>[],
      displayTier: 2,
      nextTier: longDefinition.tierDefinition(2),
      progressToNext: 0.6,
    );

    await pumpCard(tester, progress, size: const Size(320, 600));

    expect(find.text(longDefinition.title), findsOneWidget);
    expect(find.text(longDefinition.subtitle), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready-to-claim layout remains tappable with long content', (
    tester,
  ) async {
    final progress = MilestoneProgress(
      definition: longDefinition,
      currentValue: 5,
      earnedTier: 1,
      claimedTiers: const <int>{},
      claimableTiers: const <int>[1],
      displayTier: 1,
      nextTier: longDefinition.tierDefinition(2),
      progressToNext: 0,
    );

    await pumpCard(tester, progress, size: const Size(430, 600));

    expect(find.text('Ready to claim · Tier 1'), findsOneWidget);
    expect(find.text('+100 XP'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Claim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
