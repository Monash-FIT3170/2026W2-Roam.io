/*
 * Author: Amarprit Singh
 * Last Updated: 26 August 2026
 * Description:
 *   Regression test for the Google Map preview painting over sheets opened on
 *   top of it — on iOS the map is a native view that composites above later
 *   routes, so it has to stop painting while this route is covered.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/activity_feed/domain/activity_route.dart';
import 'package:roam_io/features/activity_feed/widgets/activity_map_preview.dart';
import 'package:roam_io/features/map/data/journey_map_snapshot_service.dart';

void main() {
  testWidgets('map preview stops painting while a sheet covers it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final route = ActivityRoute.fromPoints(const [
      LatLng(-37.8136, 144.9631),
      LatLng(-37.8036, 144.9731),
    ])!;

    late BuildContext screenContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              screenContext = context;
              return ActivityMapPreview(
                route: route,
                snapshotOverlay: JourneyMapSnapshotOverlay.empty,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_mapVisibility(tester).visible, isTrue);

    showModalBottomSheet<void>(
      context: screenContext,
      builder: (_) => const SizedBox(height: 200),
    );
    await tester.pumpAndSettle();

    expect(_mapVisibility(tester).visible, isFalse);
    // The map stays mounted so it comes straight back without reloading.
    expect(find.byType(GoogleMap, skipOffstage: false), findsOneWidget);

    Navigator.of(screenContext).pop();
    await tester.pumpAndSettle();

    expect(_mapVisibility(tester).visible, isTrue);
  });
}

Visibility _mapVisibility(WidgetTester tester) {
  return tester.widget<Visibility>(
    find
        .ancestor(
          of: find.byType(GoogleMap, skipOffstage: false),
          matching: find.byType(Visibility, skipOffstage: false),
        )
        .first,
  );
}
