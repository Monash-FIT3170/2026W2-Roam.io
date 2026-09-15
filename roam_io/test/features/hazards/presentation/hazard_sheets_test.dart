import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roam_io/features/hazards/domain/hazard_category.dart';
import 'package:roam_io/features/hazards/domain/hazard_report.dart';
import 'package:roam_io/features/hazards/domain/hazard_submission_exception.dart';
import 'package:roam_io/features/hazards/presentation/hazard_category_sheet.dart';
import 'package:roam_io/features/hazards/presentation/hazard_details_sheet.dart';
import 'package:roam_io/features/hazards/presentation/hazard_marker_builder.dart';
import 'package:roam_io/features/hazards/presentation/hazard_report_sheet.dart';
import 'package:roam_io/features/map/data/map_page.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/theme/app_colours.dart';

void main() {
  testWidgets('map report control is above recenter and both actions work', (
    tester,
  ) async {
    var reports = 0;
    var recenters = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: MapLocationControls(
              onReportHazard: () => reports++,
              onRecenter: () => recenters++,
            ),
          ),
        ),
      ),
    );

    final report = find.byKey(const ValueKey('report_hazard_button'));
    final recenter = find.byKey(const ValueKey('recenter_map_button'));
    expect(
      tester.getCenter(report).dy,
      lessThan(tester.getCenter(recenter).dy),
    );
    await tester.tap(report);
    await tester.tap(recenter);
    expect(reports, 1);
    expect(recenters, 1);

    final reportButton = tester.widget<FloatingActionButton>(report);
    expect(reportButton.backgroundColor, AppColors.sage);
    expect(reportButton.foregroundColor, Colors.white);
  });

  testWidgets('category sheet shows all categories and returns selection', (
    tester,
  ) async {
    HazardCategory? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await HazardCategorySheet.show(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    for (final category in HazardCategory.values) {
      expect(find.text(category.displayLabel), findsOneWidget);
    }
    await tester.tap(find.text('Roadworks'));
    await tester.pumpAndSettle();
    expect(selected, HazardCategory.roadworks);
  });

  testWidgets('report details supports photo preview, remove, and submission', (
    tester,
  ) async {
    HazardCategory? submittedCategory;
    String? submittedDescription;
    HazardSelectedPhoto? submittedPhoto;
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HazardReportSheet(
            category: HazardCategory.pothole,
            photoPicker: (_) async => XFile.fromData(png, name: 'pothole.png'),
            onSubmit:
                ({
                  required HazardCategory category,
                  String? description,
                  HazardSelectedPhoto? photo,
                }) async {
                  submittedCategory = category;
                  submittedDescription = description;
                  submittedPhoto = photo;
                },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('hazard_description')),
      '  Near the left lane  ',
    );
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hazard_photo_preview')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove_hazard_photo')));
    await tester.pump();
    expect(find.byKey(const ValueKey('hazard_photo_preview')), findsNothing);
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('submit_hazard')));
    await tester.tap(find.byKey(const ValueKey('submit_hazard')));
    await tester.pumpAndSettle();

    expect(submittedCategory, HazardCategory.pothole);
    expect(submittedDescription, 'Near the left lane');
    expect(submittedPhoto?.bytes, png);
  });

  testWidgets('hazard action icons use the sage accent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HazardReportSheet(
            category: HazardCategory.crash,
            onSubmit:
                ({
                  required HazardCategory category,
                  String? description,
                  HazardSelectedPhoto? photo,
                }) async {},
          ),
        ),
      ),
    );

    for (final iconData in [
      HazardCategory.crash.icon,
      Icons.photo_library_outlined,
      Icons.camera_alt_outlined,
    ]) {
      final icon = tester.widget<Icon>(find.byIcon(iconData));
      expect(icon.color, AppColors.sage);
    }
  });

  testWidgets('submission failure stays actionable and permits retry', (
    tester,
  ) async {
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HazardReportSheet(
            category: HazardCategory.flooding,
            onSubmit:
                ({
                  required HazardCategory category,
                  String? description,
                  HazardSelectedPhoto? photo,
                }) async {
                  submissions++;
                  if (submissions == 1) {
                    throw const HazardSubmissionException(
                      HazardSubmissionFailure.photoUpload,
                    );
                  }
                },
          ),
        ),
      ),
    );

    final submit = find.byKey(const ValueKey('submit_hazard'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(
      find.text('Photo upload failed. Try again or remove the photo.'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(submissions, 2);
  });

  testWidgets('details show report content and confirm only once', (
    tester,
  ) async {
    var confirmations = 0;
    final now = DateTime.now();
    final report = HazardReport(
      id: 'hazard-1',
      reporterId: 'user-1',
      category: HazardCategory.obstruction,
      latitude: -37.81,
      longitude: 144.96,
      description: 'Tree branch across the lane',
      createdAt: now.subtract(const Duration(minutes: 3)),
      lastConfirmedAt: now.subtract(const Duration(minutes: 3)),
      expiresAt: now.add(const Duration(hours: 1)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HazardDetailsSheet(
            report: report,
            onConfirm: () async => confirmations++,
          ),
        ),
      ),
    );

    expect(find.text('Obstruction'), findsOneWidget);
    expect(find.text('Tree branch across the lane'), findsOneWidget);
    expect(find.text('Reported 3 min ago'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm_hazard')));
    await tester.pump();
    expect(confirmations, 1);
    expect(find.text('Confirmed'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm_hazard')));
    expect(confirmations, 1);
  });

  test('hazard marker is smaller than a major place marker', () {
    expect(
      HazardMarkerBuilder.markerSize,
      lessThan(MarkerSize.large.pixelSize),
    );
  });

  testWidgets('hazard marker bitmap builds at the persisted coordinates', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 15, 4);
    final report = HazardReport(
      id: 'persisted-id',
      reporterId: 'user-1',
      category: HazardCategory.pothole,
      latitude: -37.8136,
      longitude: 144.9631,
      createdAt: now,
      lastConfirmedAt: now,
      expiresAt: now.add(const Duration(hours: 12)),
    );
    final builder = HazardMarkerBuilder();

    await tester.runAsync(builder.preload);
    final marker = builder.build(report, onTap: (_) {});

    expect(marker.markerId.value, 'hazard_persisted-id');
    expect(marker.position, report.location);
    expect(marker.icon, isNot(BitmapDescriptor.defaultMarker));
  });

  test('map marker composition retains hazards when place markers refresh', () {
    const hazardPosition = LatLng(-37.8136, 144.9631);
    const hazard = Marker(
      markerId: MarkerId('hazard_hazard-1'),
      position: hazardPosition,
    );
    const journey = Marker(
      markerId: MarkerId('journey_start_journey-1'),
      position: LatLng(-37.81, 144.96),
    );
    const firstPlace = Marker(
      markerId: MarkerId('place_1'),
      position: LatLng(-37.82, 144.97),
    );
    const refreshedPlace = Marker(
      markerId: MarkerId('place_2'),
      position: LatLng(-37.83, 144.98),
    );

    final initial = composeMapMarkers(
      placeMarkers: {firstPlace},
      journeyMarkers: {journey},
      hazardMarkers: {hazard},
    );
    final afterViewportRefresh = composeMapMarkers(
      placeMarkers: {refreshedPlace},
      journeyMarkers: {journey},
      hazardMarkers: {hazard},
    );

    expect(initial.map((marker) => marker.markerId.value), {
      'place_1',
      'journey_start_journey-1',
      'hazard_hazard-1',
    });
    expect(afterViewportRefresh, contains(hazard));
    expect(
      afterViewportRefresh
          .singleWhere((marker) => marker.markerId == hazard.markerId)
          .position,
      hazardPosition,
    );
  });
}
