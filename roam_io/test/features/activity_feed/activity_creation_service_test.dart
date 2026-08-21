/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 19 August 2026
 * Description:
 *   Service tests for creating real persisted Journey activities and reading
 *   activity feed documents.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/activity_feed/data/activity_creation_service.dart';
import 'package:roam_io/features/activity_feed/data/activity_feed_service.dart';
import 'package:roam_io/features/activity_feed/models/activity_feed_item.dart';
import 'package:roam_io/features/journeys/data/polyline_codec.dart';
import 'package:roam_io/features/journeys/domain/journey.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

void main() {
  test(
    'creates an idempotent Journey activity with real Journey data',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('public_profiles').doc('user-1').set({
        'uid': 'user-1',
        'username': 'traveller',
        'usernameSearch': 'traveller',
        'displayName': 'Traveller',
        'displayNameSearch': 'traveller',
        'photoUrl': 'https://example.com/avatar.png',
        'createdAt': DateTime(2026, 8, 10).toIso8601String(),
        'updatedAt': DateTime(2026, 8, 10).toIso8601String(),
      });
      final service = ActivityCreationService(firestore: firestore);
      final journey = _journey();

      final first = await service.createJourneyActivity(
        journey: journey,
        title: 'Creek Loop',
      );
      final second = await service.createJourneyActivity(
        journey: journey,
        title: 'Updated Title',
      );

      expect(first.id, 'journey_journey-1');
      expect(second.id, first.id);
      expect(second.title, 'Creek Loop');
      expect(first.kind, ActivityFeedKind.journey);
      expect(first.sourceJourneyId, 'journey-1');
      expect(first.encodedRoute, journey.encodedRoute);
      expect(first.routeBounds?.southwestLatitude, closeTo(-37.8136, 0.00001));
      expect(first.routeBounds?.northeastLatitude, closeTo(-37.8115, 0.00001));
      expect(first.journeyStartTime, journey.startTime.toUtc());
      expect(first.journeyEndTime, journey.endTime.toUtc());
      expect(first.transportMode, 'walk');
      expect(first.media, isEmpty);

      final docs = await firestore.collection('activities').get();
      expect(docs.docs, hasLength(1));
      final data = docs.docs.single.data();
      expect(data['activityId'], 'journey_journey-1');
      expect(data['ownerId'], 'user-1');
      expect(data['profileId'], 'user-1');
      expect(data['displayName'], 'Traveller');
      expect(data['username'], 'traveller');
      expect(data['photoUrl'], 'https://example.com/avatar.png');
      expect(data['title'], 'Creek Loop');
      expect(data['kind'], 'journey');
      expect(data['sourceJourneyId'], 'journey-1');
      expect(data['encodedRoute'], journey.encodedRoute);
      expect(
        data['journeyStartTime'],
        journey.startTime.toUtc().toIso8601String(),
      );
      expect(data['journeyEndTime'], journey.endTime.toUtc().toIso8601String());
      expect(data['transportMode'], 'walk');
      expect(data['media'], isEmpty);
      expect(data['metrics'], [
        {'label': 'Time', 'value': '30m 0s'},
        {'label': 'Tiles Unlocked', 'value': '3'},
        {'label': 'XP Gained', 'value': '+182 XP'},
      ]);
      expect(data.containsKey('kudos'), isFalse);
      expect(data.containsKey('kudosCount'), isFalse);
      expect(data.containsKey('commentCount'), isFalse);
    },
  );

  test(
    'falls back to the signed-in profile when public profile is missing',
    () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActivityCreationService(firestore: firestore);

      final activity = await service.createJourneyActivity(
        journey: _journey(),
        title: 'Fallback Journey',
        fallbackProfile: ProfileModel(
          uid: 'user-1',
          username: 'fallback_user',
          displayName: 'Fallback User',
          email: 'fallback@example.com',
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
      );

      expect(activity.title, 'Fallback Journey');
      final doc = await firestore
          .collection('activities')
          .doc(activity.id)
          .get();
      expect(doc.data()?['displayName'], 'Fallback User');
      expect(doc.data()?['username'], 'fallback_user');
    },
  );

  test(
    'activity reader skips one malformed document without dropping valid siblings',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('activities').doc('valid-activity').set({
        'activityId': 'valid-activity',
        'ownerId': 'user-1',
        'profileId': 'user-1',
        'displayName': 'Traveller',
        'username': 'traveller',
        'title': 'Traveller Activity 1',
        'kind': 'journey',
        'sourceJourneyId': 'journey-1',
        'encodedRoute': _encodedRoute,
        'journeyStartTime': DateTime.utc(2026, 8, 10).toIso8601String(),
        'journeyEndTime': DateTime.utc(2026, 8, 10, 0, 30).toIso8601String(),
        'transportMode': 'walk',
        'media': const <String>[],
        'showMapPreview': true,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 10)),
        'metrics': [
          {'label': 'XP Gained', 'value': '+120 XP'},
        ],
      });
      await firestore.collection('activities').doc('malformed-activity').set({
        'activityId': 'malformed-activity',
        'ownerId': 'user-1',
        'profileId': 'user-1',
        'displayName': 'Traveller',
        'username': 'traveller',
        'title': 42,
        'kind': 'exploration',
        'showMapPreview': true,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 9)),
        'metrics': [
          {'label': 'XP Gained', 'value': '+10 XP'},
        ],
      });
      final service = ActivityFeedService(firestore: firestore);

      final activities = await service.watchActivitiesOwnedBy('user-1').first;

      expect(activities, hasLength(1));
      expect(activities.single.id, 'valid-activity');
      expect(activities.single.title, 'Traveller Activity 1');
      expect(activities.single.sourceJourneyId, 'journey-1');
      expect(activities.single.media, isEmpty);
    },
  );
}

final _encodedRoute = PolylineCodec.encode(const [
  LatLng(-37.8136, 144.9631),
  LatLng(-37.8125, 144.9631),
  LatLng(-37.8115, 144.9631),
]);

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
    journeyXpEarned: 32,
    tilesUnlocked: 3,
    tileXpEarned: 150,
  );
}
