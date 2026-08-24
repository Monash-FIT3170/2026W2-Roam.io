import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';

void main() {
  group('Quest enums', () {
    test('quest categories expose expected display names', () {
      expect(QuestCategory.adventure.displayName, 'Adventure');
      expect(QuestCategory.fitness.displayName, 'Fitness');
      expect(QuestCategory.nature.displayName, 'Nature');
      expect(QuestCategory.culture.displayName, 'Culture');
      expect(QuestCategory.food.displayName, 'Food');
      expect(QuestCategory.social.displayName, 'Social');
      expect(QuestCategory.history.displayName, 'History');
      expect(QuestCategory.photography.displayName, 'Photography');
      expect(QuestCategory.nightlife.displayName, 'Nightlife');
      expect(QuestCategory.seasonal.displayName, 'Seasonal');
      expect(QuestCategory.hiddenGem.displayName, 'Hidden Gem');
    });

    test('quest difficulties expose expected display names', () {
      expect(QuestDifficulty.easy.displayName, 'Easy');
      expect(QuestDifficulty.medium.displayName, 'Medium');
      expect(QuestDifficulty.hard.displayName, 'Hard');
      expect(QuestDifficulty.epic.displayName, 'Epic');
    });

    test('verification types expose expected display names', () {
      expect(QuestVerificationType.gps.displayName, isNotEmpty);
      expect(QuestVerificationType.photo.displayName, isNotEmpty);
      expect(QuestVerificationType.gpsAndPhoto.displayName, isNotEmpty);
    });

    test('all quest statuses have unique enum names', () {
      final names = QuestStatus.values.map((status) => status.name);

      expect(names.toSet().length, QuestStatus.values.length);
    });
  });
}
