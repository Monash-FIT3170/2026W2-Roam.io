/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Temporary stub activity data for Home (friends) and You → Activities
 *   (personal). Not written to Firestore; temporary IDs are stable only for
 *   stub-phase comment routing and must be replaced when the real feed lands.
 */

import '../models/activity_feed_item.dart';

/// Centralised placeholder activities for UI layout only.
class StubActivityFeedData {
  StubActivityFeedData._();

  /// Single personal activity shown on You → Activities (before wiring journeys).
  static const ActivityFeedItem personalJourney = ActivityFeedItem(
    id: 'stub-personal-coles',
    displayName: 'Traveller',
    username: 'traveller',
    timestampLabel: 'August 3, 2026 at 10:07 AM',
    title: 'Journey to Coles',
    kind: ActivityFeedKind.journey,
    showMapPreview: true,
    metrics: [
      ActivityFeedMetric(label: 'Time', value: '47m 51s'),
      ActivityFeedMetric(label: 'Locations Visited', value: '4'),
      ActivityFeedMetric(label: 'XP Gained', value: '+200 XP'),
    ],
  );

  /// Friend-facing stub feed for Home. Distinct from personal activities.
  static const List<ActivityFeedItem> friendActivities = [
    ActivityFeedItem(
      id: 'stub-amar-sidequest',
      displayName: 'Amar',
      username: 'amar',
      timestampLabel: 'August 5, 2026 at 6:42 PM',
      title: 'Sidequest with Mates',
      kind: ActivityFeedKind.sidequest,
      showMapPreview: true,
      metrics: [
        ActivityFeedMetric(label: 'Time', value: '1h 12m'),
        ActivityFeedMetric(label: 'Locations Visited', value: '3'),
        ActivityFeedMetric(label: 'XP Gained', value: '+150 XP'),
      ],
    ),
    ActivityFeedItem(
      id: 'stub-nathan-monash',
      displayName: 'Nathan',
      username: 'nathan',
      timestampLabel: 'August 5, 2026 at 2:15 PM',
      title: 'Journey to Monash',
      kind: ActivityFeedKind.journey,
      showMapPreview: true,
      metrics: [
        ActivityFeedMetric(label: 'Time', value: '38m 20s'),
        ActivityFeedMetric(label: 'Locations Visited', value: '6'),
        ActivityFeedMetric(label: 'XP Gained', value: '+180 XP'),
      ],
    ),
    ActivityFeedItem(
      id: 'stub-sonia-melbourne',
      displayName: 'Sonia',
      username: 'sonia',
      timestampLabel: 'August 4, 2026 at 4:28 PM',
      title: 'Exploring Melbourne CBD',
      kind: ActivityFeedKind.exploration,
      showMapPreview: true,
      metrics: [
        ActivityFeedMetric(label: 'Tiles Unlocked', value: '9'),
        ActivityFeedMetric(label: 'Locations Visited', value: '5'),
        ActivityFeedMetric(label: 'XP Gained', value: '+220 XP'),
      ],
    ),
  ];
}
