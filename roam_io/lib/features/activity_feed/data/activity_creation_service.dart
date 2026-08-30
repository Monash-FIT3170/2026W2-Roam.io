/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Creates real persisted social activity documents from completed app
 *   events such as Journeys.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../services/storage_service.dart';
import '../../journeys/data/polyline_codec.dart';
import '../../journeys/domain/journey.dart';
import '../../profile/domain/profile_model.dart';
import '../models/activity_feed_item.dart';
import 'activity_map_image.dart';

/// Shared input for publishing social activities from completed app events.
class CreateActivityInput {
  const CreateActivityInput({
    required this.activityId,
    required this.ownerId,
    required this.title,
    required this.kind,
    required this.metrics,
    this.sourceJourneyId,
    this.encodedRoute,
    this.routeBounds,
    this.journeyStartTime,
    this.journeyEndTime,
    this.transportMode,
    this.sourceSidequestId,
    this.sidequestCompletedAt,
    this.showMapPreview = false,
    this.mediaSelections = const <PendingActivityMedia>[],
    this.mapImageBytes,
  });

  final String activityId;
  final String ownerId;
  final String title;
  final ActivityFeedKind kind;
  final List<ActivityFeedMetric> metrics;
  final String? sourceJourneyId;
  final String? encodedRoute;
  final Map<String, dynamic>? routeBounds;
  final DateTime? journeyStartTime;
  final DateTime? journeyEndTime;
  final String? transportMode;
  final String? sourceSidequestId;
  final DateTime? sidequestCompletedAt;
  final bool showMapPreview;
  final List<PendingActivityMedia> mediaSelections;

  /// Map picture captured while reviewing the journey, fog included.
  final Uint8List? mapImageBytes;
}

/// Creates persisted activity feed documents from real domain sources.
class ActivityCreationService {
  ActivityCreationService({
    FirebaseFirestore? firestore,
    StorageService? storageService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storageService = storageService ?? StorageService();

  final FirebaseFirestore _firestore;
  final StorageService _storageService;

  CollectionReference<Map<String, dynamic>> get _activities =>
      _firestore.collection('activities');

  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      _firestore.collection('public_profiles');

  /// Creates or returns the idempotent social activity for [journey].
  Future<ActivityFeedItem> createJourneyActivity({
    required Journey journey,
    required String title,
    ProfileModel? fallbackProfile,
    List<PendingActivityMedia> mediaSelections = const <PendingActivityMedia>[],
    Uint8List? mapImageBytes,
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
    final routeBounds = _routeBoundsData(journey.encodedRoute);
    return _createActivity(
      input: CreateActivityInput(
        activityId: activityId,
        ownerId: journey.userId,
        title: _nonEmpty(title) ?? journey.displayTitle,
        kind: ActivityFeedKind.journey,
        sourceJourneyId: journey.id,
        encodedRoute: journey.encodedRoute,
        routeBounds: routeBounds,
        journeyStartTime: journey.startTime,
        journeyEndTime: journey.endTime,
        transportMode: journey.transportMode.name,
        showMapPreview: true,
        mediaSelections: mediaSelections,
        mapImageBytes: mapImageBytes,
        metrics: [
          ActivityFeedMetric(
            label: 'Time',
            value: _formatDuration(journey.durationSeconds),
          ),
          ActivityFeedMetric(
            label: 'Tiles Unlocked',
            value: '${journey.tilesUnlocked}',
          ),
          ActivityFeedMetric(
            label: 'XP Gained',
            value: '+${journey.xpEarned ?? 0} XP',
          ),
        ],
      ),
      fallbackProfile: fallbackProfile,
    );
  }

  /// Adapter for teammate-owned sidequest completion code.
  ///
  /// Call this only after the sidequest completion has been committed. Required
  /// fields are owner id, deterministic source sidequest id, display title,
  /// metrics, completion timestamp, optional media, and fallback profile.
  Future<ActivityFeedItem> createSidequestActivity({
    required String ownerId,
    required String sourceSidequestId,
    required String title,
    required List<ActivityFeedMetric> metrics,
    required DateTime completedAt,
    ProfileModel? fallbackProfile,
    List<PendingActivityMedia> mediaSelections = const <PendingActivityMedia>[],
  }) {
    if (ownerId.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Owner id is required');
    }
    if (sourceSidequestId.isEmpty) {
      throw ArgumentError.value(
        sourceSidequestId,
        'sourceSidequestId',
        'Sidequest id is required',
      );
    }
    return _createActivity(
      input: CreateActivityInput(
        activityId: 'sidequest_$sourceSidequestId',
        ownerId: ownerId,
        title: _nonEmpty(title) ?? 'Completed Sidequest',
        kind: ActivityFeedKind.sidequest,
        sourceSidequestId: sourceSidequestId,
        sidequestCompletedAt: completedAt,
        mediaSelections: mediaSelections,
        metrics: metrics,
      ),
      fallbackProfile: fallbackProfile,
    );
  }

  Future<ActivityFeedItem> _createActivity({
    required CreateActivityInput input,
    required ProfileModel? fallbackProfile,
  }) async {
    if (input.ownerId.isEmpty) {
      throw ArgumentError.value(
        input.ownerId,
        'ownerId',
        'User id is required',
      );
    }

    final activityRef = _activities.doc(input.activityId);
    final existing = await activityRef.get();
    final existingData = existing.data();
    if (existingData != null) {
      final reconciled = await _reconcileExistingActivityMedia(
        activityRef: activityRef,
        existingData: existingData,
        input: input,
      );
      return _activityFromData(
        activityRef.id,
        await _attachMapImageToExisting(
          activityRef: activityRef,
          existingData: reconciled,
          input: input,
        ),
      );
    }

    final uploadedMedia = <ActivityMediaItem>[];
    ActivityMediaUploadResult? mapImage;
    try {
      uploadedMedia.addAll(
        await _uploadActivityMedia(
          ownerId: input.ownerId,
          activityId: input.activityId,
          selections: input.mediaSelections,
        ),
      );
      // Published before the picture is stored, an activity would fall back to
      // a live map on every feed card, so a failed upload fails the publish.
      mapImage = await _uploadMapImage(
        ownerId: input.ownerId,
        activityId: input.activityId,
        bytes: input.mapImageBytes,
      );
    } catch (_) {
      await _cleanupUploadedMedia(uploadedMedia);
      rethrow;
    }

    final publicProfileRef = _publicProfiles.doc(input.ownerId);
    final now = DateTime.now().toUtc();

    try {
      final data = await _runCreateActivityTransaction(
        activityRef: activityRef,
        publicProfileRef: publicProfileRef,
        input: input,
        media: uploadedMedia,
        mapImage: mapImage,
        fallbackProfile: fallbackProfile,
        now: now,
      );
      if (!_createdWithUploadedMedia(data, uploadedMedia)) {
        await _cleanupUploadedMedia(uploadedMedia);
      }
      if (mapImage != null && data['mapImageUrl'] != mapImage.url) {
        await _cleanupMapImage(mapImage);
      }
      return _activityFromData(activityRef.id, data);
    } catch (_) {
      await _cleanupUploadedMedia(uploadedMedia);
      await _cleanupMapImage(mapImage);
      rethrow;
    }
  }

  /// Uploads the captured map picture, or returns null when none was captured.
  Future<ActivityMediaUploadResult?> _uploadMapImage({
    required String ownerId,
    required String activityId,
    required Uint8List? bytes,
  }) async {
    if (bytes == null || bytes.isEmpty) return null;
    return _storageService.uploadActivityMedia(
      uid: ownerId,
      activityId: activityId,
      mediaId: ActivityMapImage.mediaId,
      bytes: bytes,
      filename: ActivityMapImage.filename,
      mediaType: ActivityMapImage.mediaType,
    );
  }

  Future<void> _cleanupMapImage(ActivityMediaUploadResult? mapImage) async {
    if (mapImage == null) return;
    try {
      await _storageService.deleteActivityMedia(
        storagePath: mapImage.storagePath,
      );
    } catch (error) {
      debugPrint(
        '[ActivityCreationService] orphan map image cleanup failed '
        'path=${mapImage.storagePath} error=$error',
      );
    }
  }

  /// Attaches a fresh capture to an activity that was published without one.
  Future<Map<String, dynamic>> _attachMapImageToExisting({
    required DocumentReference<Map<String, dynamic>> activityRef,
    required Map<String, dynamic> existingData,
    required CreateActivityInput input,
  }) async {
    final bytes = input.mapImageBytes;
    if (bytes == null ||
        bytes.isEmpty ||
        existingData['ownerId'] != input.ownerId ||
        (existingData['mapImageUrl'] as String? ?? '').isNotEmpty) {
      return existingData;
    }

    final mapImage = await _uploadMapImage(
      ownerId: input.ownerId,
      activityId: input.activityId,
      bytes: bytes,
    );
    if (mapImage == null) return existingData;

    try {
      await activityRef.update({
        'mapImageUrl': mapImage.url,
        'mapImageStoragePath': mapImage.storagePath,
      });
    } catch (_) {
      await _cleanupMapImage(mapImage);
      rethrow;
    }
    return Map<String, dynamic>.from(existingData)
      ..['mapImageUrl'] = mapImage.url
      ..['mapImageStoragePath'] = mapImage.storagePath;
  }

  bool _createdWithUploadedMedia(
    Map<String, dynamic> data,
    List<ActivityMediaItem> uploadedMedia,
  ) {
    if (uploadedMedia.isEmpty) return true;
    final stored = data['media'];
    if (stored is! List || stored.length != uploadedMedia.length) return false;
    final uploadedIds = uploadedMedia.map((item) => item.id).toSet();
    final storedIds = stored
        .whereType<Map>()
        .map((item) => item['id'])
        .whereType<String>()
        .toSet();
    return storedIds.containsAll(uploadedIds);
  }

  Future<Map<String, dynamic>> _reconcileExistingActivityMedia({
    required DocumentReference<Map<String, dynamic>> activityRef,
    required Map<String, dynamic> existingData,
    required CreateActivityInput input,
  }) async {
    if (input.mediaSelections.isEmpty ||
        existingData['ownerId'] != input.ownerId) {
      return existingData;
    }

    final existingMedia = _mediaFromData(existingData['media']);
    if (existingMedia.isNotEmpty || existingMedia.length >= 3) {
      return existingData;
    }

    final uploadedMedia = <ActivityMediaItem>[];
    try {
      uploadedMedia.addAll(
        await _uploadActivityMedia(
          ownerId: input.ownerId,
          activityId: input.activityId,
          selections: input.mediaSelections,
          startIndex: existingMedia.length,
        ),
      );
    } catch (_) {
      await _cleanupUploadedMedia(uploadedMedia);
      rethrow;
    }

    if (uploadedMedia.isEmpty) return existingData;

    try {
      final reconciled = await _firestore.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        final snapshot = await transaction.get(activityRef);
        final latestData = snapshot.data();
        if (latestData == null || latestData['ownerId'] != input.ownerId) {
          return existingData;
        }
        final latestMedia = _mediaFromData(latestData['media']);
        if (latestMedia.isNotEmpty || latestMedia.length >= 3) {
          return latestData;
        }
        final combined = [
          ...latestMedia,
          ...uploadedMedia,
        ].take(3).toList(growable: false);
        final normalized = <ActivityMediaItem>[
          for (var index = 0; index < combined.length; index += 1)
            ActivityMediaItem(
              id: combined[index].id,
              type: combined[index].type,
              url: combined[index].url,
              storagePath: combined[index].storagePath,
              order: index,
              createdAt: combined[index].createdAt,
              thumbnailUrl: combined[index].thumbnailUrl,
            ),
        ];
        final nextData = Map<String, dynamic>.from(latestData)
          ..['media'] = normalized
              .map((item) => item.toMap())
              .toList(growable: false);
        transaction.update(activityRef, {'media': nextData['media']});
        return nextData;
      });
      if (!_createdWithUploadedMedia(reconciled, uploadedMedia)) {
        await _cleanupUploadedMedia(uploadedMedia);
      }
      return reconciled;
    } catch (_) {
      await _cleanupUploadedMedia(uploadedMedia);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _runCreateActivityTransaction({
    required DocumentReference<Map<String, dynamic>> activityRef,
    required DocumentReference<Map<String, dynamic>> publicProfileRef,
    required CreateActivityInput input,
    required List<ActivityMediaItem> media,
    required ActivityMediaUploadResult? mapImage,
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
          userId: input.ownerId,
          publicProfileData: publicProfileDoc.data(),
          fallbackProfile: fallbackProfile,
        );
        final activity = <String, dynamic>{
          'activityId': activityRef.id,
          'ownerId': input.ownerId,
          'profileId': input.ownerId,
          'displayName': identity.displayName,
          'username': identity.username,
          'title': input.title,
          'kind': input.kind.name,
          ...?input.sourceJourneyId == null
              ? null
              : <String, dynamic>{'sourceJourneyId': input.sourceJourneyId},
          ...?input.encodedRoute == null
              ? null
              : <String, dynamic>{'encodedRoute': input.encodedRoute},
          ...?input.routeBounds == null
              ? null
              : <String, dynamic>{'routeBounds': input.routeBounds},
          ...?input.journeyStartTime == null
              ? null
              : <String, dynamic>{
                  'journeyStartTime': input.journeyStartTime!
                      .toUtc()
                      .toIso8601String(),
                },
          ...?input.journeyEndTime == null
              ? null
              : <String, dynamic>{
                  'journeyEndTime': input.journeyEndTime!
                      .toUtc()
                      .toIso8601String(),
                },
          ...?input.transportMode == null
              ? null
              : <String, dynamic>{'transportMode': input.transportMode},
          ...?input.sourceSidequestId == null
              ? null
              : <String, dynamic>{'sourceSidequestId': input.sourceSidequestId},
          ...?input.sidequestCompletedAt == null
              ? null
              : <String, dynamic>{
                  'sidequestCompletedAt': input.sidequestCompletedAt!
                      .toUtc()
                      .toIso8601String(),
                },
          ...?mapImage == null
              ? null
              : <String, dynamic>{
                  'mapImageUrl': mapImage.url,
                  'mapImageStoragePath': mapImage.storagePath,
                },
          'media': media.map((item) => item.toMap()).toList(growable: false),
          'showMapPreview': input.showMapPreview,
          'createdAt': now.toIso8601String(),
          'metrics': input.metrics
              .map((metric) => {'label': metric.label, 'value': metric.value})
              .toList(growable: false),
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
        'activityId=${input.activityId} code=${error.code} '
        'message=${error.message}\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<List<ActivityMediaItem>> _uploadActivityMedia({
    required String ownerId,
    required String activityId,
    required List<PendingActivityMedia> selections,
    int startIndex = 0,
  }) async {
    final remainingSlots = 3 - startIndex;
    if (remainingSlots <= 0) return const <ActivityMediaItem>[];
    final limited = selections.take(remainingSlots).toList(growable: false);
    final uploaded = <ActivityMediaItem>[];
    final now = DateTime.now().toUtc();
    try {
      for (var index = 0; index < limited.length; index += 1) {
        final selection = limited[index];
        final order = startIndex + index;
        final mediaId = 'media_${order}_${now.microsecondsSinceEpoch}';
        final bytes = await selection.file.readAsBytes();
        final result = await _storageService.uploadActivityMedia(
          uid: ownerId,
          activityId: activityId,
          mediaId: mediaId,
          bytes: bytes,
          filename: selection.file.name,
          mediaType: selection.type.name,
        );
        uploaded.add(
          ActivityMediaItem(
            id: mediaId,
            type: selection.type,
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
          '[ActivityCreationService] orphan media cleanup failed '
          'path=${item.storagePath} error=$error',
        );
      }
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
      createdAt: createdAt,
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
      mapImageUrl: data['mapImageUrl'] as String?,
      mapImageStoragePath: data['mapImageStoragePath'] as String?,
      media: _mediaFromData(data['media']),
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
      final parsedCreatedAt = createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.tryParse(createdAt as String? ?? '');
      if (parsedCreatedAt == null) continue;
      media.add(
        ActivityMediaItem(
          id: id,
          type: ActivityMediaType.fromWireValue(type),
          url: url,
          storagePath: storagePath,
          order: order.toInt(),
          createdAt: parsedCreatedAt,
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
