import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/data/user_quest.dart';
import 'package:roam_io/features/quests/screens/quest_ai_verification_service.dart';
import 'package:roam_io/features/quests/screens/quest_controller.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';
import 'package:roam_io/features/quests/screens/quest_photo_verification_result.dart';
import 'package:roam_io/features/quests/screens/quest_service.dart';
import 'package:roam_io/features/quests/screens/quest_submission.dart';
import 'package:roam_io/features/quests/screens/quest_verification.dart';
import 'package:roam_io/features/quests/screens/quest_verification_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  group('Quest remaining coverage', () {
    group('Quest model', () {
      test('active permanent quest is available', () {
        final quest = _quest();

        expect(quest.isPermanent, isTrue);
        expect(quest.isAvailableAt(DateTime(2026, 8, 25)), isTrue);
      });

      test('inactive quest is unavailable', () {
        final quest = _quest(isActive: false);

        expect(quest.isAvailableAt(DateTime(2026, 8, 25)), isFalse);
      });

      test('quest before availableFrom is unavailable', () {
        final quest = _quest(availableFrom: DateTime(2030));

        expect(quest.isAvailableAt(DateTime(2026, 8, 25)), isFalse);
      });

      test('quest after availableUntil is unavailable', () {
        final quest = _quest(availableUntil: DateTime(2020));

        expect(quest.isAvailableAt(DateTime(2026, 8, 25)), isFalse);
      });

      test('quest inside availability window is available', () {
        final quest = _quest(
          availableFrom: DateTime(2026, 8, 1),
          availableUntil: DateTime(2026, 8, 31),
        );

        expect(quest.isPermanent, isFalse);

        expect(quest.isAvailableAt(DateTime(2026, 8, 25)), isTrue);
      });

      test('gps verification requires GPS but not photo', () {
        final quest = _quest(verificationType: QuestVerificationType.gps);

        expect(quest.requiresGps, isTrue);
        expect(quest.requiresPhoto, isFalse);
      });

      test('photo verification requires photo but not GPS', () {
        final quest = _quest(verificationType: QuestVerificationType.photo);

        expect(quest.requiresGps, isFalse);
        expect(quest.requiresPhoto, isTrue);
      });

      test('gpsAndPhoto requires both evidence types', () {
        final quest = _quest(
          verificationType: QuestVerificationType.gpsAndPhoto,
        );

        expect(quest.requiresGps, isTrue);
        expect(quest.requiresPhoto, isTrue);
      });

      test('manual verification requires neither automatic evidence type', () {
        final quest = _quest(verificationType: QuestVerificationType.manual);

        expect(quest.requiresGps, isFalse);
        expect(quest.requiresPhoto, isFalse);
      });

      test('toMap includes optional fields', () {
        final quest = _quest(
          verificationPrompt: 'Show the landmark.',
          regionId: 'melbourne',
          placeId: 123,
          imageUrl: 'https://example.com/image.jpg',
          estimatedMinutes: 90,
        );

        final map = quest.toMap();

        expect(map['regionId'], 'melbourne');
        expect(map['placeId'], 123);
        expect(map['verificationPrompt'], 'Show the landmark.');
        expect(map['imageUrl'], 'https://example.com/image.jpg');
        expect(map['estimatedMinutes'], 90);
      });

      test('fromFirestore uses default values for missing fields', () async {
        final firestore = FakeFirebaseFirestore();

        await firestore.collection('quests').doc('minimal').set({
          'isActive': true,
        });

        final document = await firestore
            .collection('quests')
            .doc('minimal')
            .get();

        final quest = Quest.fromFirestore(document);

        expect(quest.id, 'minimal');
        expect(quest.title, 'Untitled Quest');
        expect(quest.description, '');
        expect(quest.rewardXp, 0);
      });

      test('unknown category falls back to adventure', () async {
        final quest = await _loadMalformedQuest(
          field: 'category',
          value: 'doesNotExist',
        );

        expect(quest.category, QuestCategory.adventure);
      });

      test('unknown difficulty falls back to easy', () async {
        final quest = await _loadMalformedQuest(
          field: 'difficulty',
          value: 'impossible',
        );

        expect(quest.difficulty, QuestDifficulty.easy);
      });

      test('unknown verification type falls back to manual', () async {
        final quest = await _loadMalformedQuest(
          field: 'verificationType',
          value: 'magic',
        );

        expect(quest.verificationType, QuestVerificationType.manual);
      });
    });

    group('Quest enums', () {
      test('all category display names are non-empty', () {
        for (final category in QuestCategory.values) {
          expect(category.displayName, isNotEmpty);
        }
      });

      test('all difficulty display names are non-empty', () {
        for (final difficulty in QuestDifficulty.values) {
          expect(difficulty.displayName, isNotEmpty);
        }
      });

      test('all verification display names are non-empty', () {
        for (final type in QuestVerificationType.values) {
          expect(type.displayName, isNotEmpty);
        }
      });

      test('enum values have unique names', () {
        expect(
          QuestCategory.values.map((e) => e.name).toSet().length,
          QuestCategory.values.length,
        );

        expect(
          QuestDifficulty.values.map((e) => e.name).toSet().length,
          QuestDifficulty.values.length,
        );

        expect(
          QuestStatus.values.map((e) => e.name).toSet().length,
          QuestStatus.values.length,
        );
      });
    });

    group('UserQuest', () {
      test('copyWith preserves existing properties', () {
        final original = UserQuest(
          id: 'quest-1',
          userId: 'user-1',
          questId: 'quest-1',
          status: QuestStatus.active,
          startedAt: DateTime(2026, 8, 20),
        );

        final updated = original.copyWith(status: QuestStatus.completed);

        expect(updated.id, original.id);
        expect(updated.userId, original.userId);
        expect(updated.questId, original.questId);
        expect(updated.startedAt, original.startedAt);
        expect(updated.status, QuestStatus.completed);
      });

      test('toMap contains status and quest ID', () {
        final quest = UserQuest(
          id: 'quest-1',
          userId: 'user-1',
          questId: 'quest-1',
          status: QuestStatus.active,
          startedAt: DateTime(2026, 8, 20),
        );

        final map = quest.toMap();

        expect(map['questId'], 'quest-1');
        expect(map['status'], 'active');
        expect(map['startedAt'], isNotNull);
      });

      test('fromFirestore handles available status', () async {
        final progress = await _loadUserQuest(QuestStatus.available);

        expect(progress.status, QuestStatus.available);
      });

      test('fromFirestore handles active status', () async {
        final progress = await _loadUserQuest(QuestStatus.active);

        expect(progress.status, QuestStatus.active);
      });

      test('fromFirestore handles submitted status', () async {
        final progress = await _loadUserQuest(QuestStatus.submitted);

        expect(progress.status, QuestStatus.submitted);
      });

      test('fromFirestore handles completed status', () async {
        final progress = await _loadUserQuest(QuestStatus.completed);

        expect(progress.status, QuestStatus.completed);
      });

      test('fromFirestore handles rejected status', () async {
        final progress = await _loadUserQuest(QuestStatus.rejected);

        expect(progress.status, QuestStatus.rejected);
      });

      test('fromFirestore handles expired status', () async {
        final progress = await _loadUserQuest(QuestStatus.expired);

        expect(progress.status, QuestStatus.expired);
      });
    });

    group('Verification value objects', () {
      test('QuestVerificationResult stores successful result', () {
        const result = QuestVerificationResult(
          isVerified: true,
          message: 'Verified.',
        );

        expect(result.isVerified, isTrue);
        expect(result.message, 'Verified.');
      });

      test('QuestVerificationResult stores failed result', () {
        const result = QuestVerificationResult(
          isVerified: false,
          message: 'Failed.',
        );

        expect(result.isVerified, isFalse);
        expect(result.message, 'Failed.');
      });

      test('photo result parses full response', () {
        final result = QuestPhotoVerificationResult.fromMap({
          'verified': true,
          'confidence': 0.96,
          'feedback': 'Looks correct.',
        });

        expect(result.verified, isTrue);
        expect(result.confidence, 0.96);
        expect(result.feedback, 'Looks correct.');
      });

      test('photo result handles integer confidence', () {
        final result = QuestPhotoVerificationResult.fromMap({
          'verified': true,
          'confidence': 1,
          'feedback': 'Verified.',
        });

        expect(result.confidence, 1.0);
      });

      test('photo result uses defaults for empty map', () {
        final result = QuestPhotoVerificationResult.fromMap(
          <String, dynamic>{},
        );

        expect(result.verified, isFalse);
        expect(result.confidence, 0);
        expect(result.feedback, isNotEmpty);
      });

      test('submission stores location and photo URL', () {
        const submission = QuestSubmission(
          questId: 'quest-1',
          latitude: -37.81,
          longitude: 144.96,
          photoUrl: 'proof.jpg',
        );

        expect(submission.questId, 'quest-1');
        expect(submission.latitude, -37.81);
        expect(submission.longitude, 144.96);
        expect(submission.photoUrl, 'proof.jpg');
      });
    });

    group('QuestVerificationService', () {
      test('exact GPS position verifies', () async {
        final service = QuestVerificationService();

        final result = await service.verify(
          quest: _quest(verificationType: QuestVerificationType.gps),
          submission: const QuestSubmission(
            questId: 'quest-1',
            latitude: -37.81,
            longitude: 144.96,
          ),
        );

        expect(result.isVerified, isTrue);
        expect(result.message, 'Location verified.');
      });

      test('near GPS position verifies', () async {
        final service = QuestVerificationService();

        final result = await service.verify(
          quest: _quest(
            verificationType: QuestVerificationType.gps,
            radius: 500,
          ),
          submission: const QuestSubmission(
            questId: 'quest-1',
            latitude: -37.8101,
            longitude: 144.9601,
          ),
        );

        expect(result.isVerified, isTrue);
      });

      test('distant GPS position fails', () async {
        final service = QuestVerificationService();

        final result = await service.verify(
          quest: _quest(
            verificationType: QuestVerificationType.gps,
            radius: 50,
          ),
          submission: const QuestSubmission(
            questId: 'quest-1',
            latitude: -38.0,
            longitude: 145.0,
          ),
        );

        expect(result.isVerified, isFalse);
        expect(result.message, contains('Move within 50m'));
      });

      test('missing quest coordinates fail GPS verification', () async {
        final service = QuestVerificationService();

        const quest = Quest(
          id: 'quest-1',
          title: 'No Location',
          description: '',
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

      test('missing submitted location fails GPS verification', () async {
        final service = QuestVerificationService();

        final result = await service.verify(
          quest: _quest(verificationType: QuestVerificationType.gps),
          submission: const QuestSubmission(questId: 'quest-1'),
        );

        expect(result.isVerified, isFalse);
        expect(result.message, contains('current location'));
      });

      test('manual verification is unsupported', () async {
        final service = QuestVerificationService();

        final result = await service.verify(
          quest: _quest(verificationType: QuestVerificationType.manual),
          submission: const QuestSubmission(questId: 'quest-1'),
        );

        expect(result.isVerified, isFalse);
        expect(result.message, contains('not supported'));
      });

      test('photo verification without bytes fails', () async {
        final service = QuestVerificationService();

        final result = await service.verify(
          quest: _quest(
            verificationType: QuestVerificationType.photo,
            verificationPrompt: 'Show the attraction.',
          ),
          submission: const QuestSubmission(questId: 'quest-1'),
          photoBytes: null,
        );

        expect(result.isVerified, isFalse);
      });

      test('gpsAndPhoto fails immediately when GPS fails', () async {
        final service = QuestVerificationService();

        final result = await service.verify(
          quest: _quest(
            verificationType: QuestVerificationType.gpsAndPhoto,
            verificationPrompt: 'Show the attraction.',
            radius: 50,
          ),
          submission: const QuestSubmission(
            questId: 'quest-1',
            latitude: -38,
            longitude: 145,
          ),
          photoBytes: Uint8List.fromList([1, 2, 3]),
        );

        expect(result.isVerified, isFalse);
        expect(result.message, contains('Move within 50m'));
      });
    });

    group('QuestAiVerificationService validation', () {
      test('AI verification exception exposes message', () {
        const exception = QuestAiVerificationException(
          'Verification unavailable.',
        );

        expect(exception.message, 'Verification unavailable.');

        expect(exception.toString(), 'Verification unavailable.');
      });
    });

    group('QuestController extra branches', () {
      test('region load only returns matching region', () async {
        final firestore = FakeFirebaseFirestore();

        await _seedQuest(firestore, id: 'melbourne', regionId: 'melbourne');

        await _seedQuest(firestore, id: 'dandenong', regionId: 'dandenong');

        final controller = QuestController(
          questService: QuestService(firestore: firestore),
          verificationService: QuestVerificationService(),
        );

        await controller.loadQuests(regionId: 'melbourne');

        expect(controller.quests, hasLength(1));
        expect(controller.quests.single.id, 'melbourne');
      });

      test('category filter returns matching quests only', () async {
        final firestore = FakeFirebaseFirestore();

        await _seedQuest(
          firestore,
          id: 'adventure',
          category: QuestCategory.adventure,
        );

        await _seedQuest(
          firestore,
          id: 'nature',
          category: QuestCategory.nature,
        );

        final controller = QuestController(
          questService: QuestService(firestore: firestore),
          verificationService: QuestVerificationService(),
        );

        await controller.initialise();

        controller.selectCategory(QuestCategory.nature);

        expect(controller.quests, hasLength(1));
        expect(controller.quests.single.id, 'nature');
      });

      test('clearing category restores all quests', () async {
        final firestore = FakeFirebaseFirestore();

        await _seedQuest(firestore, id: 'one');

        await _seedQuest(firestore, id: 'two');

        final controller = QuestController(
          questService: QuestService(firestore: firestore),
          verificationService: QuestVerificationService(),
        );

        await controller.initialise();

        controller.selectCategory(QuestCategory.adventure);

        controller.selectCategory(null);

        expect(controller.selectedCategory, isNull);

        expect(controller.quests, hasLength(2));
      });

      test('unknown quest has no progress', () {
        final controller = QuestController(
          questService: QuestService(firestore: FakeFirebaseFirestore()),
          verificationService: QuestVerificationService(),
        );

        expect(controller.progressForQuest('missing'), isNull);

        expect(controller.isQuestStarted('missing'), isFalse);

        expect(controller.isQuestCompleted('missing'), isFalse);
      });

      test('clearMessages clears controller messages', () async {
        final firestore = FakeFirebaseFirestore();

        await _seedQuest(firestore, id: 'quest-1');

        final controller = QuestController(
          questService: QuestService(firestore: firestore),
          verificationService: QuestVerificationService(),
        );

        await controller.initialise();

        final quest = controller.quests.single;

        await controller.completeQuest(userId: 'user-1', quest: quest);

        expect(controller.errorMessage, isNotNull);

        controller.clearMessages();

        expect(controller.errorMessage, isNull);
        expect(controller.completionMessage, isNull);
        expect(controller.lastVerificationPassed, isNull);
      });
    });
  });
}

Future<Quest> _loadMalformedQuest({
  required String field,
  required dynamic value,
}) async {
  final firestore = FakeFirebaseFirestore();

  await firestore.collection('quests').doc('malformed').set({
    'title': 'Malformed',
    'description': '',
    'category': 'adventure',
    'difficulty': 'easy',
    'verificationType': 'gps',
    'rewardXp': 100,
    'isActive': true,
    field: value,
  });

  final document = await firestore.collection('quests').doc('malformed').get();

  return Quest.fromFirestore(document);
}

Future<UserQuest> _loadUserQuest(QuestStatus status) async {
  final firestore = FakeFirebaseFirestore();

  await firestore
      .collection('profiles')
      .doc('user-1')
      .collection('quests')
      .doc('quest-1')
      .set({
        'questId': 'quest-1',
        'status': status.name,
        'startedAt': DateTime(2026, 8, 20),
        'submittedAt': DateTime(2026, 8, 21),
        'completedAt': DateTime(2026, 8, 22),
        'rejectionReason': 'Rejected',
      });

  final document = await firestore
      .collection('profiles')
      .doc('user-1')
      .collection('quests')
      .doc('quest-1')
      .get();

  return UserQuest.fromFirestore(userId: 'user-1', document: document);
}

Future<void> _seedQuest(
  FakeFirebaseFirestore firestore, {
  required String id,
  String? regionId,
  QuestCategory category = QuestCategory.adventure,
}) {
  return firestore.collection('quests').doc(id).set({
    'title': 'Quest $id',
    'description': 'Test quest.',
    'category': category.name,
    'difficulty': QuestDifficulty.easy.name,
    'rewardXp': 100,
    'verificationType': QuestVerificationType.gps.name,
    'isActive': true,
    'regionId': regionId,
    'latitude': -37.81,
    'longitude': 144.96,
    'verificationRadiusMetres': 100,
  });
}

Quest _quest({
  QuestDifficulty difficulty = QuestDifficulty.easy,
  QuestVerificationType verificationType = QuestVerificationType.gps,
  bool isActive = true,
  double? radius = 100,
  String? verificationPrompt,
  String? regionId,
  int? placeId,
  String? imageUrl,
  int? estimatedMinutes,
  DateTime? availableFrom,
  DateTime? availableUntil,
}) {
  return Quest(
    id: 'quest-1',
    title: 'Test Quest',
    description: 'Complete this quest.',
    category: QuestCategory.adventure,
    difficulty: difficulty,
    rewardXp: 200,
    verificationType: verificationType,
    isActive: isActive,
    regionId: regionId,
    placeId: placeId,
    latitude: -37.81,
    longitude: 144.96,
    verificationRadiusMetres: radius,
    verificationPrompt: verificationPrompt,
    imageUrl: imageUrl,
    estimatedMinutes: estimatedMinutes,
    availableFrom: availableFrom,
    availableUntil: availableUntil,
  );
}
