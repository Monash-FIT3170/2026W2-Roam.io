/*
 * Description:
 *   Defines the categories, difficulty levels, lifecycle states, and
 *   verification methods supported by the quest feature.
 */

enum QuestCategory {
  adventure,
  fitness,
  nature,
  culture,
  food,
  social,
  history,
  photography,
  nightlife,
  seasonal,
  hiddenGem,
}

extension QuestCategoryX on QuestCategory {
  String get displayName {
    return switch (this) {
      QuestCategory.adventure => 'Adventure',
      QuestCategory.fitness => 'Fitness',
      QuestCategory.nature => 'Nature',
      QuestCategory.culture => 'Culture',
      QuestCategory.food => 'Food',
      QuestCategory.social => 'Social',
      QuestCategory.history => 'History',
      QuestCategory.photography => 'Photography',
      QuestCategory.nightlife => 'Nightlife',
      QuestCategory.seasonal => 'Seasonal',
      QuestCategory.hiddenGem => 'Hidden Gem',
    };
  }
}

enum QuestDifficulty { easy, medium, hard, epic }

extension QuestDifficultyX on QuestDifficulty {
  String get displayName {
    return switch (this) {
      QuestDifficulty.easy => 'Easy',
      QuestDifficulty.medium => 'Medium',
      QuestDifficulty.hard => 'Hard',
      QuestDifficulty.epic => 'Epic',
    };
  }
}

enum QuestStatus { available, active, submitted, completed, rejected, expired }

/// Browsing filters, separate from the persisted quest lifecycle.
enum QuestStatusFilter {
  all('All'),
  available('Available'),
  active('Active'),
  completed('Completed');

  const QuestStatusFilter(this.label);
  final String label;

  bool includes(QuestStatus status) => switch (this) {
    all => true,
    available => status == QuestStatus.available,
    active => status == QuestStatus.active || status == QuestStatus.submitted,
    completed => status == QuestStatus.completed,
  };
}

extension QuestStatusLabel on QuestStatus {
  String get label => switch (this) {
    QuestStatus.available => 'Available',
    QuestStatus.active => 'Active',
    QuestStatus.submitted => 'Awaiting verification',
    QuestStatus.completed => 'Completed',
    QuestStatus.rejected => 'Verification rejected',
    QuestStatus.expired => 'Expired',
  };
}

enum QuestVerificationType {
  gps,
  photo,
  gpsAndPhoto,
  distanceWalked,
  stepCount,
  timeAtLocation,
  manual,
}

extension QuestVerificationTypeX on QuestVerificationType {
  String get displayName {
    return switch (this) {
      QuestVerificationType.gps => 'Location',
      QuestVerificationType.photo => 'Photo',
      QuestVerificationType.gpsAndPhoto => 'Location + Photo',
      QuestVerificationType.distanceWalked => 'Distance',
      QuestVerificationType.stepCount => 'Steps',
      QuestVerificationType.timeAtLocation => 'Time at location',
      QuestVerificationType.manual => 'Manual',
    };
  }
}
