/*
 * Author: Amarprit Singh
 * Last Updated: 29 August 2026
 * Description:
 *   Everything the Share Journey card draws, resolved either from a Journey
 *   document the viewer owns or from the activity post itself. Only the owner
 *   can read a journey document, so the post is the sole source for anyone
 *   else's journey — and it already carries the route, timestamps, transport
 *   mode and metrics the card needs.
 */

import '../../activity_feed/models/activity_feed_item.dart';
import '../data/route_distance.dart';
import 'journey.dart';
import 'transport_mode.dart';

/// One headline number on the share card, e.g. `3.2` over `km`.
class ShareStat {
  const ShareStat({required this.value, required this.unit});

  final String value;
  final String unit;
}

/// Card-ready view of a shared journey or sidequest.
class JourneyShareDetails {
  const JourneyShareDetails({
    required this.title,
    required this.stats,
    this.encodedRoute = '',
    this.mapImageUrl,
    this.transportMode,
  });

  /// Values straight off a journey the viewer owns.
  ///
  /// The map picture belongs to the post rather than the journey document, so
  /// callers that have the post pass it through here.
  factory JourneyShareDetails.fromJourney(
    Journey journey, {
    String? mapImageUrl,
  }) {
    return JourneyShareDetails(
      title: journey.displayTitle,
      encodedRoute: journey.encodedRoute,
      mapImageUrl: mapImageUrl,
      transportMode: journey.transportMode,
      stats: <ShareStat>[
        _distanceStat(journey.distanceMeters),
        _durationStat(journey.durationSeconds),
        if (journey.xpEarned != null)
          ShareStat(value: '${journey.xpEarned}', unit: 'xp')
        else
          ShareStat(value: '${journey.tilesUnlocked}', unit: 'tiles'),
      ],
    );
  }

  /// Values recovered from the post, for a journey nobody can read the
  /// document for — and for kinds that never had a journey behind them.
  factory JourneyShareDetails.fromActivity(ActivityFeedItem activity) {
    if (activity.kind != ActivityFeedKind.journey) {
      // A sidequest records whatever metrics its completion produced and has
      // no route, so its post is shared as those numbers alone.
      return JourneyShareDetails(
        title: activity.title,
        stats: _metricStats(activity.metrics),
      );
    }

    final encodedRoute = activity.encodedRoute ?? '';
    final stats = <ShareStat>[];

    final distanceMeters = encodedRouteDistanceMeters(encodedRoute);
    if (distanceMeters > 0) stats.add(_distanceStat(distanceMeters));

    final durationSeconds = _durationSeconds(activity);
    if (durationSeconds != null) stats.add(_durationStat(durationSeconds));

    final xpEarned = _metricInt(activity.metrics, 'xp gained');
    final tilesUnlocked = _metricInt(activity.metrics, 'tiles unlocked');
    if (xpEarned != null) {
      stats.add(ShareStat(value: '$xpEarned', unit: 'xp'));
    } else if (tilesUnlocked != null) {
      stats.add(ShareStat(value: '$tilesUnlocked', unit: 'tiles'));
    }

    return JourneyShareDetails(
      title: activity.title,
      encodedRoute: encodedRoute,
      mapImageUrl: activity.mapImageUrl,
      transportMode: TransportMode.tryFromString(activity.transportMode),
      // A post whose labels this code does not recognise still has its own
      // metrics row to fall back on, which beats a card with no numbers.
      stats: stats.isEmpty ? _metricStats(activity.metrics) : stats,
    );
  }

  final String title;
  final List<ShareStat> stats;

  /// Encoded polyline to draw, empty when the post has no route.
  final String encodedRoute;

  /// The map picture stored with the post, fog and basemap already on it.
  /// Preferred over drawing the bare polyline when it is available.
  final String? mapImageUrl;

  /// Null when the post never recorded one, e.g. a sidequest.
  final TransportMode? transportMode;

  bool get hasRoute => encodedRoute.isNotEmpty;

  bool get hasMapImage => (mapImageUrl ?? '').isNotEmpty;

  /// Whether the card has anything to show where the map goes.
  bool get hasMapArea => hasMapImage || hasRoute;

  static ShareStat _distanceStat(double meters) {
    if (meters >= 1000) {
      return ShareStat(value: (meters / 1000).toStringAsFixed(1), unit: 'km');
    }
    return ShareStat(value: '${meters.toInt()}', unit: 'm');
  }

  static ShareStat _durationStat(int seconds) {
    if (seconds >= 3600) {
      return ShareStat(value: (seconds / 3600).toStringAsFixed(1), unit: 'hrs');
    }
    return ShareStat(value: (seconds / 60).toStringAsFixed(0), unit: 'min');
  }

  static List<ShareStat> _metricStats(List<ActivityFeedMetric> metrics) {
    return metrics
        .take(3)
        .map((metric) => ShareStat(value: metric.value, unit: metric.label))
        .toList(growable: false);
  }

  /// Prefers the recorded timestamps, which survive any change to how the
  /// Time metric is worded.
  static int? _durationSeconds(ActivityFeedItem activity) {
    final start = activity.journeyStartTime;
    final end = activity.journeyEndTime;
    if (start != null && end != null) {
      final seconds = end.difference(start).inSeconds;
      if (seconds > 0) return seconds;
    }
    return _parseDuration(_metricValue(activity.metrics, 'time'));
  }

  /// Reads '1h 30m', '21m 0s' and '45s' as written by the feed's own
  /// formatter. Dropping the hours here would turn a long journey into
  /// minutes.
  static int? _parseDuration(String? value) {
    if (value == null) return null;
    final lower = value.toLowerCase();
    final hours = _firstInt(RegExp(r'(\d+)\s*h'), lower) ?? 0;
    final minutes = _firstInt(RegExp(r'(\d+)\s*m'), lower) ?? 0;
    final seconds = _firstInt(RegExp(r'(\d+)\s*s'), lower) ?? 0;

    final total = hours * 3600 + minutes * 60 + seconds;
    return total > 0 ? total : null;
  }

  static String? _metricValue(List<ActivityFeedMetric> metrics, String label) {
    for (final metric in metrics) {
      if (metric.label.toLowerCase() == label) return metric.value;
    }
    return null;
  }

  static int? _metricInt(List<ActivityFeedMetric> metrics, String label) {
    final value = _metricValue(metrics, label);
    return value == null ? null : _firstInt(RegExp(r'(\d+)'), value);
  }

  static int? _firstInt(RegExp pattern, String value) {
    final match = pattern.firstMatch(value);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}
