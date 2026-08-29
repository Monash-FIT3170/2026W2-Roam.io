/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 21 August 2026
 * Description:
 *   Coordinates Firebase Storage uploads and downloads for user profile,
 *   visit, custom location, and activity media.
 */

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Upload handler used by [StorageService.uploadVisitMedia] when set (e.g. in tests).
typedef VisitMediaUploadFn =
    Future<String> Function({
      required String uid,
      required int placeId,
      required Uint8List bytes,
      required String filename,
    });

/// Upload handler used by [StorageService.uploadActivityMedia] in tests.
typedef ActivityMediaUploadFn =
    Future<ActivityMediaUploadResult> Function({
      required String uid,
      required String activityId,
      required String mediaId,
      required Uint8List bytes,
      required String filename,
      required String mediaType,
    });

/// Delete handler used by [StorageService.deleteActivityMedia] in tests.
typedef ActivityMediaDeleteFn =
    Future<void> Function({required String storagePath});

/// Result of uploading one structured activity media object.
class ActivityMediaUploadResult {
  const ActivityMediaUploadResult({
    required this.url,
    required this.storagePath,
  });

  final String url;
  final String storagePath;
}

/// Wraps Firebase Storage operations used for profile photos and visit media.
class StorageService {
  StorageService({
    FirebaseStorage? firebaseStorage,
    VisitMediaUploadFn? visitMediaUploadOverride,
    ActivityMediaUploadFn? activityMediaUploadOverride,
    ActivityMediaDeleteFn? activityMediaDeleteOverride,
  }) : _explicitFirebaseStorage = firebaseStorage,
       _visitMediaUploadOverride = visitMediaUploadOverride,
       _activityMediaUploadOverride = activityMediaUploadOverride,
       _activityMediaDeleteOverride = activityMediaDeleteOverride;

  final FirebaseStorage? _explicitFirebaseStorage;
  final VisitMediaUploadFn? _visitMediaUploadOverride;
  final ActivityMediaUploadFn? _activityMediaUploadOverride;
  final ActivityMediaDeleteFn? _activityMediaDeleteOverride;
  FirebaseStorage? _defaultFirebaseStorage;

  FirebaseStorage get _firebaseStorage {
    final explicit = _explicitFirebaseStorage;
    if (explicit != null) {
      return explicit;
    }
    return _defaultFirebaseStorage ??= FirebaseStorage.instance;
  }

  /// Uploads a profile photo to Firebase Storage and returns its download URL.
  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    required String filename,
  }) async {
    final lowerName = filename.toLowerCase();
    final contentType = lowerName.endsWith('.png') ? 'image/png' : 'image/jpeg';

    // Sanitize the original filename before using it in a Storage path.
    final storageRef = _firebaseStorage
        .ref()
        .child('profile_photos')
        .child(uid)
        .child(
          '${DateTime.now().millisecondsSinceEpoch}_${filename.replaceAll(RegExp(r"[^a-zA-Z0-9_.-]"), '_')}',
        );

    await storageRef.putData(bytes, SettableMetadata(contentType: contentType));

    return storageRef.getDownloadURL();
  }

  /// Uploads visit media (photo or video) to Firebase Storage and returns its download URL.
  Future<String> uploadVisitMedia({
    required String uid,
    required int placeId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final override = _visitMediaUploadOverride;
    if (override != null) {
      return override(
        uid: uid,
        placeId: placeId,
        bytes: bytes,
        filename: filename,
      );
    }

    final lowerName = filename.toLowerCase();
    String contentType;
    if (lowerName.endsWith('.png')) {
      contentType = 'image/png';
    } else if (lowerName.endsWith('.mp4')) {
      contentType = 'video/mp4';
    } else if (lowerName.endsWith('.mov')) {
      contentType = 'video/quicktime';
    } else if (lowerName.endsWith('.heic')) {
      contentType = 'image/heic';
    } else {
      contentType = 'image/jpeg';
    }

    // Sanitize the original filename before using it in a Storage path.
    final sanitizedFilename = filename.replaceAll(
      RegExp(r"[^a-zA-Z0-9_.-]"),
      '_',
    );
    final storageRef = _firebaseStorage
        .ref()
        .child('visit_media')
        .child(uid)
        .child(placeId.toString())
        .child('${DateTime.now().millisecondsSinceEpoch}_$sanitizedFilename');

    await storageRef.putData(bytes, SettableMetadata(contentType: contentType));

    return storageRef.getDownloadURL();
  }

  /// Uploads media attached to a journey-created custom location.
  Future<String> uploadCustomLocationMedia({
    required String uid,
    required String locationKey,
    required Uint8List bytes,
    required String filename,
  }) async {
    final lowerName = filename.toLowerCase();
    final contentType = lowerName.endsWith('.mp4')
        ? 'video/mp4'
        : lowerName.endsWith('.mov')
        ? 'video/quicktime'
        : lowerName.endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    final safeFilename = filename.replaceAll(RegExp(r"[^a-zA-Z0-9_.-]"), '_');
    final safeLocationKey = locationKey.replaceAll(
      RegExp(r"[^a-zA-Z0-9_.-]"),
      '_',
    );
    final ref = _firebaseStorage
        .ref()
        .child('custom_location_media')
        .child(uid)
        .child(safeLocationKey)
        .child('${DateTime.now().microsecondsSinceEpoch}_$safeFilename');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  /// Uploads media attached to a social activity and returns URL plus path.
  Future<ActivityMediaUploadResult> uploadActivityMedia({
    required String uid,
    required String activityId,
    required String mediaId,
    required Uint8List bytes,
    required String filename,
    required String mediaType,
  }) async {
    final override = _activityMediaUploadOverride;
    if (override != null) {
      return override(
        uid: uid,
        activityId: activityId,
        mediaId: mediaId,
        bytes: bytes,
        filename: filename,
        mediaType: mediaType,
      );
    }

    final safeFilename = filename.replaceAll(RegExp(r"[^a-zA-Z0-9_.-]"), '_');
    final safeMediaId = mediaId.replaceAll(RegExp(r"[^a-zA-Z0-9_.-]"), '_');
    final ref = _firebaseStorage
        .ref()
        .child('activity_media')
        .child(uid)
        .child(activityId)
        .child('${safeMediaId}_$safeFilename');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: _contentType(filename, mediaType)),
    );
    return ActivityMediaUploadResult(
      url: await ref.getDownloadURL(),
      storagePath: ref.fullPath,
    );
  }

  /// Deletes previously uploaded activity media by Storage full path.
  Future<void> deleteActivityMedia({required String storagePath}) async {
    final override = _activityMediaDeleteOverride;
    if (override != null) {
      await override(storagePath: storagePath);
      return;
    }
    if (storagePath.isEmpty) return;
    await _firebaseStorage.ref(storagePath).delete();
  }

  /// Downloads bytes from an existing Firebase Storage download URL.
  Future<Uint8List?> downloadBytesFromUrl(String url) {
    return _firebaseStorage.refFromURL(url).getData();
  }

  String _contentType(String filename, String mediaType) {
    final lowerName = filename.toLowerCase();
    if (mediaType == 'video') {
      if (lowerName.endsWith('.mov')) return 'video/quicktime';
      return 'video/mp4';
    }
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
