import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/hazards/data/hazard_repository.dart';
import 'package:roam_io/features/hazards/domain/hazard_category.dart';

void main() {
  test('creates, streams, and confirms the same hazard document', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = HazardRepository(firestore: firestore);
    final now = DateTime.utc(2026, 9, 15, 4);

    final report = await repository.createHazard(
      reporterId: 'user-1',
      category: HazardCategory.pothole,
      latitude: -37.8136,
      longitude: 144.9631,
      description: '  Deep pothole  ',
      photoUrl: 'https://test/photo.jpg',
      photoStoragePath: 'hazard_photos/user-1/photo.jpg',
      createdAt: now,
      expiryDuration: const Duration(seconds: 10),
    );

    final active = await repository.watchActiveHazards(cutoff: now).first;
    expect(active.single.id, report.id);
    expect(active.single.description, 'Deep pothole');
    expect(active.single.latitude, -37.8136);
    expect(active.single.photoStoragePath, 'hazard_photos/user-1/photo.jpg');

    final confirmedAt = now.add(const Duration(seconds: 8));
    await repository.confirmHazard(
      hazardId: report.id,
      confirmedAt: confirmedAt,
      expiryDuration: const Duration(seconds: 10),
    );

    final documents = await firestore.collection('hazards').get();
    expect(documents.docs, hasLength(1));
    final confirmed = documents.docs.single.data();
    expect(
      confirmed['lastConfirmedAt'].toDate().isAtSameMomentAs(confirmedAt),
      isTrue,
    );
    expect(
      confirmed['expiresAt'].toDate().isAtSameMomentAs(
        confirmedAt.add(const Duration(seconds: 10)),
      ),
      isTrue,
    );
  });

  test('active stream excludes hazards before its cutoff', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = HazardRepository(firestore: firestore);
    final now = DateTime.utc(2026, 9, 15, 4);
    await repository.createHazard(
      reporterId: 'user-1',
      category: HazardCategory.crash,
      latitude: 0,
      longitude: 0,
      createdAt: now.subtract(const Duration(minutes: 2)),
      expiryDuration: const Duration(minutes: 1),
    );

    expect(await repository.watchActiveHazards(cutoff: now).first, isEmpty);
  });
}
