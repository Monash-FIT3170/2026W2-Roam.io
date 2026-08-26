/*
 * Description:
 *   Sends quest photo evidence to the Firebase callable AI function and
 *   converts the response into a QuestPhotoVerificationResult.
 */

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import 'data/quest.dart';
import 'quest_photo_verification_result.dart';

class QuestAiVerificationService {
  QuestAiVerificationService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<QuestPhotoVerificationResult> verifyPhoto({
    required Quest quest,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final prompt = quest.verificationPrompt?.trim();

    if (prompt == null || prompt.isEmpty) {
      throw const QuestAiVerificationException(
        'Photo verification is not configured for this quest yet.',
      );
    }

    if (imageBytes.isEmpty) {
      throw const QuestAiVerificationException('The selected photo is empty.');
    }

    try {
      final callable = _functions.httpsCallable(
        'verifyQuestPhoto',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final response = await callable
          .call<Map<String, dynamic>>(<String, dynamic>{
            'questTitle': quest.title,
            'questDescription': quest.description,
            'verificationPrompt': prompt,
            'imageBase64': base64Encode(imageBytes),
            'mimeType': mimeType,
          });

      return QuestPhotoVerificationResult.fromMap(
        Map<String, dynamic>.from(response.data),
      );
    } on FirebaseFunctionsException catch (error) {
      throw QuestAiVerificationException(
        error.message ?? 'Unable to verify the quest photo.',
      );
    } on QuestAiVerificationException {
      rethrow;
    } catch (error) {
      throw const QuestAiVerificationException(
        'Unable to verify the quest photo right now.',
      );
    }
  }
}

class QuestAiVerificationException implements Exception {
  const QuestAiVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}
