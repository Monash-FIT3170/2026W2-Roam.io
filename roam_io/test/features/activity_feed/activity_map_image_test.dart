/*
 * Author: Amarprit Singh
 * Last Updated: 26 August 2026
 * Description:
 *   Journeys store a map image captured at save time, with the route and that
 *   day's fog already drawn on it, so home feed cards render a picture instead
 *   of standing up a native map per card.
 */

import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/activity_feed/data/activity_creation_service.dart';
import 'package:roam_io/features/activity_feed/data/activity_mutation_service.dart';
import 'package:roam_io/features/activity_feed/models/activity_feed_item.dart';
import 'package:roam_io/features/activity_feed/screens/activity_detail_screen.dart';
import 'package:roam_io/features/activity_feed/widgets/activity_feed_card.dart';
import 'package:roam_io/features/activity_feed/widgets/activity_map_preview.dart';
import 'package:roam_io/features/journeys/data/polyline_codec.dart';
import 'package:roam_io/features/journeys/domain/journey.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/services/storage_service.dart';

void main() {
  group('createJourneyActivity map image', () {
    test('uploads the captured map and stores its url', () async {
      final firestore = FakeFirebaseFirestore();
      final uploads = <String>[];

      final activity =
          await _service(
            firestore,
            onUpload: (uid, activityId, mediaId, filename) {
              uploads.add('$uid/$activityId/$mediaId/$filename');
            },
          ).createJourneyActivity(
            journey: _journey(),
            title: 'Creek Loop',
            mapImageBytes: Uint8List.fromList([1, 2, 3]),
          );

      expect(uploads, ['user-1/journey_journey-1/map/map_preview.png']);
      expect(activity.mapImageUrl, 'https://example.com/map.png');
      expect(
        activity.mapImageStoragePath,
        'activity_media/user-1/journey_journey-1/map.png',
      );

      final data = await _activityData(firestore);
      expect(data['mapImageUrl'], activity.mapImageUrl);
      expect(data['mapImageStoragePath'], activity.mapImageStoragePath);
    });

    test('stores nothing when no map was captured', () async {
      final firestore = FakeFirebaseFirestore();
      final uploads = <String>[];

      final activity = await _service(
        firestore,
        onUpload: (uid, activityId, mediaId, filename) => uploads.add(mediaId),
      ).createJourneyActivity(journey: _journey(), title: 'Creek Loop');

      expect(uploads, isEmpty);
      expect(activity.mapImageUrl, isNull);

      final data = await _activityData(firestore);
      expect(data.containsKey('mapImageUrl'), isFalse);
      expect(data.containsKey('mapImageStoragePath'), isFalse);
    });

    test(
      'attaches a new capture when the journey activity already exists',
      () async {
        final firestore = FakeFirebaseFirestore();
        final uploads = <String>[];
        final service = _service(
          firestore,
          onUpload: (uid, activityId, mediaId, filename) {
            uploads.add('$uid/$activityId/$mediaId/$filename');
          },
        );
        await service.createJourneyActivity(
          journey: _journey(),
          title: 'Creek Loop',
        );

        final activity = await service.createJourneyActivity(
          journey: _journey(),
          title: 'Creek Loop',
          mapImageBytes: Uint8List.fromList([1, 2, 3]),
        );

        expect(uploads, ['user-1/journey_journey-1/map/map_preview.png']);
        expect(activity.mapImageUrl, 'https://example.com/map.png');
        expect(
          (await _activityData(firestore))['mapImageUrl'],
          activity.mapImageUrl,
        );
      },
    );

    test(
      'does not silently publish a dynamic-map fallback when upload fails',
      () async {
        final firestore = FakeFirebaseFirestore();

        await expectLater(
          _service(
            firestore,
            onUpload: (uid, activityId, mediaId, filename) {
              throw StateError('storage unavailable');
            },
          ).createJourneyActivity(
            journey: _journey(),
            title: 'Creek Loop',
            mapImageBytes: Uint8List.fromList([1, 2, 3]),
          ),
          throwsA(isA<StateError>()),
        );

        final snapshot = await firestore
            .collection('activities')
            .doc('journey_journey-1')
            .get();
        expect(snapshot.exists, isFalse);
      },
    );
  });

  group('ActivityFeedCard route slide', () {
    testWidgets('shows the stored map image', (tester) async {
      await _pumpCard(tester, _activity(mapImageUrl: 'https://cdn/map.png'));

      expect(_networkImageUrls(tester), ['https://cdn/map.png']);
    });

    testWidgets('renders the map when the activity has no image', (
      tester,
    ) async {
      await _pumpCard(tester, _activity(mapImageUrl: null));

      expect(_networkImageUrls(tester), isEmpty);
      expect(find.byType(ActivityMapPreview), findsOneWidget);
    });

    testWidgets('keeps a static error state when the image cannot load', (
      tester,
    ) async {
      await _pumpCard(tester, _activity(mapImageUrl: 'https://cdn/map.png'));
      await tester.pumpAndSettle();

      expect(find.text('Map preview unavailable'), findsOneWidget);
      expect(find.byType(ActivityMapPreview), findsNothing);
    });
  });

  group('map image backfill', () {
    testWidgets('arms capture on the owner\'s own un-backfilled card', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _activity(mapImageUrl: null, id: 'journey_backfill-mine'),
        currentUserId: 'user-1',
      );

      expect(_mapPreview(tester).onSnapshotCaptured, isNotNull);
      expect(
        tester.widget<GoogleMap>(find.byType(GoogleMap)).liteModeEnabled,
        isFalse,
      );
    });

    testWidgets('leaves someone else\'s card alone', (tester) async {
      // Only the owner can write the image, so capturing here would be wasted.
      await _pumpCard(
        tester,
        _activity(mapImageUrl: null, id: 'journey_backfill-theirs'),
        currentUserId: 'someone-else',
      );

      expect(_mapPreview(tester).onSnapshotCaptured, isNull);
      expect(
        tester.widget<GoogleMap>(find.byType(GoogleMap)).liteModeEnabled,
        isTrue,
      );
    });

    testWidgets('uploads the capture and records it, once per activity', (
      tester,
    ) async {
      const activityId = 'journey_backfill-once';
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('activities').doc(activityId).set({
        'activityId': activityId,
        'ownerId': 'user-1',
        'title': 'Creek Loop',
      });
      final uploads = <String>[];
      final service = ActivityMutationService(
        firestore: firestore,
        storageService: StorageService(
          activityMediaUploadOverride:
              ({
                required uid,
                required activityId,
                required mediaId,
                required bytes,
                required filename,
                required mediaType,
              }) async {
                uploads.add('$uid/$activityId/$mediaId');
                return ActivityMediaUploadResult(
                  url: 'https://cdn/$mediaId.png',
                  storagePath: 'activity_media/$uid/$activityId/$mediaId.png',
                );
              },
        ),
      );
      final activity = _activity(mapImageUrl: null, id: activityId);

      await _pumpCard(
        tester,
        activity,
        currentUserId: 'user-1',
        mutationService: service,
      );
      _mapPreview(tester).onSnapshotCaptured!(Uint8List.fromList([1, 2, 3]));
      await tester.pumpAndSettle();

      expect(uploads, ['user-1/$activityId/map']);
      final data =
          (await firestore.collection('activities').doc(activityId).get())
              .data()!;
      expect(data['mapImageUrl'], 'https://cdn/map.png');
      expect(
        data['mapImageStoragePath'],
        'activity_media/user-1/$activityId/map.png',
      );

      // Scrolling past it again must not upload a second copy.
      await _pumpCard(
        tester,
        activity,
        currentUserId: 'user-1',
        mutationService: service,
      );

      expect(_mapPreview(tester).onSnapshotCaptured, isNull);
    });

    testWidgets('allows a rebuilt card to retry a failed backfill', (
      tester,
    ) async {
      const activityId = 'journey_backfill-retry';
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('activities').doc(activityId).set({
        'activityId': activityId,
        'ownerId': 'user-1',
        'title': 'Creek Loop',
      });
      var uploadAttempts = 0;
      final service = ActivityMutationService(
        firestore: firestore,
        storageService: StorageService(
          activityMediaUploadOverride:
              ({
                required uid,
                required activityId,
                required mediaId,
                required bytes,
                required filename,
                required mediaType,
              }) async {
                uploadAttempts += 1;
                if (uploadAttempts == 1) {
                  throw StateError('temporary rules failure');
                }
                return ActivityMediaUploadResult(
                  url: 'https://cdn/$mediaId.png',
                  storagePath: 'activity_media/$uid/$activityId/$mediaId.png',
                );
              },
        ),
      );
      final activity = _activity(mapImageUrl: null, id: activityId);

      await _pumpCard(
        tester,
        activity,
        currentUserId: 'user-1',
        mutationService: service,
      );
      _mapPreview(tester).onSnapshotCaptured!(Uint8List.fromList([1]));
      await tester.pumpAndSettle();

      await _pumpCard(
        tester,
        activity,
        currentUserId: 'user-1',
        mutationService: service,
      );
      expect(_mapPreview(tester).onSnapshotCaptured, isNotNull);
      _mapPreview(tester).onSnapshotCaptured!(Uint8List.fromList([2]));
      await tester.pumpAndSettle();

      expect(uploadAttempts, 2);
    });
  });

  group('Activity detail route slide', () {
    testWidgets('uses the persisted fogged image', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ActivityDetailScreen(
            activity: _activity(mapImageUrl: 'https://cdn/detail-map.png'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ActivityMapSnapshotImage), findsOneWidget);
      expect(find.byType(ActivityMapPreview), findsNothing);
      expect(_networkImageUrls(tester), contains('https://cdn/detail-map.png'));
    });
  });
}

List<String> _networkImageUrls(WidgetTester tester) {
  return tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .whereType<NetworkImage>()
      .map((provider) => provider.url)
      .toList();
}

Future<void> _pumpCard(
  WidgetTester tester,
  ActivityFeedItem activity, {
  String? currentUserId,
  ActivityMutationService? mutationService,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ActivityFeedCard.fromItem(
            activity,
            currentUserId: currentUserId,
            mutationService: mutationService,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

ActivityMapPreview _mapPreview(WidgetTester tester) {
  return tester.widget<ActivityMapPreview>(find.byType(ActivityMapPreview));
}

ActivityCreationService _service(
  FakeFirebaseFirestore firestore, {
  required void Function(
    String uid,
    String activityId,
    String mediaId,
    String filename,
  )
  onUpload,
}) {
  return ActivityCreationService(
    firestore: firestore,
    storageService: StorageService(
      activityMediaUploadOverride:
          ({
            required uid,
            required activityId,
            required mediaId,
            required bytes,
            required filename,
            required mediaType,
          }) async {
            onUpload(uid, activityId, mediaId, filename);
            return ActivityMediaUploadResult(
              url: 'https://example.com/$mediaId.png',
              storagePath: 'activity_media/$uid/$activityId/$mediaId.png',
            );
          },
    ),
  );
}

Future<Map<String, dynamic>> _activityData(
  FakeFirebaseFirestore firestore,
) async {
  final snapshot = await firestore
      .collection('activities')
      .doc('journey_journey-1')
      .get();
  return snapshot.data()!;
}

ActivityFeedItem _activity({
  required String? mapImageUrl,
  String id = 'journey_journey-1',
}) {
  return ActivityFeedItem(
    id: id,
    ownerId: 'user-1',
    displayName: 'Traveller',
    timestampLabel: 'August 10, 2026',
    title: 'Creek Loop',
    kind: ActivityFeedKind.journey,
    metrics: const [ActivityFeedMetric(label: 'Time', value: '30m 0s')],
    encodedRoute: _encodedRoute,
    journeyEndTime: DateTime.utc(2026, 8, 10, 7, 30),
    transportMode: 'walk',
    mapImageUrl: mapImageUrl,
  );
}

Journey _journey() {
  return Journey(
    id: 'journey-1',
    userId: 'user-1',
    startTime: DateTime.utc(2026, 8, 10, 7),
    endTime: DateTime.utc(2026, 8, 10, 7, 30),
    startLocation: const JourneyLocation(
      latLng: LatLng(-37.8136, 144.9631),
      displayName: 'Creek entrance',
    ),
    endLocation: const JourneyLocation(
      latLng: LatLng(-37.8115, 144.9631),
      displayName: 'Park lookout',
    ),
    transportMode: TransportMode.walk,
    encodedRoute: _encodedRoute,
    distanceMeters: 3200,
    durationSeconds: 1800,
    title: 'Creek Loop',
    xpEarned: 182,
    tilesUnlocked: 3,
  );
}

final _encodedRoute = PolylineCodec.encode(const [
  LatLng(-37.8136, 144.9631),
  LatLng(-37.8115, 144.9631),
]);
