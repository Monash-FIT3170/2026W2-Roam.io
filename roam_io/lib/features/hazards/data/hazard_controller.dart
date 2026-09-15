import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/storage_service.dart';
import '../domain/hazard_category.dart';
import '../domain/hazard_config.dart';
import '../domain/hazard_report.dart';
import '../domain/hazard_submission_exception.dart';
import '../presentation/hazard_marker_builder.dart';
import 'hazard_repository.dart';

typedef HazardClock = DateTime Function();
typedef HazardTimerFactory =
    Timer Function(Duration duration, void Function() callback);

/// Owns live hazard state without coupling Firestore queries to map widgets.
class HazardController extends ChangeNotifier {
  HazardController({
    HazardRepository? repository,
    StorageService? storageService,
    HazardMarkerBuilder? markerBuilder,
    Duration expiryDuration = HazardConfig.expiryDuration,
    HazardClock? clock,
    HazardTimerFactory? timerFactory,
  }) : _repository = repository ?? HazardRepository(),
       _storageService = storageService ?? StorageService(),
       _markerBuilder = markerBuilder ?? HazardMarkerBuilder(),
       _expiryDuration = expiryDuration,
       _clock = clock ?? DateTime.now,
       _timerFactory =
           timerFactory ?? ((duration, callback) => Timer(duration, callback));

  final HazardRepository _repository;
  final StorageService _storageService;
  final HazardMarkerBuilder _markerBuilder;
  final Duration _expiryDuration;
  final HazardClock _clock;
  final HazardTimerFactory _timerFactory;

  StreamSubscription<List<HazardReport>>? _subscription;
  Timer? _expiryTimer;
  List<HazardReport> _streamReports = const [];
  final Map<String, HazardReport> _locallyCreatedReports = {};
  List<HazardReport> _sourceReports = const [];
  List<HazardReport> _activeReports = const [];
  Set<Marker> _markers = const {};
  final Set<String> _confirmingIds = {};
  bool _isDisposed = false;
  bool _didLogExpiryConfiguration = false;

  void Function(HazardReport report)? onHazardTapped;

  List<HazardReport> get activeReports => List.unmodifiable(_activeReports);
  Set<Marker> get markers => Set.unmodifiable(_markers);
  Duration get expiryDuration => _expiryDuration;

  Future<void> initialise() async {
    if (kDebugMode && !_didLogExpiryConfiguration) {
      _didLogExpiryConfiguration = true;
      debugPrint(
        '[HazardController] Effective hazard expiry: '
        '${_expiryDuration.inSeconds} seconds',
      );
    }
    await _subscription?.cancel();
    if (_isDisposed) return;

    // Start receiving data before preparing custom icons. Marker rendering can
    // safely use its default descriptor while icons are loading, so a bitmap
    // failure must never prevent the realtime hazard subscription from starting.
    _subscription = _repository
        .watchActiveHazards(cutoff: _clock())
        .listen(_handleReports, onError: _handleStreamError);

    try {
      await _markerBuilder.preload();
    } catch (error, stackTrace) {
      debugPrint('[HazardController] Hazard marker preload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (!_isDisposed) pruneExpired();
  }

  void _handleReports(List<HazardReport> reports) {
    _streamReports = reports;
    final streamedIds = reports.map((report) => report.id).toSet();
    _locallyCreatedReports.removeWhere((id, _) => streamedIds.contains(id));
    pruneExpired();
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    debugPrint('[HazardController] Hazard stream failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  @visibleForTesting
  void pruneExpired() {
    if (_isDisposed) return;
    final now = _clock();
    _locallyCreatedReports.removeWhere((_, report) => !report.isActiveAt(now));
    final reportsById = <String, HazardReport>{
      for (final report in _streamReports) report.id: report,
      ..._locallyCreatedReports,
    };
    _sourceReports = reportsById.values.toList(growable: false);
    _activeReports = _sourceReports
        .where((report) => report.isActiveAt(now))
        .toList(growable: false);
    _markers = _activeReports
        .map(
          (report) => _markerBuilder.build(
            report,
            onTap: (selected) => onHazardTapped?.call(selected),
          ),
        )
        .toSet();
    if (kDebugMode) {
      debugPrint(
        '[HazardController] Active hazards after expiry filtering: '
        '${_activeReports.length}; generated markers: ${_markers.length}',
      );
    }
    _scheduleNextExpiry(now);
    notifyListeners();
  }

  void _scheduleNextExpiry(DateTime now) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (_activeReports.isEmpty) return;
    final nextExpiry = _activeReports
        .map((report) => report.expiresAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = nextExpiry.difference(now);
    _expiryTimer = _timerFactory(
      delay.isNegative ? Duration.zero : delay,
      pruneExpired,
    );
  }

  Future<HazardReport> createHazard({
    required String reporterId,
    required HazardCategory category,
    required double latitude,
    required double longitude,
    String? description,
    Uint8List? photoBytes,
    String? photoFilename,
  }) async {
    HazardPhotoUploadResult? uploadedPhoto;
    if (photoBytes != null && photoFilename != null) {
      try {
        uploadedPhoto = await _storageService.uploadHazardPhoto(
          uid: reporterId,
          bytes: photoBytes,
          filename: photoFilename,
        );
      } catch (error, stackTrace) {
        debugPrint('[HazardController] Photo upload failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        throw HazardSubmissionException(
          HazardSubmissionFailure.photoUpload,
          cause: error,
        );
      }
    }

    late final HazardReport report;
    try {
      report = await _repository.createHazard(
        reporterId: reporterId,
        category: category,
        latitude: latitude,
        longitude: longitude,
        description: description,
        photoUrl: uploadedPhoto?.url,
        photoStoragePath: uploadedPhoto?.storagePath,
        createdAt: _clock(),
        expiryDuration: _expiryDuration,
      );
    } catch (error, stackTrace) {
      debugPrint('[HazardController] Firestore hazard creation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (uploadedPhoto != null) {
        try {
          await _storageService.deleteHazardPhoto(
            storagePath: uploadedPhoto.storagePath,
          );
        } catch (cleanupError, cleanupStackTrace) {
          debugPrint('[HazardController] Photo cleanup failed: $cleanupError');
          debugPrintStack(stackTrace: cleanupStackTrace);
        }
      }
      throw HazardSubmissionException(
        HazardSubmissionFailure.save,
        cause: error,
      );
    }

    if (!_streamReports.any((streamed) => streamed.id == report.id)) {
      _locallyCreatedReports[report.id] = report;
    }
    pruneExpired();
    return report;
  }

  Future<void> confirmHazard(HazardReport report) async {
    if (!_confirmingIds.add(report.id)) return;
    try {
      await _repository.confirmHazard(
        hazardId: report.id,
        confirmedAt: _clock(),
        expiryDuration: _expiryDuration,
      );
    } finally {
      _confirmingIds.remove(report.id);
    }
  }

  Future<void> disposeController() async {
    _isDisposed = true;
    _expiryTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }
}
