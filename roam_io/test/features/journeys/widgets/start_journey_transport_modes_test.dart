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
}
