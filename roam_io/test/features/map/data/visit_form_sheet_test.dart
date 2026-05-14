import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/data/place_of_interest.dart';
import 'package:roam_io/features/map/data/visit.dart';
import 'package:roam_io/features/map/data/visit_form_sheet.dart';
import 'package:roam_io/features/map/data/visit_service.dart';
import 'package:roam_io/services/storage_service.dart';

import '../../../support/map_test_doubles.dart';

StorageService _testStorage() {
  return StorageService(
    visitMediaUploadOverride:
        ({
          required String uid,
          required int placeId,
          required Uint8List bytes,
          required String filename,
        }) async =>
            'https://test.local/visit/$placeId/${filename.hashCode}.jpg',
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  group('VisitFormSheet create mode', () {
    testWidgets('shows log visit copy and prefills place name', (tester) async {
      final place = testPlace(id: 10, name: 'River Cafe');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitFormSheet(
              place: place,
              userId: 'user-1',
              visitService: VisitService(firestore: FakeFirebaseFirestore()),
              storageService: _testStorage(),
            ),
          ),
        ),
      );

      expect(find.text('Log Your Visit'), findsOneWidget);
      expect(find.text('River Cafe'), findsWidgets);
      expect(find.text('Log Visit'), findsOneWidget);

      final nameField = find.byType(TextFormField).first;
      expect(
        tester.widget<TextFormField>(nameField).controller!.text,
        'River Cafe',
      );
    });

    testWidgets('validates empty name', (tester) async {
      final place = testPlace(id: 11);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitFormSheet(
              place: place,
              userId: 'user-1',
              visitService: VisitService(firestore: FakeFirebaseFirestore()),
              storageService: _testStorage(),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.tap(find.text('Log Visit'));
      await tester.pump();

      expect(find.text('Please enter a name'), findsOneWidget);
    });

    testWidgets('cancel pops with cancelled result', (tester) async {
      VisitFormResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    result = await VisitFormSheet.show(
                      context: context,
                      place: testPlace(id: 12),
                      userId: 'user-1',
                      visitService: VisitService(
                        firestore: FakeFirebaseFirestore(),
                      ),
                      storageService: _testStorage(),
                    );
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, VisitFormResult.cancelled);
    });

    testWidgets(
      'save pops success and passes null custom name when unchanged',
      (tester) async {
        final place = testPlace(id: 13, name: 'Same Name');
        final visitService = _CapturingVisitService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VisitFormSheet(
                place: place,
                userId: 'user-1',
                visitService: visitService,
                storageService: _testStorage(),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Log Visit'));
        await tester.pumpAndSettle();

        expect(visitService.markVisitedCalls, 1);
        expect(visitService.lastCustomName, isNull);
        expect(visitService.lastDescription, isNull);
      },
    );

    testWidgets('save passes trimmed custom name when edited', (tester) async {
      final place = testPlace(id: 14, name: 'Park');
      final visitService = _CapturingVisitService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitFormSheet(
              place: place,
              userId: 'user-1',
              visitService: visitService,
              storageService: _testStorage(),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, '  My Park  ');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '  Great walk  ',
      );
      await tester.tap(find.text('Log Visit'));
      await tester.pumpAndSettle();

      expect(visitService.markVisitedCalls, 1);
      expect(visitService.lastCustomName, 'My Park');
      expect(visitService.lastDescription, 'Great walk');
    });

    testWidgets('save shows error when visit service throws', (tester) async {
      final visitService = _ThrowingVisitService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitFormSheet(
              place: testPlace(id: 15),
              userId: 'user-1',
              visitService: visitService,
              storageService: _testStorage(),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Log Visit'));
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to save visit. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Log Visit'), findsOneWidget);
    });
  });

  group('VisitFormSheet edit mode', () {
    testWidgets('shows edit copy and save changes', (tester) async {
      final place = testPlace(id: 20, name: 'Museum');
      final visit = Visit(
        placeId: 20,
        googlePlaceId: 'gp-20',
        placeName: 'Museum',
        regionId: 'region-1',
        category: PlaceCategory.other.name,
        visitedAt: DateTime(2026, 2, 1),
        customName: 'Art day',
        description: 'Saw the exhibition',
        mediaUrls: const <String>[],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitFormSheet(
              place: place,
              userId: 'user-1',
              existingVisit: visit,
              visitService: VisitService(firestore: FakeFirebaseFirestore()),
              storageService: _testStorage(),
            ),
          ),
        ),
      );

      expect(find.text('Edit Visit'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Art day',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'Saw the exhibition',
      );
    });

    testWidgets('save calls updateVisit with merged fields', (tester) async {
      final place = testPlace(id: 21, name: 'Museum');
      final visit = Visit(
        placeId: 21,
        googlePlaceId: 'gp-21',
        placeName: 'Museum',
        regionId: 'region-1',
        category: PlaceCategory.other.name,
        visitedAt: DateTime(2026, 2, 1),
        customName: 'Old custom',
        description: 'Old desc',
        mediaUrls: const <String>['https://example.com/old.jpg'],
      );

      final visitService = _CapturingVisitService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitFormSheet(
              place: place,
              userId: 'user-1',
              existingVisit: visit,
              visitService: visitService,
              storageService: _testStorage(),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'Museum');
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(visitService.updateVisitCalls, 1);
      expect(visitService.lastUpdatePlaceId, 21);
      expect(visitService.lastUpdateCustomName, isNull);
      expect(visitService.lastUpdateDescription, isNull);
      expect(visitService.lastUpdateMediaUrls, ['https://example.com/old.jpg']);
    });

    testWidgets('existing media shows remove control', (tester) async {
      final place = testPlace(id: 22, name: 'Gallery');
      final visit = Visit(
        placeId: 22,
        googlePlaceId: 'gp-22',
        placeName: 'Gallery',
        regionId: 'region-1',
        category: PlaceCategory.other.name,
        visitedAt: DateTime(2026, 2, 1),
        mediaUrls: const <String>['https://example.com/shot.jpg'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitFormSheet(
              place: place,
              userId: 'user-1',
              existingVisit: visit,
              visitService: VisitService(firestore: FakeFirebaseFirestore()),
              storageService: _testStorage(),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.byIcon(Icons.close), findsNothing);
    });
  });
}

class _CapturingVisitService extends VisitService {
  _CapturingVisitService() : super(firestore: FakeFirebaseFirestore());

  int markVisitedCalls = 0;
  int updateVisitCalls = 0;
  String? lastCustomName;
  String? lastDescription;
  int? lastUpdatePlaceId;
  String? lastUpdateCustomName;
  String? lastUpdateDescription;
  List<String>? lastUpdateMediaUrls;

  @override
  Future<void> markVisited({
    required String userId,
    required PlaceOfInterest place,
    String? customName,
    String? description,
    List<String>? mediaUrls,
  }) async {
    markVisitedCalls++;
    lastCustomName = customName;
    lastDescription = description;
    await super.markVisited(
      userId: userId,
      place: place,
      customName: customName,
      description: description,
      mediaUrls: mediaUrls,
    );
  }

  @override
  Future<void> updateVisit({
    required String userId,
    required int placeId,
    String? customName,
    String? description,
    List<String>? mediaUrls,
  }) async {
    updateVisitCalls++;
    lastUpdatePlaceId = placeId;
    lastUpdateCustomName = customName;
    lastUpdateDescription = description;
    lastUpdateMediaUrls = mediaUrls;
  }
}

class _ThrowingVisitService extends VisitService {
  _ThrowingVisitService() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<void> markVisited({
    required String userId,
    required PlaceOfInterest place,
    String? customName,
    String? description,
    List<String>? mediaUrls,
  }) async {
    throw StateError('persist failed');
  }
}
