import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/map/fog/fog_decay_difficulty.dart';
import 'package:roam_io/features/map/fog/fog_decay_warning_service.dart';
import 'package:roam_io/features/profile/domain/visited_polygon_meta.dart';
import 'package:roam_io/notifications/models/app_notification.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);

  test('warning is scheduled seven days before decay', () {
    final service = FogDecayWarningService(
      schedule: _unusedSchedule,
      cancel: _unusedCancel,
    );

    final warnings = service.buildWarnings(
      locations: <VisitedPolygonMeta>[_location('a', DateTime.utc(2026, 1, 1))],
      difficulty: FogDecayDifficulty.monthly,
      now: now,
    );

    expect(warnings.single.decayAt, DateTime.utc(2026, 1, 31));
    expect(warnings.single.warningAt, DateTime.utc(2026, 1, 24));
  });

  test('locations due on the same day are batched into one warning', () {
    final service = FogDecayWarningService(
      schedule: _unusedSchedule,
      cancel: _unusedCancel,
    );

    final warnings = service.buildWarnings(
      locations: <VisitedPolygonMeta>[
        _location('a', DateTime.utc(2026, 1, 1, 8)),
        _location('b', DateTime.utc(2026, 1, 1, 17)),
      ],
      difficulty: FogDecayDifficulty.monthly,
      now: now,
    );

    expect(warnings, hasLength(1));
    expect(warnings.single.locationCount, 2);
  });

  test('refresh cancels stale slots and does not create duplicates', () async {
    final scheduled = <String>[];
    final cancelled = <String>[];
    final service = FogDecayWarningService(
      schedule: (notification, {required scheduledAt}) async {
        scheduled.add(notification.id);
        return true;
      },
      cancel: (id) async => cancelled.add(id),
    );
    final locations = <VisitedPolygonMeta>[
      _location('a', DateTime.utc(2026, 1, 1)),
    ];

    await service.refreshWarnings(
      locations: locations,
      difficulty: FogDecayDifficulty.monthly,
      now: now,
    );
    await service.refreshWarnings(
      locations: locations,
      difficulty: FogDecayDifficulty.monthly,
      now: now,
    );

    expect(scheduled, <String>['fog-decay-warning-0', 'fog-decay-warning-0']);
    expect(cancelled.where((id) => id == 'fog-decay-warning-0'), hasLength(2));
  });

  test('revisit and difficulty change recalculate the warning date', () {
    final service = FogDecayWarningService(
      schedule: _unusedSchedule,
      cancel: _unusedCancel,
    );
    final original = _location('a', DateTime.utc(2026, 1, 1));
    final revisited = VisitedPolygonMeta(
      polygonId: 'a',
      visitedAt: original.visitedAt,
      lastEnteredAt: DateTime.utc(2026, 1, 20),
    );

    final originalWarning = service
        .buildWarnings(
          locations: <VisitedPolygonMeta>[original],
          difficulty: FogDecayDifficulty.monthly,
          now: now,
        )
        .single;
    final revisitWarning = service
        .buildWarnings(
          locations: <VisitedPolygonMeta>[revisited],
          difficulty: FogDecayDifficulty.monthly,
          now: now,
        )
        .single;
    final yearlyWarning = service
        .buildWarnings(
          locations: <VisitedPolygonMeta>[revisited],
          difficulty: FogDecayDifficulty.yearly,
          now: now,
        )
        .single;

    expect(revisitWarning.warningAt.isAfter(originalWarning.warningAt), isTrue);
    expect(yearlyWarning.warningAt.isAfter(revisitWarning.warningAt), isTrue);
  });

  test('denied notification permission is handled without throwing', () async {
    final service = FogDecayWarningService(
      schedule: (notification, {required scheduledAt}) async => false,
      cancel: _unusedCancel,
    );

    await expectLater(
      service.refreshWarnings(
        locations: <VisitedPolygonMeta>[
          _location('a', DateTime.utc(2026, 1, 1)),
        ],
        difficulty: FogDecayDifficulty.monthly,
        now: now,
      ),
      completes,
    );
  });
}

VisitedPolygonMeta _location(String id, DateTime visitedAt) {
  return VisitedPolygonMeta(
    polygonId: id,
    visitedAt: visitedAt,
    lastEnteredAt: visitedAt,
  );
}

Future<bool> _unusedSchedule(
  AppNotification notification, {
  required DateTime scheduledAt,
}) async => true;

Future<void> _unusedCancel(String id) async {}
