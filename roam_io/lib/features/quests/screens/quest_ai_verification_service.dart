import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:roam_io/features/quests/screens/quest_photo_verification_result.dart';

import 'data/quest.dart';


class QuestAiVerificationService {
  QuestAiVerificationService({
    FirebaseFunctions? functions,
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<QuestPhotoVerificationResult> verifyPhoto({
    required Quest quest,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final verificationPrompt = quest.verificationPrompt?.trim();

    if (verificationPrompt == null || verificationPrompt.isEmpty) {
      throw StateError(
        'Quest ${quest.id} does not have a verification prompt.',
      );
    }

    if (imageBytes.isEmpty) {
      throw ArgumentError('Quest verification image is empty.');
    }

    try {
      final callable = _functions.httpsCallable(
        'verifyQuestPhoto',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );

      final response = await callable.call<Map<String, dynamic>>({
        'questTitle': quest.title,
        'questDescription': quest.description,
        'verificationPrompt': verificationPrompt,
        'imageBase64': base64Encode(imageBytes),
        'mimeType': mimeType,
      });

      final data = Map<String, dynamic>.from(response.data);

      return QuestPhotoVerificationResult.fromMap(data);
    } on FirebaseFunctionsException catch (error) {
      throw QuestAiVerificationException(
        error.message ?? 'Unable to verify quest photo.',
      );
    } catch (error) {
      if (error is QuestAiVerificationException) {
        rethrow;
      }

      throw QuestAiVerificationException(
        'Unable to verify quest photo.',
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