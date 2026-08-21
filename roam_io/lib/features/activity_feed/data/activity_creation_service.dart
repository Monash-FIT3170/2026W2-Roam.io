/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 19 August 2026
 * Description:
 *   Creates real persisted social activity documents from completed app
 *   events such as Journeys.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../journeys/data/polyline_codec.dart';
import '../../journeys/domain/journey.dart';
import '../../profile/domain/profile_model.dart';
import '../models/activity_feed_item.dart';

/// Creates persisted activity feed documents from real domain sources.
class ActivityCreationService {
  ActivityCreationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _activities =>
      _firestore.collection('activities');

  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      _firestore.collection('public_profiles');

  /// Creates or returns the idempotent social activity for [journey].
  Future<ActivityFeedItem> createJourneyActivity({
    required Journey journey,
    required String title,
    ProfileModel? fallbackProfile,
  }) async {
    if (journey.userId.isEmpty) {
      throw ArgumentError.value(
        journey.userId,
        'userId',
        'User id is required',
      );
    }
    if (journey.id.isEmpty) {
      throw ArgumentError.value(
        journey.id,
        'journey.id',
        'Journey id is required',
      );
    }

    final activityId = 'journey_${journey.id}';
    final activityRef = _activities.doc(activityId);
    final publicProfileRef = _publicProfiles.doc(journey.userId);
    final now = DateTime.now().toUtc();

    final data = await _runCreateJourneyTransaction(
      activityRef: activityRef,
      publicProfileRef: publicProfileRef,
      journey: journey,
      title: title,
      fallbackProfile: fallbackProfile,
      now: now,
    );

    return _activityFromData(activityRef.id, data);
  }

  Future<Map<String, dynamic>> _runCreateJourneyTransaction({
    required DocumentReference<Map<String, dynamic>> activityRef,
    required DocumentReference<Map<String, dynamic>> publicProfileRef,
    required Journey journey,
    required String title,
    required ProfileModel? fallbackProfile,
    required DateTime now,
  }) async {
    try {
      return await _firestore.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        final existing = await transaction.get(activityRef);
        final existingData = existing.data();
        if (existingData != null) return existingData;

        debugPrint(
          '[ActivityCreationService] transaction.get path=${publicProfileRef.path}',
        );
        final publicProfileDoc = await transaction.get(publicProfileRef);
        final identity = _activityIdentity(
          userId: journey.userId,
          publicProfileData: publicProfileDoc.data(),
          fallbackProfile: fallbackProfile,
        );
        final routeBounds = _routeBoundsData(journey.encodedRoute);
        final activity = <String, dynamic>{
          'activityId': activityRef.id,
          'ownerId': journey.userId,
          'profileId': journey.userId,
          'displayName': identity.displayName,
          'username': identity.username,
          'title': _nonEmpty(title) ?? journey.displayTitle,
          'kind': ActivityFeedKind.journey.name,
          'sourceJourneyId': journey.id,
          'encodedRoute': journey.encodedRoute,
          ...?routeBounds == null
              ? null
              : <String, dynamic>{'routeBounds': routeBounds},
          'journeyStartTime': journey.startTime.toUtc().toIso8601String(),
          'journeyEndTime': journey.endTime.toUtc().toIso8601String(),
          'transportMode': journey.transportMode.name,
          'media': const <String>[],
          'showMapPreview': true,
          'createdAt': now.toIso8601String(),
          'metrics': [
            {
              'label': 'Time',
              'value': _formatDuration(journey.durationSeconds),
            },
            {'label': 'Tiles Unlocked', 'value': '${journey.tilesUnlocked}'},
            {'label': 'XP Gained', 'value': '+${journey.xpEarned ?? 0} XP'},
          ],
        };
        final photoUrl = identity.photoUrl;
        if (photoUrl != null && photoUrl.isNotEmpty) {
          activity['photoUrl'] = photoUrl;
        }

        transaction.set(activityRef, activity);
        return activity;
      });
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[ActivityCreationService] create journey activity failed '
        'publicProfilePath=${publicProfileRef.path} '
        'activityPath=${activityRef.path} '
        'journeyId=${journey.id} code=${error.code} '
        'message=${error.message}\n$stackTrace',
      );
      rethrow;
    }
  }

  _ActivityIdentity _activityIdentity({
    required String userId,
    required Map<String, dynamic>? publicProfileData,
    required ProfileModel? fallbackProfile,
  }) {
    final publicDisplayName = _stringValue(publicProfileData?['displayName']);
    final publicUsername = _stringValue(publicProfileData?['username']);
    final publicPhotoUrl = _stringValue(publicProfileData?['photoUrl']);
    final fallbackDisplayName = fallbackProfile?.uid == userId
        ? fallbackProfile?.displayName
        : null;
    final fallbackUsername = fallbackProfile?.uid == userId
        ? fallbackProfile?.username
        : null;
    final fallbackPhotoUrl = fallbackProfile?.uid == userId
        ? fallbackProfile?.photoUrl
        : null;

    final displayName =
        publicDisplayName ??
        _nonEmpty(fallbackDisplayName) ??
        publicUsername ??
        _nonEmpty(fallbackUsername) ??
        'Traveller';
    final username =
        publicUsername ?? _nonEmpty(fallbackUsername) ?? displayName;

    return _ActivityIdentity(
      displayName: displayName,
      username: username,
      photoUrl: publicPhotoUrl ?? _nonEmpty(fallbackPhotoUrl),
    );
  }

  Map<String, dynamic>? _routeBoundsData(String encodedRoute) {
    final points = PolylineCodec.decode(encodedRoute);
    if (points.isEmpty) return null;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    return <String, dynamic>{
      'southwestLatitude': minLat,
      'southwestLongitude': minLng,
      'northeastLatitude': maxLat,
      'northeastLongitude': maxLng,
    };
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final remainingSeconds = duration.inSeconds % 60;

    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${remainingSeconds}s';
    return '${remainingSeconds}s';
  }

  String? _stringValue(Object? value) {
    return value is String ? _nonEmpty(value) : null;
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  ActivityFeedItem _activityFromData(String id, Map<String, dynamic> data) {
    final createdAt = DateTime.tryParse(data['createdAt'] as String? ?? '');
    final routeBounds = _routeBoundsFromData(data['routeBounds']);
    return ActivityFeedItem(
      id: id,
      ownerId: data['ownerId'] as String,
      displayName: data['displayName'] as String,
      username: data['username'] as String?,
      photoUrl: data['photoUrl'] as String?,
      timestampLabel: createdAt == null
          ? 'Recently'
          : '${createdAt.toLocal().day}/${createdAt.toLocal().month}/${createdAt.toLocal().year}',
      title: data['title'] as String,
      kind: ActivityFeedKindParsing.fromWireValue(data['kind'] as String),
      showMapPreview: data['showMapPreview'] as bool? ?? true,
      sourceJourneyId: data['sourceJourneyId'] as String?,
      encodedRoute: data['encodedRoute'] as String?,
      routeBounds: routeBounds,
      journeyStartTime: DateTime.tryParse(
        data['journeyStartTime'] as String? ?? '',
      ),
      journeyEndTime: DateTime.tryParse(
        data['journeyEndTime'] as String? ?? '',
      ),
      transportMode: data['transportMode'] as String?,
      media:
          (data['media'] as List?)?.whereType<String>().toList() ??
          const <String>[],
      metrics: (data['metrics'] as List)
          .whereType<Map>()
          .map(
            (metric) => ActivityFeedMetric(
              label: metric['label'] as String,
              value: metric['value'] as String,
            ),
          )
          .toList(growable: false),
    );
  }

  ActivityRouteBounds? _routeBoundsFromData(Object? value) {
    if (value is! Map) return null;
    final southwestLatitude = (value['southwestLatitude'] as num?)?.toDouble();
    final southwestLongitude = (value['southwestLongitude'] as num?)
        ?.toDouble();
    final northeastLatitude = (value['northeastLatitude'] as num?)?.toDouble();
    final northeastLongitude = (value['northeastLongitude'] as num?)
        ?.toDouble();
    if (southwestLatitude == null ||
        southwestLongitude == null ||
        northeastLatitude == null ||
        northeastLongitude == null) {
      return null;
    }
    return ActivityRouteBounds(
      southwestLatitude: southwestLatitude,
      southwestLongitude: southwestLongitude,
      northeastLatitude: northeastLatitude,
      northeastLongitude: northeastLongitude,
    );
  }
}

class _ActivityIdentity {
  const _ActivityIdentity({
    required this.displayName,
    required this.username,
    this.photoUrl,
  });

  final String displayName;
  final String username;
  final String? photoUrl;
}
