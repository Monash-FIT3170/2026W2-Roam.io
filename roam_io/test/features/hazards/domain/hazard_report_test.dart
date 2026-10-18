import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/hazards/domain/hazard_category.dart';
import 'package:roam_io/features/hazards/domain/hazard_config.dart';
import 'package:roam_io/features/hazards/domain/hazard_report.dart';
import 'package:roam_io/features/hazards/domain/hazard_submission_exception.dart';

void main() {
  test('categories have stable unique IDs and distinct icons', () {
    expect(HazardCategory.values.map((value) => value.id).toSet(), {
      'crash',
      'pothole',
      'roadworks',
      'obstruction',
      'flooding',
      'slippery_surface',
    });
    expect(
      HazardCategory.values.map((value) => value.icon.codePoint).toSet(),
      hasLength(HazardCategory.values.length),
    );
  });

  test('production expiry defaults to twelve hours', () {
    expect(HazardConfig.expiryDuration, const Duration(hours: 12));
  });

  test('location errors map to actionable messages', () {
    expect(
      HazardSubmissionException.fromLocationError(
        Exception('Location services are disabled'),
      ).failure,
      HazardSubmissionFailure.locationServicesDisabled,
    );
    expect(
      HazardSubmissionException.fromLocationError(
        Exception('Location permission denied'),
      ).failure,
      HazardSubmissionFailure.locationPermissionDenied,
    );
    expect(
      HazardSubmissionException.fromLocationError(
        Exception('The location service on the device is disabled.'),
      ).userMessage,
      'Please enable location services to report a hazard.',
    );
    expect(
      HazardSubmissionException.fromLocationError(
        Exception('Location permission permanently denied'),
      ).userMessage,
      'Please grant location permission to report a hazard.',
    );
    expect(
      HazardSubmissionException.fromLocationError(
        Exception('Could not get current or last known location'),
      ).userMessage,
      'Could not get your current location.',
    );
  });

  test('serializes and restores optional report fields', () async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2026, 9, 15, 4);
    final report = HazardReport(
      id: 'hazard-1',
      reporterId: 'user-1',
      category: HazardCategory.flooding,
      latitude: -37.81,
      longitude: 144.96,
      description: 'Water over the road',
      photoUrl: 'https://test/photo.jpg',
      photoStoragePath: 'hazard_photos/user-1/photo.jpg',
      createdAt: now,
      lastConfirmedAt: now,
      expiresAt: now.add(const Duration(hours: 12)),
    );
    await firestore
        .collection('hazards')
        .doc(report.id)
        .set(report.toFirestore());

    final snapshot = await firestore.collection('hazards').doc(report.id).get();
    final restored = HazardReport.fromFirestore(snapshot);

    expect(restored.category, HazardCategory.flooding);
    expect(restored.description, 'Water over the road');
    expect(restored.photoUrl, 'https://test/photo.jpg');
    expect(restored.location.latitude, -37.81);
    expect(
      restored.expiresAt.isAtSameMomentAs(now.add(const Duration(hours: 12))),
      isTrue,
    );
    expect(snapshot.data()!['createdAt'], isA<Timestamp>());
  });
}
