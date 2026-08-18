/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Temporary real Firestore activity creator used by the Home test button.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../profile/domain/profile_model.dart';
import '../models/activity_feed_item.dart';

/// Creates persisted activity feed documents with a per-user test sequence.
class ActivityCreationService {
  ActivityCreationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _activities =>
      _firestore.collection('activities');

  CollectionReference<Map<String, dynamic>> get _counters =>
      _firestore.collection('activity_counters');

  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      _firestore.collection('public_profiles');

  Future<ActivityFeedItem> createTestActivityForUser({
    required String userId,
    ProfileModel? fallbackProfile,
  }) async {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User id is required');
    }

    final activityRef = _activities.doc();
    final counterRef = _counters.doc(userId);
    final publicProfileRef = _publicProfiles.doc(userId);
    final now = DateTime.now().toUtc();

    final data = await _runCreateTransaction(
      activityRef: activityRef,
      counterRef: counterRef,
      publicProfileRef: publicProfileRef,
      userId: userId,
      fallbackProfile: fallbackProfile,
      now: now,
    );

    return _activityFromData(activityRef.id, data);
  }

  Future<Map<String, dynamic>> _runCreateTransaction({
    required DocumentReference<Map<String, dynamic>> activityRef,
    required DocumentReference<Map<String, dynamic>> counterRef,
    required DocumentReference<Map<String, dynamic>> publicProfileRef,
    required String userId,
    required ProfileModel? fallbackProfile,
    required DateTime now,
  }) async {
    try {
      return await _firestore.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        debugPrint(
          '[ActivityCreationService] transaction.get path=${publicProfileRef.path}',
        );
        final publicProfileDoc = await transaction.get(publicProfileRef);
        debugPrint(
          '[ActivityCreationService] transaction.get path=${counterRef.path}',
        );
        final counterDoc = await transaction.get(counterRef);

        final identity = _activityIdentity(
          userId: userId,
          publicProfileData: publicProfileDoc.data(),
          fallbackProfile: fallbackProfile,
        );
        final previousNumber =
            (counterDoc.data()?['lastTestActivityNumber'] as num?)?.toInt() ??
            0;
        final nextNumber = previousNumber + 1;
        final createdAt = now.toIso8601String();
        final titlePrefix = identity.titlePrefix;
        final activity = <String, dynamic>{
          'activityId': activityRef.id,
          'ownerId': userId,
          'profileId': userId,
          'displayName': identity.displayName,
          'username': identity.username,
          'title': '$titlePrefix Activity $nextNumber',
          'kind': 'exploration',
          'showMapPreview': true,
          'createdAt': createdAt,
          'metrics': const [
            {'label': 'Time', 'value': '12m 34s'},
            {'label': 'Locations Visited', 'value': '3'},
            {'label': 'XP Gained', 'value': '+120 XP'},
          ],
        };
        final photoUrl = identity.photoUrl;
        if (photoUrl != null && photoUrl.isNotEmpty) {
          activity['photoUrl'] = photoUrl;
        }

        transaction.set(activityRef, activity);
        transaction.set(counterRef, <String, dynamic>{
          'ownerId': userId,
          'lastTestActivityNumber': nextNumber,
          'createdAt': counterDoc.exists
              ? (counterDoc.data()?['createdAt'] as String? ?? createdAt)
              : createdAt,
          'updatedAt': createdAt,
        });
        return activity;
      });
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[ActivityCreationService] create transaction failed '
        'publicProfilePath=${publicProfileRef.path} '
        'counterPath=${counterRef.path} activityPath=${activityRef.path} '
        'code=${error.code} message=${error.message}\n$stackTrace',
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
    final titlePrefix =
        publicDisplayName ??
        _nonEmpty(fallbackDisplayName) ??
        publicUsername ??
        _nonEmpty(fallbackUsername) ??
        'Test';

    return _ActivityIdentity(
      displayName: displayName,
      username: username,
      photoUrl: publicPhotoUrl ?? _nonEmpty(fallbackPhotoUrl),
      titlePrefix: titlePrefix,
    );
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
}

class _ActivityIdentity {
  const _ActivityIdentity({
    required this.displayName,
    required this.username,
    required this.titlePrefix,
    this.photoUrl,
  });

  final String displayName;
  final String username;
  final String? photoUrl;
  final String titlePrefix;
}
