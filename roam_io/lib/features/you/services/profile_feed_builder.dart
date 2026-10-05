/*
 * Author: Amarprit Singh
 * Last Updated: 4 October 2026
 * Description:
 *   Derives the Profile tab's journey feed and weekly summary from data the
 *   app already stores: activity posts, the journeys they were published
 *   from, and unlocked tile records. Nothing here writes back — titles,
 *   distances and highlights are worked out for display only.
 */

import '../../activity_feed/models/activity_feed_item.dart';
import '../../journeys/data/route_distance.dart';
import '../../journeys/domain/journey.dart';
import '../../journeys/domain/transport_mode.dart';
import '../../profile/domain/visited_polygon_record.dart';

/// Placeholder name a journey endpoint gets when the traveller never picked a
/// place, so it says nothing about where they went.
const _unnamedLocation = 'current location';

const _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// An inline achievement shown on a journey card.
enum ProfileJourneyHighlightKind { longestThisMonth, mostTiles }

class ProfileJourneyHighlight {
  const ProfileJourneyHighlight(this.kind, this.label);

  final ProfileJourneyHighlightKind kind;
  final String label;
}

/// One activity post, joined to the journey it came from where possible.
class ProfileJourneyEntry {
  const ProfileJourneyEntry({
    required this.activity,
    required this.title,
    required this.occurredAt,
    this.journey,
    this.distanceMeters,
    this.durationSeconds,
    this.tilesUnlocked,
    this.xpEarned,
    this.placeLabel,
    this.transportMode,
    this.highlights = const <ProfileJourneyHighlight>[],
  });

  final ActivityFeedItem activity;

  /// The source journey. Null for sidequests, and for journeys outside the
  /// loaded journey history.
  final Journey? journey;

  /// Display title: the stored one, unless it is a generic time-of-day title
  /// that the journey's own data can improve on.
  final String title;

  /// When the journey started, or when the post was made for other kinds.
  final DateTime occurredAt;
  final double? distanceMeters;
  final int? durationSeconds;
  final int? tilesUnlocked;
  final int? xpEarned;

  /// "Start → End", or the one named endpoint. Null when neither was named.
  final String? placeLabel;
  final TransportMode? transportMode;
  final List<ProfileJourneyHighlight> highlights;

  bool get isJourney => activity.kind == ActivityFeedKind.journey;

  /// The activity carrying the display title, for screens opened from the
  /// card so the detail view and share card agree with what was tapped.
  ActivityFeedItem get displayActivity =>
      title == activity.title ? activity : activity.copyWith(title: title);
}

/// A sticky-headed run of entries: "This week", "Last week", then months.
class ProfileFeedSection {
  const ProfileFeedSection({required this.title, required this.entries});

  final String title;
  final List<ProfileJourneyEntry> entries;

  /// e.g. "3 journeys · 24.1 km".
  String get summary {
    final journeys = entries.where((entry) => entry.isJourney).toList();
    if (journeys.isEmpty) {
      return _plural(entries.length, 'activity', 'activities');
    }
    final distance = journeys.fold<double>(
      0,
      (sum, entry) => sum + (entry.distanceMeters ?? 0),
    );
    final count = _plural(journeys.length, 'journey', 'journeys');
    if (distance <= 0) return count;
    final formatted = formatProfileDistance(distance);
    return '$count · ${formatted.value} ${formatted.unit}';
  }
}

/// Totals for one Monday-to-Sunday week.
class WeeklyActivityTotals {
  const WeeklyActivityTotals({
    required this.weekStart,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.newTiles = 0,
    this.journeyCount = 0,
  });

  final DateTime weekStart;
  final double distanceMeters;
  final int durationSeconds;
  final int newTiles;
  final int journeyCount;
}

/// Joins [activities] to [journeys] and derives everything a card shows.
///
/// [journeys] should be the traveller's whole history: monthly and all-time
/// highlights are judged against it.
List<ProfileJourneyEntry> buildProfileJourneyEntries({
  required List<ActivityFeedItem> activities,
  required List<Journey> journeys,
  required DateTime now,
}) {
  final journeysById = <String, Journey>{
    for (final journey in journeys) journey.id: journey,
  };
  final longestByMonth = _longestJourneyIdByMonth(journeys);
  final mostTilesId = _mostTilesJourneyId(journeys);

  return <ProfileJourneyEntry>[
    for (final activity in activities)
      _entryFor(
        activity: activity,
        journey: journeysById[activity.sourceJourneyId],
        longestByMonth: longestByMonth,
        mostTilesId: mostTilesId,
        now: now,
      ),
  ];
}

ProfileJourneyEntry _entryFor({
  required ActivityFeedItem activity,
  required Journey? journey,
  required Map<int, String> longestByMonth,
  required String? mostTilesId,
  required DateTime now,
}) {
  final isJourney = activity.kind == ActivityFeedKind.journey;
  final occurredAt =
      (journey?.startTime ??
              activity.journeyStartTime ??
              activity.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0))
          .toLocal();

  if (!isJourney) {
    return ProfileJourneyEntry(
      activity: activity,
      title: activity.title,
      occurredAt: occurredAt,
    );
  }

  final metrics = _ParsedMetrics.from(activity.metrics);
  final distanceMeters =
      journey?.distanceMeters ??
      (activity.encodedRoute == null
          ? null
          : encodedRouteDistanceMeters(activity.encodedRoute));
  final durationSeconds =
      journey?.durationSeconds ??
      metrics.durationSeconds ??
      _secondsBetween(activity.journeyStartTime, activity.journeyEndTime);
  final tiles = journey?.tilesUnlocked ?? metrics.tiles;
  final xp = journey?.xpEarned ?? metrics.xp;
  final mode =
      journey?.transportMode ??
      TransportMode.tryFromString(activity.transportMode);
  final start = _namedPlace(journey?.startLocation.name);
  final end = _namedPlace(journey?.endLocation.name);

  final highlights = <ProfileJourneyHighlight>[
    if (journey != null &&
        longestByMonth[_monthKey(journey.startTime)] == journey.id)
      ProfileJourneyHighlight(
        ProfileJourneyHighlightKind.longestThisMonth,
        _monthKey(journey.startTime) == _monthKey(now)
            ? 'Longest journey this month'
            : 'Longest journey in '
                  '${_monthNames[journey.startTime.toLocal().month - 1]}',
      ),
    if (journey != null && journey.id == mostTilesId)
      const ProfileJourneyHighlight(
        ProfileJourneyHighlightKind.mostTiles,
        'Most tiles in one journey',
      ),
  ];

  return ProfileJourneyEntry(
    activity: activity,
    journey: journey,
    title: deriveJourneyDisplayTitle(
      storedTitle: activity.title,
      transportMode: mode,
      start: start,
      destination: end,
      tilesUnlocked: tiles,
    ),
    occurredAt: occurredAt,
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    tilesUnlocked: tiles,
    xpEarned: xp,
    placeLabel: _placeLabel(start, end),
    transportMode: mode,
    highlights: highlights,
  );
}

/// Replaces a generic "Morning Journey"-style title with something the
/// journey's own data supports, and leaves every other title alone.
///
/// Titles the traveller typed are never generic, so renamed journeys keep
/// their names.
String deriveJourneyDisplayTitle({
  required String storedTitle,
  required TransportMode? transportMode,
  required String? start,
  required String? destination,
  required int? tilesUnlocked,
}) {
  final period = _genericTitlePeriod(storedTitle);
  if (period == null) return storedTitle;

  final noun = transportMode == null ? 'journey' : _modeNoun(transportMode);
  if (destination != null) {
    return destination == start
        ? '$period $noun around $destination'
        : '$period $noun to $destination';
  }
  final tiles = tilesUnlocked ?? 0;
  if (tiles > 0) {
    return 'Explored ${_plural(tiles, 'new tile', 'new tiles')}';
  }
  if (transportMode != null) return '$period $noun';
  return storedTitle;
}

/// Splits [entries] under "This week", "Last week", then one header per month.
List<ProfileFeedSection> groupProfileFeed(
  List<ProfileJourneyEntry> entries, {
  required DateTime now,
}) {
  final thisWeek = startOfProfileWeek(now);
  final lastWeek = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7);
  final sections = <String, List<ProfileJourneyEntry>>{};
  for (final entry in entries) {
    final when = entry.occurredAt;
    final title = !when.isBefore(thisWeek)
        ? 'This week'
        : !when.isBefore(lastWeek)
        ? 'Last week'
        : '${_monthNames[when.month - 1]} ${when.year}';
    sections.putIfAbsent(title, () => <ProfileJourneyEntry>[]).add(entry);
  }
  return <ProfileFeedSection>[
    for (final section in sections.entries)
      ProfileFeedSection(title: section.key, entries: section.value),
  ];
}

/// The last [weeks] weeks of journey and tile totals, oldest first, ending
/// with the week containing [now].
List<WeeklyActivityTotals> buildWeeklyTotals({
  required List<Journey> journeys,
  required List<VisitedPolygonRecord> tileRecords,
  required DateTime now,
  int weeks = 12,
}) {
  final current = startOfProfileWeek(now);
  final distance = List<double>.filled(weeks, 0);
  final duration = List<int>.filled(weeks, 0);
  final tiles = List<int>.filled(weeks, 0);
  final count = List<int>.filled(weeks, 0);

  int? slotFor(DateTime date) {
    final weeksBack =
        (_dayNumber(current) - _dayNumber(startOfProfileWeek(date))) ~/ 7;
    if (weeksBack < 0 || weeksBack >= weeks) return null;
    return weeks - 1 - weeksBack;
  }

  for (final journey in journeys) {
    final slot = slotFor(journey.startTime);
    if (slot == null) continue;
    distance[slot] += journey.distanceMeters;
    duration[slot] += journey.durationSeconds;
    count[slot] += 1;
  }
  // Counted the same way Statistics counts tiles unlocked per week, so the
  // two never disagree.
  for (final record in tileRecords) {
    final slot = slotFor(record.visitedAt);
    if (slot != null) tiles[slot] += 1;
  }

  return <WeeklyActivityTotals>[
    for (var slot = 0; slot < weeks; slot++)
      WeeklyActivityTotals(
        weekStart: DateTime(
          current.year,
          current.month,
          current.day - 7 * (weeks - 1 - slot),
        ),
        distanceMeters: distance[slot],
        durationSeconds: duration[slot],
        newTiles: tiles[slot],
        journeyCount: count[slot],
      ),
  ];
}

/// Consecutive weeks, up to now, with at least one journey.
///
/// The current week is still in progress, so not having travelled yet this
/// week does not break the streak — it counts back from last week instead.
int journeyWeekStreak({
  required List<Journey> journeys,
  required DateTime now,
}) {
  final activeWeeks = <int>{
    for (final journey in journeys)
      _dayNumber(startOfProfileWeek(journey.startTime)),
  };
  var week = startOfProfileWeek(now);
  if (!activeWeeks.contains(_dayNumber(week))) {
    week = DateTime(week.year, week.month, week.day - 7);
  }
  var streak = 0;
  while (activeWeeks.contains(_dayNumber(week))) {
    streak += 1;
    week = DateTime(week.year, week.month, week.day - 7);
  }
  return streak;
}

/// Local midnight on the Monday starting [date]'s week.
DateTime startOfProfileWeek(DateTime date) {
  final local = date.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day - (local.weekday - DateTime.monday),
  );
}

/// Splits a distance into a number and unit for big-number stat display.
({String value, String unit}) formatProfileDistance(double meters) {
  if (meters < 1000) return (value: '${meters.round()}', unit: 'm');
  final km = meters / 1000;
  return (value: km.toStringAsFixed(km < 100 ? 1 : 0), unit: 'km');
}

/// "1h 12m", "7m 7s" or "45s"; seconds are dropped once a duration reaches
/// an hour, or whenever [includeSeconds] is false.
String formatProfileDuration(int seconds, {bool includeSeconds = true}) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  if (!includeSeconds) return '${minutes}m';
  if (minutes > 0) return '${minutes}m ${remainder}s';
  return '${remainder}s';
}

String? _genericTitlePeriod(String title) {
  final words = title.trim().split(RegExp(r'\s+'));
  if (words.length != 2 || words[1] != 'Journey') return null;
  const periods = <String>{'Morning', 'Afternoon', 'Evening'};
  return periods.contains(words[0]) ? words[0] : null;
}

String _modeNoun(TransportMode mode) {
  switch (mode) {
    case TransportMode.walk:
      return 'walk';
    case TransportMode.run:
      return 'run';
    case TransportMode.cycle:
      return 'ride';
    case TransportMode.drive:
      return 'drive';
    case TransportMode.bus:
      return 'bus ride';
    case TransportMode.train:
      return 'train ride';
    case TransportMode.tram:
      return 'tram ride';
    case TransportMode.transit:
      return 'trip';
  }
}

String? _namedPlace(String? name) {
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (trimmed.toLowerCase() == _unnamedLocation) return null;
  return trimmed;
}

String? _placeLabel(String? start, String? end) {
  if (start != null && end != null && start != end) return '$start → $end';
  return end ?? start;
}

Map<int, String> _longestJourneyIdByMonth(List<Journey> journeys) {
  final byMonth = <int, List<Journey>>{};
  for (final journey in journeys) {
    byMonth.putIfAbsent(_monthKey(journey.startTime), () => []).add(journey);
  }
  final longest = <int, String>{};
  for (final entry in byMonth.entries) {
    // A month with one journey has nothing to beat.
    if (entry.value.length < 2) continue;
    Journey? best;
    for (final journey in entry.value) {
      if (journey.distanceMeters <= 0) continue;
      if (best == null ||
          journey.distanceMeters > best.distanceMeters ||
          (journey.distanceMeters == best.distanceMeters &&
              journey.startTime.isBefore(best.startTime))) {
        best = journey;
      }
    }
    if (best != null) longest[entry.key] = best.id;
  }
  return longest;
}

String? _mostTilesJourneyId(List<Journey> journeys) {
  if (journeys.length < 2) return null;
  Journey? best;
  for (final journey in journeys) {
    if (journey.tilesUnlocked <= 0) continue;
    if (best == null ||
        journey.tilesUnlocked > best.tilesUnlocked ||
        (journey.tilesUnlocked == best.tilesUnlocked &&
            journey.startTime.isBefore(best.startTime))) {
      best = journey;
    }
  }
  return best?.id;
}

int _monthKey(DateTime date) {
  final local = date.toLocal();
  return local.year * 12 + local.month;
}

int _dayNumber(DateTime date) {
  return DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

int? _secondsBetween(DateTime? start, DateTime? end) {
  if (start == null || end == null) return null;
  final seconds = end.difference(start).inSeconds;
  return seconds < 0 ? null : seconds;
}

String _plural(int count, String singular, String plural) {
  return '$count ${count == 1 ? singular : plural}';
}

/// Values recovered from an activity's stored display metrics, for posts
/// whose source journey is not in the loaded history.
class _ParsedMetrics {
  const _ParsedMetrics({this.durationSeconds, this.tiles, this.xp});

  factory _ParsedMetrics.from(List<ActivityFeedMetric> metrics) {
    int? durationSeconds;
    int? tiles;
    int? xp;
    for (final metric in metrics) {
      final label = metric.label.toLowerCase();
      if (label.contains('time') || label.contains('duration')) {
        durationSeconds = _parseDuration(metric.value);
      } else if (label.contains('tile')) {
        tiles = _parseInt(metric.value);
      } else if (label.contains('xp')) {
        xp = _parseInt(metric.value);
      }
    }
    return _ParsedMetrics(
      durationSeconds: durationSeconds,
      tiles: tiles,
      xp: xp,
    );
  }

  final int? durationSeconds;
  final int? tiles;
  final int? xp;

  static int? _parseDuration(String value) {
    final parts = RegExp(r'(\d+)\s*([hms])').allMatches(value.toLowerCase());
    if (parts.isEmpty) return null;
    var seconds = 0;
    for (final part in parts) {
      final amount = int.parse(part.group(1)!);
      seconds += switch (part.group(2)) {
        'h' => amount * 3600,
        'm' => amount * 60,
        _ => amount,
      };
    }
    return seconds;
  }

  static int? _parseInt(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }
}
