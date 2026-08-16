/*
 * Description:
 *   Performs simple quest verification using location and photo evidence.
 */

import 'package:geolocator/geolocator.dart';
import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';
import 'package:roam_io/features/quests/screens/quest_submission.dart';
import 'package:roam_io/features/quests/screens/quest_verification.dart';

import '../../map/data/geolocator_service.dart';


class QuestVerificationService {
  QuestVerificationService({
    GeoLocatorService? geoLocatorService,
  }) : _geoLocatorService = geoLocatorService ?? GeoLocatorService();

  final GeoLocatorService _geoLocatorService;

  Future<QuestVerificationResult> verify({
    required Quest quest,
    required QuestSubmission submission,
  }) async {
    return switch (quest.verificationType) {
      QuestVerificationType.gps => _verifyGps(
          quest: quest,
          submission: submission,
        ),

      QuestVerificationType.photo => _verifyPhoto(
          submission: submission,
        ),

      QuestVerificationType.gpsAndPhoto => _verifyGpsAndPhoto(
          quest: quest,
          submission: submission,
        ),

      _ => const QuestVerificationResult(
          isVerified: false,
          message: 'This quest verification method is not supported yet.',
        ),
    };
  }

  Future<QuestSubmission> createSubmissionFromCurrentLocation({
    required Quest quest,
    String? photoUrl,
  }) async {
    final position = await _geoLocatorService.getCurrentLocation();

    return QuestSubmission(
      questId: quest.id,
      latitude: position.latitude,
      longitude: position.longitude,
      photoUrl: photoUrl,
    );
  }

  QuestVerificationResult _verifyPhoto({
    required QuestSubmission submission,
  }) {
    final photoUrl = submission.photoUrl;

    if (photoUrl == null || photoUrl.trim().isEmpty) {
      return const QuestVerificationResult(
        isVerified: false,
        message: 'A photo is required to complete this quest.',
      );
    }

    return const QuestVerificationResult(
      isVerified: true,
      message: 'Photo submitted successfully.',
    );
  }

  QuestVerificationResult _verifyGps({
    required Quest quest,
    required QuestSubmission submission,
  }) {
    final questLatitude = quest.latitude;
    final questLongitude = quest.longitude;

    final userLatitude = submission.latitude;
    final userLongitude = submission.longitude;

    if (questLatitude == null || questLongitude == null) {
      return const QuestVerificationResult(
        isVerified: false,
        message: 'This quest does not have a valid verification location.',
      );
    }

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
            'You are ${distance.round()}m away. Move within ${allowedRadius.round()}m to complete this quest.',
      );
    }

    return const QuestVerificationResult(
      isVerified: true,
      message: 'Location verified.',
    );
  }

  QuestVerificationResult _verifyGpsAndPhoto({
    required Quest quest,
    required QuestSubmission submission,
  }) {
    final gpsResult = _verifyGps(
      quest: quest,
      submission: submission,
    );

    if (!gpsResult.isVerified) {
      return gpsResult;
    }

    return _verifyPhoto(
      submission: submission,
    );
  }
}