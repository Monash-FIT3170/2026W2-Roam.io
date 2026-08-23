/*
 * Author: GitHub Copilot
 * Last Modified: 30/07/2026
 * Description:
 *   Domain model for a completed journey. Contains all metadata and the
 *   encoded route polyline for efficient storage and rendering.
 */

import 'package:cloud_firestore/cloud_firestore.dart';

import 'journey_location.dart';
import 'transport_mode.dart';

/// Represents a completed journey with route data and metadata.
class Journey {
  /// Creates a new journey.
  const Journey({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.startLocation,
    required this.endLocation,
    required this.transportMode,
    required this.encodedRoute,
    required this.distanceMeters,
    required this.durationSeconds,
    this.title,
    this.xpEarned,
    this.journeyXpEarned,
    this.tilesUnlocked = 0,
    this.tileXpEarned = 0,
    this.unlockedTileIds = const [],
    this.areaUnlockedSquareMetres = 0,
    this.tilesPerKm,
  });

  /// Unique identifier for this journey.
  final String id;

  /// The user who completed this journey.
  final String userId;

  /// When the journey started.
  final DateTime startTime;

  /// When the journey ended.
  final DateTime endTime;

  /// The starting location.
  final JourneyLocation startLocation;

  /// The ending location.
  final JourneyLocation endLocation;

  /// How the user traveled.
  final TransportMode transportMode;

  /// The route as an encoded polyline string (Google Polyline Algorithm).
  /// This compresses the route data by ~75% compared to storing raw coordinates.
  final String encodedRoute;

  /// Total distance traveled in meters.
  final double distanceMeters;

  /// Total duration in seconds.
  final int durationSeconds;

  /// User-facing Journey title chosen during summary review.
  final String? title;

  /// Total XP earned during this journey, including unlocked-tile XP.
  final int? xpEarned;

  /// Distance and transport-mode XP awarded when the journey is saved.
  final int? journeyXpEarned;

  /// Number of new map tiles unlocked while tracking this journey.
  final int tilesUnlocked;

  /// XP already awarded as those tiles were unlocked.
  final int tileXpEarned;

  /// SA1 polygon IDs first unlocked while tracking this journey.
  final List<String> unlockedTileIds;

  /// Sum of unlocked tile areas recorded during this journey.
  final double areaUnlockedSquareMetres;

  /// New tiles unlocked per kilometre travelled.
  final double? tilesPerKm;

  /// Returns the distance formatted as a string (e.g., "3.2 km").
  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toInt()} m';
  }

  /// Returns the duration formatted as a string (e.g., "45 mins" or "1 hr 30 mins").
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours hr${hours > 1 ? 's' : ''} $minutes min${minutes != 1 ? 's' : ''}';
    }
    return '$minutes min${minutes != 1 ? 's' : ''}';
  }

  /// Returns the reviewed title, falling back to the legacy route title.
  String get displayTitle {
    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return '${startLocation.name} to ${endLocation.name}';
  }

  /// Creates a copy with optional field overrides.
  Journey copyWith({
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    JourneyLocation? startLocation,
    JourneyLocation? endLocation,
    TransportMode? transportMode,
    String? encodedRoute,
    double? distanceMeters,
    int? durationSeconds,
    String? title,
    int? xpEarned,
    int? journeyXpEarned,
    int? tilesUnlocked,
    int? tileXpEarned,
    List<String>? unlockedTileIds,
    double? areaUnlockedSquareMetres,
    double? tilesPerKm,
  }) {
    return Journey(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      transportMode: transportMode ?? this.transportMode,
      encodedRoute: encodedRoute ?? this.encodedRoute,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      title: title ?? this.title,
      xpEarned: xpEarned ?? this.xpEarned,
      journeyXpEarned: journeyXpEarned ?? this.journeyXpEarned,
      tilesUnlocked: tilesUnlocked ?? this.tilesUnlocked,
      tileXpEarned: tileXpEarned ?? this.tileXpEarned,
      unlockedTileIds: unlockedTileIds ?? this.unlockedTileIds,
      areaUnlockedSquareMetres:
          areaUnlockedSquareMetres ?? this.areaUnlockedSquareMetres,
      tilesPerKm: tilesPerKm ?? this.tilesPerKm,
    );
  }

  /// Creates a Journey from a Firestore document.
  factory Journey.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Journey(
      id: doc.id,
      userId: data['userId'] as String,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      startLocation: JourneyLocation.fromMap(
        data['startLocation'] as Map<String, dynamic>,
      ),
      endLocation: JourneyLocation.fromMap(
        data['endLocation'] as Map<String, dynamic>,
      ),
      transportMode: TransportMode.fromString(data['transportMode'] as String),
      encodedRoute: data['encodedRoute'] as String,
      distanceMeters: (data['distanceMeters'] as num).toDouble(),
      durationSeconds: data['durationSeconds'] as int,
      title: data['title'] as String?,
      xpEarned: data['xpEarned'] as int?,
      journeyXpEarned:
          (data['journeyXpEarned'] as num?)?.toInt() ??
          (data['xpEarned'] as num?)?.toInt(),
      tilesUnlocked: (data['tilesUnlocked'] as num?)?.toInt() ?? 0,
      tileXpEarned: (data['tileXpEarned'] as num?)?.toInt() ?? 0,
      unlockedTileIds:
          (data['unlockedTileIds'] as List<dynamic>?)
              ?.map((value) => '$value')
              .toList() ??
          const [],
      areaUnlockedSquareMetres:
          (data['areaUnlockedSquareMetres'] as num?)?.toDouble() ?? 0,
      tilesPerKm: (data['tilesPerKm'] as num?)?.toDouble(),
    );
  }

  /// Converts this journey to a map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'startLocation': startLocation.toMap(),
      'endLocation': endLocation.toMap(),
      'transportMode': transportMode.name,
      'encodedRoute': encodedRoute,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
      'xpEarned': xpEarned,
      'journeyXpEarned': journeyXpEarned,
      'tilesUnlocked': tilesUnlocked,
      'tileXpEarned': tileXpEarned,
      'unlockedTileIds': unlockedTileIds,
      'areaUnlockedSquareMetres': areaUnlockedSquareMetres,
      if (tilesPerKm != null) 'tilesPerKm': tilesPerKm,
    };
  }

  @override
  String toString() =>
      'Journey(id: $id, title: $displayTitle, distance: $formattedDistance)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Journey && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
