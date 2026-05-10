/*
 * Author: Nathan Nunes
 * Last Modified: 3/05/2026
 * Description:
 *   Coordinates Firebase Storage uploads and downloads for user profile
 *   images.
 */

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Wraps Firebase Storage operations used by profile image workflows.
class StorageService {
  StorageService({FirebaseStorage? firebaseStorage})
    : _firebaseStorage = firebaseStorage ?? FirebaseStorage.instance;

  final FirebaseStorage _firebaseStorage;

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

  /// Downloads bytes from an existing Firebase Storage download URL.
  Future<Uint8List?> downloadBytesFromUrl(String url) {
    return _firebaseStorage.refFromURL(url).getData();
  }
}
