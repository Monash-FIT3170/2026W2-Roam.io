import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/journeys/widgets/driving_safety_dialog.dart';

void main() {
  testWidgets('requires explicit acknowledgement before returning true', (
    tester,
  ) async {
    final harness = await _pumpDialogHarness(tester);

    await tester.tap(find.text('Show warning'));
    await tester.pumpAndSettle();

    expect(find.text('Drive Safely'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(
      find.textContaining('Do not use Roam.io while driving'),
      findsOneWidget,
    );
    expect(
      find.textContaining('only interact with your phone when safely parked'),
      findsOneWidget,
    );
    expect(harness.completed, isFalse);
    expect(harness.result, isNull);

    final cancelButton = find.widgetWithText(OutlinedButton, 'Cancel');
    final startButton = find.widgetWithText(FilledButton, 'Start journey');
    final cancelRect = tester.getRect(cancelButton);
    final startRect = tester.getRect(startButton);

    expect(cancelRect.top, startRect.top);
    expect(cancelRect.height, startRect.height);
    expect(startRect.left - cancelRect.right, 12);
    expect(startRect.width, greaterThan(cancelRect.width));

    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(harness.completed, isTrue);
    expect(harness.result, isTrue);
  });

  testWidgets('Cancel rejects the driving safety warning', (tester) async {
    final harness = await _pumpDialogHarness(tester);

    await tester.tap(find.text('Show warning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(harness.completed, isTrue);
    expect(harness.result, isFalse);
  });

  testWidgets('dismissing the warning rejects it', (tester) async {
    final harness = await _pumpDialogHarness(tester);

    await tester.tap(find.text('Show warning'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(harness.completed, isTrue);
    expect(harness.result, isFalse);
  });
}

Future<_DialogHarnessState> _pumpDialogHarness(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: _DialogHarness())),
  );
  return tester.state<_DialogHarnessState>(find.byType(_DialogHarness));
}

class _DialogHarness extends StatefulWidget {
  const _DialogHarness();

  @override
  State<_DialogHarness> createState() => _DialogHarnessState();
}

class _DialogHarnessState extends State<_DialogHarness> {
  bool completed = false;
  bool? result;

  Future<void> _showWarning() async {
    result = await showDrivingSafetyDialog(context);
    completed = true;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: _showWarning,
        child: const Text('Show warning'),
      ),
    );
  }
}
