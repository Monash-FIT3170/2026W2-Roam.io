import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/journeys/widgets/custom_location_form_sheet.dart';
import 'package:roam_io/features/journeys/widgets/journey_summary_sheet.dart';

const _keyboardInset = 300.0;
const _location = JourneyLocation(
  latLng: LatLng(-37.8136, 144.9631),
  displayName: 'Current Location',
);

void main() {
  testWidgets('journey name editor moves above the keyboard', (tester) async {
    await _pumpWithKeyboard(
      tester,
      JourneySummarySheet(
        startLocation: _location,
        endLocation: _location,
        transportMode: TransportMode.walk,
        distanceMeters: 100,
        duration: const Duration(minutes: 2),
        routePoints: const [],
        onUpdateStartName: (_) {},
        onUpdateEndName: (_) {},
      ),
    );

    _expectKeyboardPadding('journey_summary_keyboard_padding', tester);
  });

  testWidgets('custom location form moves above the keyboard', (tester) async {
    await _pumpWithKeyboard(
      tester,
      const CustomLocationFormSheet(location: _location, userId: 'user-1'),
    );

    _expectKeyboardPadding('custom_location_keyboard_padding', tester);
  });
}

Future<void> _pumpWithKeyboard(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          viewInsets: EdgeInsets.only(bottom: _keyboardInset),
        ),
        child: Scaffold(resizeToAvoidBottomInset: false, body: child),
      ),
    ),
  );
}

void _expectKeyboardPadding(String key, WidgetTester tester) {
  final padding = tester.widget<AnimatedPadding>(find.byKey(ValueKey(key)));
  expect((padding.padding as EdgeInsets).bottom, _keyboardInset);
  expect(find.byType(SingleChildScrollView), findsWidgets);
}
