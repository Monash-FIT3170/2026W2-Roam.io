/*
 * Description:
 *   Handles selecting quest proof photos and uploading them to Firebase
 *   Storage. Photos are stored per user and quest so repeated verification
 *   attempts replace the previous proof rather than creating unused files.
 */

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class QuestPhotoSelection {
  const QuestPhotoSelection({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}

class QuestPhotoService {
  QuestPhotoService({
    ImagePicker? imagePicker,
    FirebaseStorage? storage,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _storage = storage ?? FirebaseStorage.instance;

  final ImagePicker _imagePicker;
  final FirebaseStorage _storage;

  /// Opens the device camera and returns the selected photo.
  Future<QuestPhotoSelection?> takePhoto() {
    return _pickPhoto(ImageSource.camera);
  }

  /// Opens the device gallery and returns the selected photo.
  Future<QuestPhotoSelection?> chooseFromGallery() {
    return _pickPhoto(ImageSource.gallery);
  }

  /// Uploads the selected proof photo for a quest and returns its download URL.
  ///
  /// A stable path is used so retrying verification replaces the previous
  /// photo instead of creating orphaned uploads.
  Future<String> uploadQuestProof({
    required String userId,
    required String questId,
    required QuestPhotoSelection photo,
  }) async {
    final reference = _storage
        .ref()
        .child('quest_submissions')
        .child(userId)
        .child(questId)
        .child('proof.jpg');

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'userId': userId,
        'questId': questId,
        'originalFileName': photo.fileName,
      },
    );

    final uploadTask = await reference.putData(
      photo.bytes,
      metadata,
    );

    return uploadTask.ref.getDownloadURL();
  }

  Future<QuestPhotoSelection?> _pickPhoto(
    ImageSource source,
  ) async {
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );

    if (pickedFile == null) {
      return null;
    }

    final bytes = await pickedFile.readAsBytes();

    return QuestPhotoSelection(
      bytes: bytes,
      fileName: pickedFile.name,
    );
  }
}