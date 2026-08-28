import '../../../notifications/models/app_notification.dart';
import '../../../notifications/models/notification_type.dart';
import '../../../notifications/services/android_notification_service.dart';
import '../../profile/domain/visited_polygon_meta.dart';
import 'fog_decay_difficulty.dart';
import 'fog_decay_service.dart';

typedef FogWarningSchedule =
    Future<bool> Function(
      AppNotification notification, {
      required DateTime scheduledAt,
    });
typedef FogWarningCancel = Future<void> Function(String notificationId);

/// A batched warning for regions sharing approximately the same decay date.
class FogDecayWarning {
  const FogDecayWarning({
    required this.notificationId,
    required this.warningAt,
    required this.decayAt,
    required this.locationCount,
  });

  final String notificationId;
  final DateTime warningAt;
  final DateTime decayAt;
  final int locationCount;
}

/// Builds and replaces a bounded set of fog-decay device warnings.
class FogDecayWarningService {
  FogDecayWarningService({
    FogDecayService fogDecayService = const FogDecayService(),
    FogWarningSchedule? schedule,
    FogWarningCancel? cancel,
  }) : _fogDecayService = fogDecayService,
       _schedule = schedule ?? AndroidNotificationService.instance.schedule,
       _cancel = cancel ?? AndroidNotificationService.instance.cancelById;

  static const Duration warningLeadTime = Duration(days: 7);
  static const int maximumScheduledWarnings = 32;
  static const String _notificationIdPrefix = 'fog-decay-warning';

  final FogDecayService _fogDecayService;
  final FogWarningSchedule _schedule;
  final FogWarningCancel _cancel;

  /// Groups warnings by UTC day and caps them to avoid one alarm per tile.
  List<FogDecayWarning> buildWarnings({
    required Iterable<VisitedPolygonMeta> locations,
    required FogDecayDifficulty difficulty,
    required DateTime now,
  }) {
    final grouped = <DateTime, _WarningGroup>{};

    for (final location in locations) {
      final decayAt = _fogDecayService.calculateDecayDate(
        lastExploredAt: location.lastEnteredAt ?? location.visitedAt,
        difficulty: difficulty,
      );
      if (!now.isBefore(decayAt)) continue;

      final calculatedWarningAt = decayAt.subtract(warningLeadTime);
      final warningAt = calculatedWarningAt.isAfter(now)
          ? calculatedWarningAt
          : now.add(const Duration(seconds: 1));
      final utc = warningAt.toUtc();
      final day = DateTime.utc(utc.year, utc.month, utc.day);
      final group = grouped.putIfAbsent(
        day,
        () => _WarningGroup(warningAt: warningAt, decayAt: decayAt),
      );
      group
        ..locationCount += 1
        ..warningAt = warningAt.isBefore(group.warningAt)
            ? warningAt
            : group.warningAt
        ..decayAt = decayAt.isBefore(group.decayAt) ? decayAt : group.decayAt;
    }

    final groups = grouped.values.toList()
      ..sort((a, b) => a.warningAt.compareTo(b.warningAt));
    return <FogDecayWarning>[
      for (
        var index = 0;
        index < groups.length && index < maximumScheduledWarnings;
        index++
      )
        FogDecayWarning(
          notificationId: '$_notificationIdPrefix-$index',
          warningAt: groups[index].warningAt,
          decayAt: groups[index].decayAt,
          locationCount: groups[index].locationCount,
        ),
    ];
  }

  /// Cancels stale slots before scheduling the newly calculated batches.
  Future<void> refreshWarnings({
    required Iterable<VisitedPolygonMeta> locations,
    required FogDecayDifficulty difficulty,
    required DateTime now,
  }) async {
    final warnings = buildWarnings(
      locations: locations,
      difficulty: difficulty,
      now: now,
    );

    for (var index = 0; index < maximumScheduledWarnings; index++) {
      await _cancel('$_notificationIdPrefix-$index');
    }

    for (final warning in warnings) {
      await _schedule(
        AppNotification(
          id: warning.notificationId,
          type: NotificationType.fogDecay,
          title: 'Fog returning soon',
          body: warning.locationCount == 1
              ? 'An explored area will become covered by fog in about one week. Revisit it to keep it uncovered.'
              : '${warning.locationCount} explored areas will become covered by fog in about one week. Revisit them to keep them uncovered.',
          timestamp: now,
          showInApp: false,
          data: <String, String>{
            'decayAt': warning.decayAt.toUtc().toIso8601String(),
            'locationCount': '${warning.locationCount}',
          },
        ),
        scheduledAt: warning.warningAt,
      );
    }
  }
}

class _WarningGroup {
  _WarningGroup({required this.warningAt, required this.decayAt});

  DateTime warningAt;
  DateTime decayAt;
  int locationCount = 0;
}
