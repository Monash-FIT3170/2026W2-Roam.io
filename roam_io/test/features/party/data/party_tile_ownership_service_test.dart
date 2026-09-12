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

  test('a tile below the claim gate has no owner', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('parties')
        .doc('p1')
        .collection('tiles')
        .doc('t1')
        .set({'teamADwellSeconds': 15, 'teamBDwellSeconds': 0});
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

  test('watchTileData emits PartyTileData objects with dwell stats', () async {
    final firestore = FakeFirebaseFirestore();
    final tileRef = firestore
        .collection('parties')
        .doc('p1')
        .collection('tiles')
        .doc('t1');
    await tileRef.set({
      'teamADwellSeconds': 150,
      'teamBDwellSeconds': 75,
      'lastPingByUser': {
        'u1': {'team': 'A', 'pingAt': '2026-09-12T10:00:00.000Z'},
      },
    });
    final service = PartyTileOwnershipService(firestore: firestore);

    final data = await service.watchTileData('p1').first;

    expect(data['t1'], isNotNull);
    expect(data['t1']!.teamADwellSeconds, 150.0);
    expect(data['t1']!.teamBDwellSeconds, 75.0);
    expect(data['t1']!.teamDwellSeconds('A'), 150.0);
    expect(data['t1']!.teamDwellSeconds('B'), 75.0);
    expect(data['t1']!.owningTeam, 'A');
  });
}
