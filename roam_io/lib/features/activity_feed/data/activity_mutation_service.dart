/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 21 August 2026
 * Description:
 *   Owner-only editable activity mutations for title/media updates, deletion,
 *   and profile media gallery streams.
 */

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../services/storage_service.dart';
import '../models/activity_feed_item.dart';
import 'activity_map_image.dart';

/// Gallery item derived from an activity's structured media.
class ProfileActivityMediaEntry {
  const ProfileActivityMediaEntry({
    required this.activity,
    required this.media,
  });

  final ActivityFeedItem activity;
  final ActivityMediaItem media;
}

/// Mutates owner-editable activity fields only.
class ActivityMutationService {
  ActivityMutationService({
    FirebaseFirestore? firestore,
    StorageService? storageService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storageService = storageService ?? StorageService();

  final FirebaseFirestore _firestore;
  final StorageService _storageService;

  CollectionReference<Map<String, dynamic>> get _activities =>
      _firestore.collection('activities');

  Future<void> updateActivityEditableFields({
    required ActivityFeedItem activity,
    required String title,
    required List<ActivityMediaItem> media,
    List<PendingActivityMedia> pendingMedia = const <PendingActivityMedia>[],
  }) async {
    final normalizedTitle = title.trim().isEmpty
        ? activity.title
        : title.trim();
    final uploadedMedia = <ActivityMediaItem>[];
    try {
      uploadedMedia.addAll(
        await _uploadPendingMedia(
          activity: activity,
          pendingMedia: pendingMedia,
          startIndex: media.length,
        ),
      );
    } catch (_) {
      await _cleanupUploadedMedia(uploadedMedia);
      rethrow;
    }

    final combined = [...media, ...uploadedMedia].take(3).toList();
    final normalizedMedia = <ActivityMediaItem>[
      for (var i = 0; i < combined.length; i += 1)
        ActivityMediaItem(
          id: combined[i].id,
          type: combined[i].type,
          url: combined[i].url,
          storagePath: combined[i].storagePath,
          order: i,
          createdAt: combined[i].createdAt,
          thumbnailUrl: combined[i].thumbnailUrl,
        ),
    ];
    try {
      await _activities.doc(activity.id).update({
        'title': normalizedTitle,
        'media': normalizedMedia
            .map((item) => item.toMap())
            .toList(growable: false),
      });
    } catch (_) {
      await _cleanupUploadedMedia(uploadedMedia);
      rethrow;
    }

    final retainedPaths = normalizedMedia
        .map((item) => item.storagePath)
        .where((path) => path.isNotEmpty)
        .toSet();
    for (final removed in activity.media) {
      if (removed.storagePath.isEmpty ||
          retainedPaths.contains(removed.storagePath)) {
        continue;
      }
      unawaited(
        _storageService
            .deleteActivityMedia(storagePath: removed.storagePath)
            .catchError((Object error) {
              debugPrint(
                '[ActivityMutationService] removed media cleanup failed '
                'path=${removed.storagePath} error=$error',
              );
            }),
      );
    }
  }

  /// Stores a map picture captured for an activity that was saved without one.
  ///
  /// Only the owner can write here, so callers must check that first.
  Future<void> attachMapImage({
    required String activityId,
    required String ownerId,
    required Uint8List bytes,
  }) async {
    final result = await _storageService.uploadActivityMedia(
      uid: ownerId,
      activityId: activityId,
      mediaId: ActivityMapImage.mediaId,
      bytes: bytes,
      filename: ActivityMapImage.filename,
      mediaType: ActivityMapImage.mediaType,
    );
    try {
      await _activities.doc(activityId).update({
        'mapImageUrl': result.url,
        'mapImageStoragePath': result.storagePath,
      });
    } catch (_) {
      try {
        await _storageService.deleteActivityMedia(
          storagePath: result.storagePath,
        );
      } catch (error) {
        debugPrint(
          '[ActivityMutationService] orphan map image cleanup failed '
          'path=${result.storagePath} error=$error',
        );
      }
      rethrow;
    }
  }

  Future<List<ActivityMediaItem>> _uploadPendingMedia({
    required ActivityFeedItem activity,
    required List<PendingActivityMedia> pendingMedia,
    required int startIndex,
  }) async {
    final uploaded = <ActivityMediaItem>[];
    final remainingSlots = 3 - startIndex;
    if (remainingSlots <= 0) return uploaded;
    final now = DateTime.now().toUtc();
    try {
      for (
        var index = 0;
        index < pendingMedia.length && index < remainingSlots;
        index += 1
      ) {
        final pending = pendingMedia[index];
        final order = startIndex + index;
        final mediaId = 'media_${order}_${now.microsecondsSinceEpoch}';
        final result = await _storageService.uploadActivityMedia(
          uid: activity.ownerId,
          activityId: activity.id,
          mediaId: mediaId,
          bytes: await pending.file.readAsBytes(),
          filename: pending.file.name,
          mediaType: pending.type.name,
        );
        uploaded.add(
          ActivityMediaItem(
            id: mediaId,
            type: pending.type,
            url: result.url,
            storagePath: result.storagePath,
            order: order,
            createdAt: now,
          ),
        );
      }
    } catch (_) {
      await _cleanupUploadedMedia(uploaded);
      rethrow;
    }
    return uploaded;
  }

  Future<void> _cleanupUploadedMedia(List<ActivityMediaItem> media) async {
    for (final item in media) {
      try {
        await _storageService.deleteActivityMedia(
          storagePath: item.storagePath,
        );
      } catch (error) {
        debugPrint(
          '[ActivityMutationService] uploaded media cleanup failed '
          'path=${item.storagePath} error=$error',
        );
      }
    }
  }

  Future<void> deleteActivity(ActivityFeedItem activity) async {
    final storagePaths = <String>[
      for (final media in activity.media) media.storagePath,
      activity.mapImageStoragePath ?? '',
    ];
    for (final storagePath in storagePaths) {
      if (storagePath.isEmpty) continue;
      try {
        await _storageService.deleteActivityMedia(storagePath: storagePath);
      } catch (error) {
        debugPrint(
          '[ActivityMutationService] activity media delete failed '
          'path=$storagePath error=$error',
        );
      }
    }

    await _deleteKnownSubcollections(activity.id);
    await _activities.doc(activity.id).delete();
  }

  Stream<List<ProfileActivityMediaEntry>> watchProfileActivityMedia(
    String profileId,
  ) {
    if (profileId.isEmpty) {
      return Stream<List<ProfileActivityMediaEntry>>.value(
        const <ProfileActivityMediaEntry>[],
      );
    }
    return _activities
        .where('ownerId', isEqualTo: profileId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final entries = <ProfileActivityMediaEntry>[];
          for (final doc in snapshot.docs) {
            final activity = _tryActivityFromDoc(doc.id, doc.data());
            if (activity == null) continue;
            for (final media in activity.media) {
              entries.add(
                ProfileActivityMediaEntry(activity: activity, media: media),
              );
            }
          }
          return entries;
        });
  }

  Future<void> _deleteKnownSubcollections(String activityId) async {
    final activityRef = _activities.doc(activityId);
    await _deleteCollection(activityRef.collection('kudos'));
    final comments = await activityRef.collection('comments').get();
    for (final comment in comments.docs) {
      await _deleteCollection(comment.reference.collection('likes'));
    }
    await _deleteCollection(activityRef.collection('comments'));
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const batchSize = 450;
    while (true) {
      final snapshot = await collection.limit(batchSize).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < batchSize) return;
    }
  }

  ActivityFeedItem? _tryActivityFromDoc(String id, Map<String, dynamic> data) {
    try {
      final createdAt = _dateFromData(data['createdAt']);
      if (createdAt == null) return null;
      return ActivityFeedItem(
        id: id,
        ownerId: data['ownerId'] as String,
        displayName: data['displayName'] as String,
        username: data['username'] as String?,
        photoUrl: data['photoUrl'] as String?,
        timestampLabel:
            '${createdAt.toLocal().day}/${createdAt.toLocal().month}/${createdAt.toLocal().year}',
        createdAt: createdAt,
        title: data['title'] as String,
        kind: ActivityFeedKindParsing.fromWireValue(data['kind'] as String),
        metrics: (data['metrics'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (metric) => ActivityFeedMetric(
                label: metric['label'] as String,
                value: metric['value'] as String,
              ),
            )
            .toList(growable: false),
        showMapPreview: data['showMapPreview'] as bool? ?? true,
        sourceJourneyId: data['sourceJourneyId'] as String?,
        encodedRoute: data['encodedRoute'] as String?,
        routeBounds: _routeBoundsFromData(data['routeBounds']),
        journeyStartTime: DateTime.tryParse(
          data['journeyStartTime'] as String? ?? '',
        ),
        journeyEndTime: DateTime.tryParse(
          data['journeyEndTime'] as String? ?? '',
        ),
        transportMode: data['transportMode'] as String?,
        mapImageUrl: data['mapImageUrl'] as String?,
        mapImageStoragePath: data['mapImageStoragePath'] as String?,
        media: _mediaFromData(data['media']),
      );
    } catch (_) {
      return null;
    }
  }

  List<ActivityMediaItem> _mediaFromData(Object? value) {
    if (value is! List) return const <ActivityMediaItem>[];
    final media = <ActivityMediaItem>[];
    for (var index = 0; index < value.length; index += 1) {
      final item = value[index];
      if (item is String) {
        if (item.isNotEmpty) {
          media.add(ActivityMediaItem.legacyUrl(item, index));
        }
        continue;
      }
      if (item is! Map) continue;
      final id = item['id'];
      final type = item['type'];
      final url = item['url'];
      final storagePath = item['storagePath'];
      final order = item['order'];
      final createdAt = item['createdAt'];
      if (id is! String ||
          type is! String ||
          url is! String ||
          storagePath is! String ||
          order is! num) {
        continue;
      }
      media.add(
        ActivityMediaItem(
          id: id,
          type: ActivityMediaType.fromWireValue(type),
          url: url,
          storagePath: storagePath,
          order: order.toInt(),
          createdAt:
              _dateFromData(createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          thumbnailUrl: item['thumbnailUrl'] as String?,
        ),
      );
    }
    media.sort((a, b) => a.order.compareTo(b.order));
    return media;
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

  DateTime? _dateFromData(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
