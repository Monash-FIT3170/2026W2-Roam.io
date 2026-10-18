import 'dart:async';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/hazards/data/hazard_controller.dart';
import 'package:roam_io/features/hazards/data/hazard_repository.dart';
import 'package:roam_io/features/hazards/domain/hazard_category.dart';
import 'package:roam_io/features/hazards/domain/hazard_report.dart';
import 'package:roam_io/features/hazards/domain/hazard_submission_exception.dart';
import 'package:roam_io/features/hazards/presentation/hazard_marker_builder.dart';
import 'package:roam_io/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'realtime reports render and the nearest expiry removes markers',
    () async {
      var now = DateTime.utc(2026, 9, 15, 4);
      final repository = _RecordingHazardRepository();
      _ManualTimer? timer;
      final controller = HazardController(
        repository: repository,
        markerBuilder: _FakeMarkerBuilder(),
        clock: () => now,
        expiryDuration: const Duration(seconds: 10),
        timerFactory: (duration, callback) {
          timer = _ManualTimer(duration, callback);
          return timer!;
        },
      );
      await controller.initialise();
      final report = _report(expiresAt: now.add(const Duration(seconds: 10)));

      repository.stream.add([report]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.activeReports, [report]);
      expect(controller.markers.single.markerId.value, 'hazard_hazard-1');
      expect(timer!.duration, const Duration(seconds: 10));

      now = now.add(const Duration(seconds: 10));
      timer!.fire();
      expect(controller.activeReports, isEmpty);
      expect(controller.markers, isEmpty);

      await controller.disposeController();
      controller.dispose();
      await repository.close();
    },
  );

  test('non-expired hazards remain after pruning', () async {
    var now = DateTime.utc(2026, 9, 15, 4);
    final repository = _RecordingHazardRepository();
    final controller = HazardController(
      repository: repository,
      markerBuilder: _FakeMarkerBuilder(),
      clock: () => now,
      timerFactory: (duration, callback) => _ManualTimer(duration, callback),
    );
    await controller.initialise();
    repository.stream.add([
      _report(expiresAt: now.add(const Duration(minutes: 1))),
    ]);
    await Future<void>.delayed(Duration.zero);

    now = now.add(const Duration(seconds: 30));
    controller.pruneExpired();
    expect(controller.activeReports, hasLength(1));

    await controller.disposeController();
    controller.dispose();
    await repository.close();
  });

  test(
    'confirmation uses configured expiry and ignores a rapid duplicate',
    () async {
      final now = DateTime.utc(2026, 9, 15, 4);
      final repository = _RecordingHazardRepository()..holdConfirmation = true;
      final controller = HazardController(
        repository: repository,
        markerBuilder: _FakeMarkerBuilder(),
        clock: () => now,
        expiryDuration: const Duration(seconds: 10),
      );
      final report = _report(expiresAt: now.add(const Duration(seconds: 5)));

      final first = controller.confirmHazard(report);
      final second = controller.confirmHazard(report);
      await second;
      expect(repository.confirmCalls, 1);
      expect(repository.confirmedAt, now);
      expect(repository.confirmExpiry, const Duration(seconds: 10));
      repository.completeConfirmation();
      await first;

      await controller.disposeController();
      controller.dispose();
      await repository.close();
    },
  );

  test('failed persistence cleans up an uploaded hazard photo', () async {
    final repository = _RecordingHazardRepository()..failCreation = true;
    String? deletedPath;
    final storage = StorageService(
      hazardPhotoUploadOverride:
          ({required uid, required bytes, required filename}) async =>
              const HazardPhotoUploadResult(
                url: 'https://test/photo.jpg',
                storagePath: 'hazard_photos/user-1/photo.jpg',
              ),
      hazardPhotoDeleteOverride: ({required storagePath}) async {
        deletedPath = storagePath;
      },
    );
    final controller = HazardController(
      repository: repository,
      storageService: storage,
      markerBuilder: _FakeMarkerBuilder(),
    );

    await expectLater(
      controller.createHazard(
        reporterId: 'user-1',
        category: HazardCategory.roadworks,
        latitude: -37.81,
        longitude: 144.96,
        photoBytes: Uint8List.fromList([1, 2, 3]),
        photoFilename: 'road.jpg',
      ),
      throwsA(
        isA<HazardSubmissionException>().having(
          (error) => error.failure,
          'failure',
          HazardSubmissionFailure.save,
        ),
      ),
    );
    expect(deletedPath, 'hazard_photos/user-1/photo.jpg');

    controller.dispose();
    await repository.close();
  });

  test(
    'photo upload failure is specific and a no-photo retry can succeed',
    () async {
      final repository = _RecordingHazardRepository();
      var uploadCalls = 0;
      final storage = StorageService(
        hazardPhotoUploadOverride:
            ({required uid, required bytes, required filename}) async {
              uploadCalls++;
              throw StateError('upload unavailable');
            },
      );
      final controller = HazardController(
        repository: repository,
        storageService: storage,
        markerBuilder: _FakeMarkerBuilder(),
      );

      await expectLater(
        controller.createHazard(
          reporterId: 'user-1',
          category: HazardCategory.flooding,
          latitude: -37.81,
          longitude: 144.96,
          photoBytes: Uint8List.fromList([1, 2, 3]),
          photoFilename: 'flood.jpg',
        ),
        throwsA(
          isA<HazardSubmissionException>().having(
            (error) => error.failure,
            'failure',
            HazardSubmissionFailure.photoUpload,
          ),
        ),
      );

      final retry = await controller.createHazard(
        reporterId: 'user-1',
        category: HazardCategory.flooding,
        latitude: -37.81,
        longitude: 144.96,
      );
      expect(retry.category, HazardCategory.flooding);
      expect(uploadCalls, 1);

      await controller.disposeController();
      controller.dispose();
      await repository.close();
    },
  );

  test(
    'creation forwards selected category, description, and GPS coordinates',
    () async {
      final repository = _RecordingHazardRepository();
      final controller = HazardController(
        repository: repository,
        markerBuilder: _FakeMarkerBuilder(),
        clock: () => DateTime.utc(2026, 9, 15, 4),
        expiryDuration: const Duration(seconds: 10),
      );
      await controller.initialise();

      final created = await controller.createHazard(
        reporterId: 'user-1',
        category: HazardCategory.slipperySurface,
        latitude: -37.8123,
        longitude: 144.9654,
        description: 'Loose gravel',
      );

      expect(repository.createdCategory, HazardCategory.slipperySurface);
      expect(repository.createdLatitude, -37.8123);
      expect(repository.createdLongitude, 144.9654);
      expect(repository.createdDescription, 'Loose gravel');
      expect(controller.activeReports, [created]);
      expect(controller.markers.single.position, created.location);

      // An older/empty stream event must not remove a successfully persisted
      // local report while Firestore catches up.
      repository.stream.add(const []);
      await Future<void>.delayed(Duration.zero);
      expect(controller.activeReports, [created]);

      // Once Firestore publishes the document it becomes the canonical source.
      repository.stream.add([created]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.activeReports, [created]);
      expect(controller.markers, hasLength(1));

      await controller.disposeController();
      controller.dispose();
      await repository.close();
    },
  );

  test(
    'marker preload failure does not prevent realtime subscription',
    () async {
      final now = DateTime.utc(2026, 9, 15, 4);
      final repository = _RecordingHazardRepository();
      final controller = HazardController(
        repository: repository,
        markerBuilder: _FailingPreloadMarkerBuilder(),
        clock: () => now,
      );

      await controller.initialise();
      final report = _report(expiresAt: now.add(const Duration(minutes: 1)));
      repository.stream.add([report]);
      await Future<void>.delayed(Duration.zero);

      expect(controller.activeReports, [report]);
      expect(controller.markers.single.markerId.value, 'hazard_hazard-1');

      await controller.disposeController();
      controller.dispose();
      await repository.close();
    },
  );
}

HazardReport _report({required DateTime expiresAt}) {
  final createdAt = expiresAt.subtract(const Duration(seconds: 10));
  return HazardReport(
    id: 'hazard-1',
    reporterId: 'user-1',
    category: HazardCategory.crash,
    latitude: -37.81,
    longitude: 144.96,
    createdAt: createdAt,
    lastConfirmedAt: createdAt,
    expiresAt: expiresAt,
  );
}

class _FakeMarkerBuilder extends HazardMarkerBuilder {
  @override
  Future<void> preload() async {}

  @override
  Marker build(
    HazardReport report, {
    required void Function(HazardReport report) onTap,
  }) {
    return Marker(
      markerId: MarkerId('hazard_${report.id}'),
      position: report.location,
      onTap: () => onTap(report),
    );
  }
}

class _FailingPreloadMarkerBuilder extends _FakeMarkerBuilder {
  @override
  Future<void> preload() async {
    throw StateError('bitmap generation unavailable');
  }
}

class _RecordingHazardRepository extends HazardRepository {
  _RecordingHazardRepository() : super(firestore: FakeFirebaseFirestore());

  final stream = StreamController<List<HazardReport>>.broadcast();
  bool failCreation = false;
  bool holdConfirmation = false;
  int confirmCalls = 0;
  DateTime? confirmedAt;
  Duration? confirmExpiry;
  Completer<void>? _confirmationCompleter;
  HazardCategory? createdCategory;
  double? createdLatitude;
  double? createdLongitude;
  String? createdDescription;

  @override
  Stream<List<HazardReport>> watchActiveHazards({required DateTime cutoff}) {
    return stream.stream;
  }

  @override
  Future<HazardReport> createHazard({
    required String reporterId,
    required HazardCategory category,
    required double latitude,
    required double longitude,
    required DateTime createdAt,
    required Duration expiryDuration,
    String? description,
    String? photoUrl,
    String? photoStoragePath,
  }) async {
    if (failCreation) throw StateError('database failed');
    createdCategory = category;
    createdLatitude = latitude;
    createdLongitude = longitude;
    createdDescription = description;
    return HazardReport(
      id: 'created',
      reporterId: reporterId,
      category: category,
      latitude: latitude,
      longitude: longitude,
      description: description,
      photoUrl: photoUrl,
      photoStoragePath: photoStoragePath,
      createdAt: createdAt,
      lastConfirmedAt: createdAt,
      expiresAt: createdAt.add(expiryDuration),
    );
  }

  @override
  Future<void> confirmHazard({
    required String hazardId,
    required DateTime confirmedAt,
    required Duration expiryDuration,
  }) {
    confirmCalls++;
    this.confirmedAt = confirmedAt;
    confirmExpiry = expiryDuration;
    if (!holdConfirmation) return Future.value();
    _confirmationCompleter = Completer<void>();
    return _confirmationCompleter!.future;
  }

  void completeConfirmation() => _confirmationCompleter!.complete();

  Future<void> close() => stream.close();
}

class _ManualTimer implements Timer {
  _ManualTimer(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}
