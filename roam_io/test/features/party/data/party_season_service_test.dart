import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/party/data/party_season_service.dart';

void main() {
  test('watchSeasons emits a persisted season summary', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('parties')
        .doc('p1')
        .collection('seasons')
        .doc('s1')
        .set({
          'teamAMembers': ['u1'],
          'teamBMembers': ['u2'],
          'teamATileCount': 5,
          'teamBTileCount': 2,
          'winner': 'A',
          'startAt': '2026-08-26T00:00:00.000Z',
          'endAt': '2026-09-09T00:00:00.000Z',
        });
    final service = PartySeasonService(firestore: firestore);

    final seasons = await service.watchSeasons('p1').first;

    expect(seasons, hasLength(1));
    expect(seasons.single.teamAMembers, ['u1']);
    expect(seasons.single.teamBMembers, ['u2']);
    expect(seasons.single.teamATileCount, 5);
    expect(seasons.single.teamBTileCount, 2);
    expect(seasons.single.winner, 'A');
  });

  test('watchSeasons orders newest season first', () async {
    final firestore = FakeFirebaseFirestore();
    final seasonsRef = firestore
        .collection('parties')
        .doc('p1')
        .collection('seasons');
    await seasonsRef.doc('older').set({
      'teamAMembers': ['u1'],
      'teamBMembers': ['u2'],
      'teamATileCount': 1,
      'teamBTileCount': 0,
      'winner': 'A',
      'startAt': '2026-08-12T00:00:00.000Z',
      'endAt': '2026-08-26T00:00:00.000Z',
    });
    await seasonsRef.doc('newer').set({
      'teamAMembers': ['u1'],
      'teamBMembers': ['u2'],
      'teamATileCount': 3,
      'teamBTileCount': 1,
      'winner': 'A',
      'startAt': '2026-08-26T00:00:00.000Z',
      'endAt': '2026-09-09T00:00:00.000Z',
    });
    final service = PartySeasonService(firestore: firestore);

    final seasons = await service.watchSeasons('p1').first;

    expect(seasons.map((s) => s.id), ['newer', 'older']);
  });
}
