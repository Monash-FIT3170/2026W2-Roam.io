import 'package:roam_io/features/quests/screens/quest_enums.dart';

class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.rewardXp,
    required this.verificationType,
    required this.isActive,
    this.regionId,
    this.placeId,
    this.latitude,
    this.longitude,
    this.verificationRadiusMetres,
    this.imageUrl,
    this.estimatedMinutes,
    this.availableFrom,
    this.availableUntil,
  });

  final String id;
  final String title;
  final String description;

  final QuestCategory category;
  final QuestDifficulty difficulty;
  final QuestVerificationType verificationType;

  final int rewardXp;
  final bool isActive;

  final String? regionId;
  final int? placeId;

  final double? latitude;
  final double? longitude;
  final double? verificationRadiusMetres;

  final String? imageUrl;
  final int? estimatedMinutes;

  final DateTime? availableFrom;
  final DateTime? availableUntil;

  bool get isPermanent =>
      availableFrom == null && availableUntil == null;

  bool isAvailableAt(DateTime now) {
    if (!isActive) return false;

    if (availableFrom != null && now.isBefore(availableFrom!)) {
      return false;
    }

    if (availableUntil != null && now.isAfter(availableUntil!)) {
      return false;
    }

    return true;
  }
}