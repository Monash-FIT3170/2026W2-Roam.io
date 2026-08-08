import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/widgets/custom_location_details_sheet.dart';

void main() {
  testWidgets('shows custom location name, type, distance, and edit action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomLocationDetailsSheet(
            location: const JourneyLocation(
              latLng: LatLng(-37.8136, 144.9631),
              displayName: 'Current Location',
              customName: 'Creek lookout',
              description: 'A quiet place near the trail.',
            ),
            distanceMeters: 17,
            userId: 'user-1',
            onSave: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Creek lookout'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('17m away'), findsOneWidget);
    expect(find.text('A quiet place near the trail.'), findsOneWidget);
    expect(find.text('Edit location'), findsOneWidget);
  });
}
