import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/party/data/party_tile_ownership_service.dart';

void main() {
  test('watchOwnership emits an empty map when a party has no tiles', () async {
    final service = PartyTileOwnershipService(
      firestore: FakeFirebaseFirestore(),
    );

    final ownership = await service.watchOwnership('p1').first;

    expect(ownership, isEmpty);
  });

  test('a tile below the 5-minute gate has no owner', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('parties')
        .doc('p1')
        .collection('tiles')
        .doc('t1')
        .set({'teamADwellSeconds': 60, 'teamBDwellSeconds': 0});
    final service = PartyTileOwnershipService(firestore: firestore);

    final ownership = await service.watchOwnership('p1').first;

    expect(ownership['t1'], isNull);
  });

  test('a tile past the gate for one team returns that team', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('parties')
        .doc('p1')
        .collection('tiles')
        .doc('t1')
        .set({'teamADwellSeconds': 400, 'teamBDwellSeconds': 0});
    final service = PartyTileOwnershipService(firestore: firestore);

    final ownership = await service.watchOwnership('p1').first;

    expect(ownership['t1'], 'A');
  });

  test('the stream live-updates when a tile flips ownership', () async {
    final firestore = FakeFirebaseFirestore();
    final tileRef = firestore
        .collection('parties')
        .doc('p1')
        .collection('tiles')
        .doc('t1');
    await tileRef.set({'teamADwellSeconds': 400, 'teamBDwellSeconds': 0});
    final service = PartyTileOwnershipService(firestore: firestore);

    final emissions = <Map<String, String?>>[];
    final subscription = service.watchOwnership('p1').listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    await tileRef.set({'teamADwellSeconds': 400, 'teamBDwellSeconds': 500});
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(emissions.first['t1'], 'A');
    expect(emissions.last['t1'], 'B');
  });
}
