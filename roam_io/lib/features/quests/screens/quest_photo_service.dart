/*
 * Description:
 *   Handles selecting side-quest proof photos and storing successfully
 *   verified proof images in Firebase Storage.
 */

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class QuestPhotoSelection {
  const QuestPhotoSelection({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;

  String get mimeType {
    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerName.endsWith('.heic') || lowerName.endsWith('.heif')) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }
}

class QuestPhotoService {
  QuestPhotoService({ImagePicker? imagePicker, FirebaseStorage? storage})
    : _imagePicker = imagePicker ?? ImagePicker(),
      _storage = storage ?? FirebaseStorage.instance;

  final ImagePicker _imagePicker;
  final FirebaseStorage _storage;

  Future<QuestPhotoSelection?> takePhoto() {
    return _pickPhoto(ImageSource.camera);
  }

  Future<QuestPhotoSelection?> chooseFromGallery() {
    return _pickPhoto(ImageSource.gallery);
  }

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
      contentType: photo.mimeType,
      customMetadata: <String, String>{
        'userId': userId,
        'questId': questId,
        'originalFileName': photo.fileName,
      },
    );

    final snapshot = await reference.putData(photo.bytes, metadata);

    return snapshot.ref.getDownloadURL();
  }

  Future<QuestPhotoSelection?> _pickPhoto(ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (file == null) {
      return null;
    }

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw StateError('The selected image contains no data.');
    }

    return QuestPhotoSelection(bytes: bytes, fileName: file.name);
  }
}
