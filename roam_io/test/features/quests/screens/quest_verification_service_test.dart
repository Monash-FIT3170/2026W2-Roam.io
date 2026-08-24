import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';
import 'package:roam_io/features/quests/screens/quest_submission.dart';
import 'package:roam_io/features/quests/screens/quest_verification_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  group('QuestVerificationService', () {
    test('GPS verification succeeds inside allowed radius', () async {
      final service = QuestVerificationService();

      final result = await service.verify(
        quest: _gpsQuest(latitude: -37.8206, longitude: 144.9585, radius: 200),
        submission: const QuestSubmission(
          questId: 'quest-1',
          latitude: -37.8206,
          longitude: 144.9585,
        ),
      );

      expect(result.isVerified, isTrue);
      expect(result.message, 'Location verified.');
    });

    test('GPS verification fails outside allowed radius', () async {
      final service = QuestVerificationService();

      final result = await service.verify(
        quest: _gpsQuest(latitude: -37.8206, longitude: 144.9585, radius: 100),
        submission: const QuestSubmission(
          questId: 'quest-1',
          latitude: -37.8100,
          longitude: 144.9585,
        ),
      );

      expect(result.isVerified, isFalse);
      expect(result.message, contains('Move within 100m'));
    });

    test('GPS verification fails when quest has no location', () async {
      final service = QuestVerificationService();

      const quest = Quest(
        id: 'quest-1',
        title: 'No Location',
        description: 'Test',
        category: QuestCategory.adventure,
        difficulty: QuestDifficulty.easy,
        rewardXp: 100,
        verificationType: QuestVerificationType.gps,
        isActive: true,
      );

      final result = await service.verify(
        quest: quest,
        submission: const QuestSubmission(
          questId: 'quest-1',
          latitude: -37.81,
          longitude: 144.96,
        ),
      );

      expect(result.isVerified, isFalse);
      expect(result.message, contains('verification location'));
    });

    test('GPS verification fails when submission has no location', () async {
      final service = QuestVerificationService();

      final result = await service.verify(
        quest: _gpsQuest(latitude: -37.8206, longitude: 144.9585, radius: 200),
        submission: const QuestSubmission(questId: 'quest-1'),
      );

      expect(result.isVerified, isFalse);
      expect(result.message, contains('current location'));
    });

    test('photo quest fails when no photo bytes supplied', () async {
      final service = QuestVerificationService();

      const quest = Quest(
        id: 'photo-quest',
        title: 'Photo Quest',
        description: 'Take a photo.',
        category: QuestCategory.photography,
        difficulty: QuestDifficulty.easy,
        rewardXp: 100,
        verificationType: QuestVerificationType.photo,
        isActive: true,
        verificationPrompt: 'Show the landmark.',
      );

      final result = await service.verify(
        quest: quest,
        submission: const QuestSubmission(questId: 'photo-quest'),
      );

      expect(result.isVerified, isFalse);
      expect(result.message, contains('proof photo'));
    });

    test(
      'gpsAndPhoto fails GPS before attempting photo verification',
      () async {
        final service = QuestVerificationService();

        const quest = Quest(
          id: 'combined',
          title: 'Combined Quest',
          description: 'Visit and photograph.',
          category: QuestCategory.adventure,
          difficulty: QuestDifficulty.easy,
          rewardXp: 300,
          verificationType: QuestVerificationType.gpsAndPhoto,
          isActive: true,
          latitude: -37.8206,
          longitude: 144.9585,
          verificationRadiusMetres: 100,
          verificationPrompt: 'Show the attraction.',
        );

        final result = await service.verify(
          quest: quest,
          submission: const QuestSubmission(
            questId: 'combined',
            latitude: -37.8000,
            longitude: 144.9585,
          ),
          photoBytes: null,
        );

        expect(result.isVerified, isFalse);
        expect(result.message, contains('Move within 100m'));
      },
    );

    test('unsupported verification method returns false', () async {
      final service = QuestVerificationService();

      const quest = Quest(
        id: 'manual',
        title: 'Manual Quest',
        description: 'Test',
        category: QuestCategory.adventure,
        difficulty: QuestDifficulty.easy,
        rewardXp: 100,
        verificationType: QuestVerificationType.manual,
        isActive: true,
      );

      final result = await service.verify(
        quest: quest,
        submission: const QuestSubmission(questId: 'manual'),
      );

      expect(result.isVerified, isFalse);
      expect(result.message, contains('not supported'));
    });
  });
}

Quest _gpsQuest({
  required double latitude,
  required double longitude,
  required double radius,
}) {
  return Quest(
    id: 'quest-1',
    title: 'GPS Quest',
    description: 'Visit the location.',
    category: QuestCategory.adventure,
    difficulty: QuestDifficulty.easy,
    rewardXp: 200,
    verificationType: QuestVerificationType.gps,
    isActive: true,
    latitude: latitude,
    longitude: longitude,
    verificationRadiusMetres: radius,
  );
}
