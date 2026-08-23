/*
 * Description:
 *   Coordinates quest verification using GPS and AI photo evidence.
 *
 *   GPS is checked before AI for combined quests so AI is only called
 *   when the user is actually near the quest location.
 */

import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';

import '../../map/data/geolocator_service.dart';
import 'data/quest.dart';
import 'quest_ai_verification_service.dart';
import 'quest_enums.dart';
import 'quest_submission.dart';
import 'quest_verification.dart';

class QuestVerificationService {
  QuestVerificationService({
    GeoLocatorService? geoLocatorService,
    QuestAiVerificationService? aiVerificationService,
  }) : _geoLocatorService = geoLocatorService ?? GeoLocatorService(),
       _aiVerificationService =
           aiVerificationService ?? QuestAiVerificationService();

  final GeoLocatorService _geoLocatorService;
  final QuestAiVerificationService _aiVerificationService;

  Future<QuestSubmission> createSubmission({required Quest quest}) async {
    if (!quest.requiresGps) {
      return QuestSubmission(questId: quest.id);
    }

    final position = await _geoLocatorService.getCurrentLocation();

    return QuestSubmission(
      questId: quest.id,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<QuestVerificationResult> verify({
    required Quest quest,
    required QuestSubmission submission,
    Uint8List? photoBytes,
    String photoMimeType = 'image/jpeg',
  }) async {
    switch (quest.verificationType) {
      case QuestVerificationType.gps:
        return _verifyGps(quest: quest, submission: submission);

      case QuestVerificationType.photo:
        return _verifyPhoto(
          quest: quest,
          photoBytes: photoBytes,
          photoMimeType: photoMimeType,
        );

      case QuestVerificationType.gpsAndPhoto:
        return _verifyGpsAndPhoto(
          quest: quest,
          submission: submission,
          photoBytes: photoBytes,
          photoMimeType: photoMimeType,
        );

      default:
        return const QuestVerificationResult(
          isVerified: false,
          message: 'This verification method is not supported yet.',
        );
    }
  }

  QuestVerificationResult _verifyGps({
    required Quest quest,
    required QuestSubmission submission,
  }) {
    final questLatitude = quest.latitude;
    final questLongitude = quest.longitude;

    if (questLatitude == null || questLongitude == null) {
      return const QuestVerificationResult(
        isVerified: false,
        message: 'This quest does not have a verification location.',
      );
    }

    final userLatitude = submission.latitude;
    final userLongitude = submission.longitude;

    if (userLatitude == null || userLongitude == null) {
      return const QuestVerificationResult(
        isVerified: false,
        message: 'Your current location could not be determined.',
      );
    }

    final distance = Geolocator.distanceBetween(
      userLatitude,
      userLongitude,
      questLatitude,
      questLongitude,
    );

    final allowedRadius = quest.verificationRadiusMetres ?? 150;

    if (distance > allowedRadius) {
      return QuestVerificationResult(
        isVerified: false,
        message:
            'You are ${distance.round()}m away. '
            'Move within ${allowedRadius.round()}m to verify this quest.',
      );
    }

    return const QuestVerificationResult(
      isVerified: true,
      message: 'Location verified.',
    );
  }

  Future<QuestVerificationResult> _verifyPhoto({
    required Quest quest,
    required Uint8List? photoBytes,
    required String photoMimeType,
  }) async {
    if (photoBytes == null || photoBytes.isEmpty) {
      return const QuestVerificationResult(
        isVerified: false,
        message: 'Add a proof photo before verifying this quest.',
      );
    }

    try {
      final aiResult = await _aiVerificationService.verifyPhoto(
        quest: quest,
        imageBytes: photoBytes,
        mimeType: photoMimeType,
      );

      if (!aiResult.verified) {
        return QuestVerificationResult(
          isVerified: false,
          message: aiResult.feedback,
        );
      }

      return QuestVerificationResult(
        isVerified: true,
        message: aiResult.feedback,
      );
    } on QuestAiVerificationException catch (error) {
      return QuestVerificationResult(isVerified: false, message: error.message);
    } catch (_) {
      return const QuestVerificationResult(
        isVerified: false,
        message: 'Your photo could not be verified right now. Try again.',
      );
    }
  }

  Future<QuestVerificationResult> _verifyGpsAndPhoto({
    required Quest quest,
    required QuestSubmission submission,
    required Uint8List? photoBytes,
    required String photoMimeType,
  }) async {
    final gpsResult = _verifyGps(quest: quest, submission: submission);

    if (!gpsResult.isVerified) {
      return gpsResult;
    }

    return _verifyPhoto(
      quest: quest,
      photoBytes: photoBytes,
      photoMimeType: photoMimeType,
    );
  }
}
