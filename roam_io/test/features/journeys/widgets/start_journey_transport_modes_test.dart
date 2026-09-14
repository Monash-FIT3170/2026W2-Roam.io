import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/journeys/widgets/start_journey_sheet.dart';

void main() {
  testWidgets('shows only transport modes available at the current location', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StartJourneySheet(
            currentPosition: LatLng(-37.81, 144.96),
            availableTransportModes: {
              TransportMode.walk,
              TransportMode.drive,
              TransportMode.bus,
            },
          ),
        ),
      ),
    );

    expect(find.text('Walk'), findsOneWidget);
    expect(find.text('Drive'), findsOneWidget);
    expect(find.text('Bus'), findsOneWidget);
    expect(find.text('Train'), findsNothing);
    expect(find.text('Tram'), findsNothing);
  });

  for (final mode in [TransportMode.drive, TransportMode.walk]) {
    testWidgets('returns the typed ${mode.name} transport mode', (
      tester,
    ) async {
      StartJourneyResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await StartJourneySheet.show(
                    context: context,
                    currentPosition: const LatLng(-37.81, 144.96),
                  );
                },
                child: const Text('Open journey setup'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open journey setup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(mode.displayName));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Start Journey'));
      await tester.pumpAndSettle();

      expect(result?.transportMode, mode);
    });
  }
}
