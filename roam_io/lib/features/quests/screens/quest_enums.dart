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

enum QuestDifficulty {
  easy,
  medium,
  hard,
  epic,
}

enum QuestStatus {
  available,
  active,
  submitted,
  completed,
  rejected,
  expired,
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