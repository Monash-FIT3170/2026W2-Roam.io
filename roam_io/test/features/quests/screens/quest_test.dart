import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';

void main() {
  group('Quest', () {
    test('permanent quest has no availability dates', () {
      final quest = _quest();

      expect(quest.isPermanent, isTrue);
    });

    test('quest with availability dates is not permanent', () {
      final quest = _quest(
        availableFrom: DateTime(2026, 8, 1),
        availableUntil: DateTime(2026, 8, 31),
      );

      expect(quest.isPermanent, isFalse);
    });

    test('active quest is available inside date range', () {
      final quest = _quest(
        availableFrom: DateTime(2026, 8, 1),
        availableUntil: DateTime(2026, 8, 31),
      );

      expect(quest.isAvailableAt(DateTime(2026, 8, 15)), isTrue);
    });

    test('inactive quest is unavailable', () {
      final quest = _quest(isActive: false);

      expect(quest.isAvailableAt(DateTime(2026, 8, 15)), isFalse);
    });

    test('quest is unavailable before availableFrom', () {
      final quest = _quest(availableFrom: DateTime(2026, 8, 10));

      expect(quest.isAvailableAt(DateTime(2026, 8, 5)), isFalse);
    });

    test('quest is unavailable after availableUntil', () {
      final quest = _quest(availableUntil: DateTime(2026, 8, 10));

      expect(quest.isAvailableAt(DateTime(2026, 8, 15)), isFalse);
    });

    test('gpsAndPhoto quest requires both GPS and photo', () {
      final quest = _quest(verificationType: QuestVerificationType.gpsAndPhoto);

      expect(quest.requiresGps, isTrue);
      expect(quest.requiresPhoto, isTrue);
    });

    test('gps-only quest does not require photo', () {
      final quest = _quest(verificationType: QuestVerificationType.gps);

      expect(quest.requiresGps, isTrue);
      expect(quest.requiresPhoto, isFalse);
    });

    test('photo-only quest does not require GPS', () {
      final quest = _quest(verificationType: QuestVerificationType.photo);

      expect(quest.requiresPhoto, isTrue);
      expect(quest.requiresGps, isFalse);
    });

    test('toMap preserves verification prompt', () {
      final quest = _quest(
        verificationPrompt: 'Show the aquarium environment.',
      );

      final map = quest.toMap();

      expect(map['verificationPrompt'], 'Show the aquarium environment.');
      expect(map['rewardXp'], 300);
      expect(map['category'], 'adventure');
      expect(map['verificationType'], 'gpsAndPhoto');
    });

    test('fromFirestore parses quest fields correctly', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('quests').doc('quest-1').set({
        'title': 'Aquarium Explorer',
        'description': 'Visit the aquarium.',
        'category': 'adventure',
        'difficulty': 'easy',
        'rewardXp': 300,
        'verificationType': 'gpsAndPhoto',
        'isActive': true,
        'latitude': -37.8206,
        'longitude': 144.9585,
        'verificationRadiusMetres': 180,
        'verificationPrompt': 'Show an aquarium environment.',
        'estimatedMinutes': 90,
      });

      final document = await firestore
          .collection('quests')
          .doc('quest-1')
          .get();

      final quest = Quest.fromFirestore(document);

      expect(quest.id, 'quest-1');
      expect(quest.title, 'Aquarium Explorer');
      expect(quest.category, QuestCategory.adventure);
      expect(quest.difficulty, QuestDifficulty.easy);
      expect(quest.rewardXp, 300);
      expect(quest.verificationType, QuestVerificationType.gpsAndPhoto);
      expect(quest.latitude, -37.8206);
      expect(quest.longitude, 144.9585);
      expect(quest.verificationRadiusMetres, 180);
      expect(quest.verificationPrompt, 'Show an aquarium environment.');
    });
  });
}

Quest _quest({
  bool isActive = true,
  QuestVerificationType verificationType = QuestVerificationType.gpsAndPhoto,
  String? verificationPrompt,
  DateTime? availableFrom,
  DateTime? availableUntil,
}) {
  return Quest(
    id: 'quest-1',
    title: 'Test Quest',
    description: 'Complete the test quest.',
    category: QuestCategory.adventure,
    difficulty: QuestDifficulty.easy,
    rewardXp: 300,
    verificationType: verificationType,
    isActive: isActive,
    latitude: -37.8206,
    longitude: 144.9585,
    verificationRadiusMetres: 180,
    verificationPrompt: verificationPrompt,
    estimatedMinutes: 60,
    availableFrom: availableFrom,
    availableUntil: availableUntil,
  );
}
