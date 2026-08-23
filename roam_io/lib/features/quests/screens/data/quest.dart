/*
 * Description:
 *   Represents a quest definition available to all users.
 *   Stores quest details, rewards, location requirements and availability.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
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
    this.verificationPrompt,
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
  final String? verificationPrompt;

  final String? imageUrl;
  final int? estimatedMinutes;

  final DateTime? availableFrom;
  final DateTime? availableUntil;

  bool get isPermanent => availableFrom == null && availableUntil == null;

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

  factory Quest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Quest ${document.id} contains no data');
    }

    return Quest(
      id: document.id,
      title: data['title'] as String? ?? 'Untitled Quest',
      description: data['description'] as String? ?? '',
      category: _parseCategory(data['category']),
      difficulty: _parseDifficulty(data['difficulty']),
      rewardXp: (data['rewardXp'] as num?)?.toInt() ?? 0,
      verificationType: _parseVerificationType(data['verificationType']),
      isActive: data['isActive'] as bool? ?? true,
      regionId: data['regionId'] as String?,
      placeId: (data['placeId'] as num?)?.toInt(),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      verificationRadiusMetres:
          (data['verificationRadiusMetres'] as num?)?.toDouble(),
      verificationPrompt: data['verificationPrompt'] as String?,
      imageUrl: data['imageUrl'] as String?,
      estimatedMinutes: (data['estimatedMinutes'] as num?)?.toInt(),
      availableFrom: _parseDate(data['availableFrom']),
      availableUntil: _parseDate(data['availableUntil']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category.name,
      'difficulty': difficulty.name,
      'rewardXp': rewardXp,
      'verificationType': verificationType.name,
      'isActive': isActive,
      'regionId': regionId,
      'placeId': placeId,
      'latitude': latitude,
      'longitude': longitude,
      'verificationRadiusMetres': verificationRadiusMetres,
      'imageUrl': imageUrl,
      'estimatedMinutes': estimatedMinutes,
      'verificationPrompt': verificationPrompt,
      'availableFrom': availableFrom == null
          ? null
          : Timestamp.fromDate(availableFrom!),
      'availableUntil': availableUntil == null
          ? null
          : Timestamp.fromDate(availableUntil!),
    };
  }

  static QuestCategory _parseCategory(dynamic value) {
    return QuestCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => QuestCategory.adventure,
    );
  }

  static QuestDifficulty _parseDifficulty(dynamic value) {
    return QuestDifficulty.values.firstWhere(
      (difficulty) => difficulty.name == value,
      orElse: () => QuestDifficulty.easy,
    );
  }

  static QuestVerificationType _parseVerificationType(dynamic value) {
    return QuestVerificationType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => QuestVerificationType.manual,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}