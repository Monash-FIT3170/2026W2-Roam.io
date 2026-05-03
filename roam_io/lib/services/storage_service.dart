import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Thin wrapper around Firebase Storage upload operations.
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
    final contentType = lowerName.endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    final storageRef = _firebaseStorage
        .ref()
        .child('profile_photos')
        .child(uid)
        .child('${DateTime.now().millisecondsSinceEpoch}_${filename.replaceAll(RegExp(r"[^a-zA-Z0-9_.-]"), '_')}');

    await storageRef.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );

    return storageRef.getDownloadURL();
  }
}
