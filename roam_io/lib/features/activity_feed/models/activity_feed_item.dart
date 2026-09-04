/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Presentation activity feed item used by persisted Home, You, external
 *   profile, and detail activity surfaces.
 */

import 'activity_media_item.dart';

export 'activity_media_item.dart';

/// Kind of activity represented in the feed UI.
enum ActivityFeedKind { journey, sidequest, exploration }

extension ActivityFeedKindParsing on ActivityFeedKind {
  static ActivityFeedKind fromWireValue(String value) {
    return ActivityFeedKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => ActivityFeedKind.exploration,
    );
  }
}

/// A single metric row value shown on an activity card or detail screen.
class ActivityFeedMetric {
  const ActivityFeedMetric({required this.label, required this.value});

  final String label;
  final String value;
}

/// Stored bounds for a recorded activity route.
class ActivityRouteBounds {
  const ActivityRouteBounds({
    required this.southwestLatitude,
    required this.southwestLongitude,
    required this.northeastLatitude,
    required this.northeastLongitude,
  });

  final double southwestLatitude;
  final double southwestLongitude;
  final double northeastLatitude;
  final double northeastLongitude;
}

/// UI model for an activity feed entry.
class ActivityFeedItem {
  const ActivityFeedItem({
    required this.id,
    required this.ownerId,
    required this.displayName,
    required this.timestampLabel,
    required this.title,
    required this.kind,
    required this.metrics,
    this.createdAt,
    this.username,
    this.photoUrl,
    this.showMapPreview = true,
    this.sourceJourneyId,
    this.encodedRoute,
    this.routeBounds,
    this.journeyStartTime,
    this.journeyEndTime,
    this.transportMode,
    this.mapImageUrl,
    this.mapImageStoragePath,
    this.media = const <ActivityMediaItem>[],
  });

  final String id;
  final String ownerId;
  final String displayName;
  final String? username;
  final String? photoUrl;
  final String timestampLabel;
  final DateTime? createdAt;
  final String title;
  final ActivityFeedKind kind;
  final List<ActivityFeedMetric> metrics;
  final bool showMapPreview;
  final String? sourceJourneyId;
  final String? encodedRoute;
  final ActivityRouteBounds? routeBounds;
  final DateTime? journeyStartTime;
  final DateTime? journeyEndTime;
  final String? transportMode;

  /// Map picture captured when the journey was saved, with its own fog already
  /// drawn on it. Cards render this instead of standing up a live map.
  final String? mapImageUrl;
  final String? mapImageStoragePath;
  final List<ActivityMediaItem> media;

  bool get hasMapImage => (mapImageUrl ?? '').isNotEmpty;

  List<String> get mediaUrls => media.map((item) => item.url).toList();

  bool get hasMedia => media.isNotEmpty;

  /// Returns a copy with optional identity fields overridden (e.g. signed-in user).
  ActivityFeedItem copyWith({
    String? id,
    String? ownerId,
    String? displayName,
    String? username,
    String? photoUrl,
  }) {
    return ActivityFeedItem(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      timestampLabel: timestampLabel,
      createdAt: createdAt,
      title: title,
      kind: kind,
      metrics: metrics,
      showMapPreview: showMapPreview,
      sourceJourneyId: sourceJourneyId,
      encodedRoute: encodedRoute,
      routeBounds: routeBounds,
      journeyStartTime: journeyStartTime,
      journeyEndTime: journeyEndTime,
      transportMode: transportMode,
      mapImageUrl: mapImageUrl,
      mapImageStoragePath: mapImageStoragePath,
      media: media,
    );
  }
}
