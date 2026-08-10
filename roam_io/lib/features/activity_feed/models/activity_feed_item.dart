/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Presentation activity feed item used by persisted Home, You, external
 *   profile, and detail activity surfaces.
 */

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
    this.username,
    this.photoUrl,
    this.showMapPreview = true,
  });

  final String id;
  final String ownerId;
  final String displayName;
  final String? username;
  final String? photoUrl;
  final String timestampLabel;
  final String title;
  final ActivityFeedKind kind;
  final List<ActivityFeedMetric> metrics;
  final bool showMapPreview;

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
      title: title,
      kind: kind,
      metrics: metrics,
      showMapPreview: showMapPreview,
    );
  }
}
