import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/party/data/party_service.dart';

void main() {
  test(
    'createParty generates a unique join code and two empty teams',
    () async {
      final service = PartyService(firestore: FakeFirebaseFirestore());

      final party = await service.createParty();

      expect(party.joinCode, isNotEmpty);
      expect(party.teamAMembers, isEmpty);
      expect(party.teamBMembers, isEmpty);
    },
  );

  test('joining an empty party assigns the user to team A', () async {
    final service = PartyService(firestore: FakeFirebaseFirestore());
    final party = await service.createParty();

    final joined = await service.joinParty(
      code: party.joinCode,
      uid: 'user-1',
    );

    expect(joined.teamAMembers, ['user-1']);
    expect(joined.teamBMembers, isEmpty);
  });

  test('joining assigns the user to whichever team is smaller', () async {
    final service = PartyService(firestore: FakeFirebaseFirestore());
    final party = await service.createParty();
    await service.joinParty(code: party.joinCode, uid: 'user-1');

    final joined = await service.joinParty(
      code: party.joinCode,
      uid: 'user-2',
    );

    expect(joined.teamAMembers, ['user-1']);
    expect(joined.teamBMembers, ['user-2']);
  });

  test('joining with an unknown code throws PartyNotFoundException', () async {
    final service = PartyService(firestore: FakeFirebaseFirestore());
    await service.createParty();

    expect(
      () => service.joinParty(code: 'NOPE00', uid: 'user-1'),
      throwsA(isA<PartyNotFoundException>()),
    );
  });

  test('joining a full party (8/8) throws PartyFullException', () async {
    final service = PartyService(firestore: FakeFirebaseFirestore());
    final party = await service.createParty();

    for (var i = 0; i < 16; i++) {
      await service.joinParty(code: party.joinCode, uid: 'user-$i');
    }

    expect(
      () => service.joinParty(code: party.joinCode, uid: 'user-overflow'),
      throwsA(isA<PartyFullException>()),
    );
  });

  test('leaving a party removes the member without affecting others', () async {
    final service = PartyService(firestore: FakeFirebaseFirestore());
    final party = await service.createParty();
    await service.joinParty(code: party.joinCode, uid: 'user-1');
    await service.joinParty(code: party.joinCode, uid: 'user-2');

    final after = await service.leaveParty(
      partyId: party.id,
      uid: 'user-1',
    );

    expect(after.teamAMembers, isEmpty);
    expect(after.teamBMembers, ['user-2']);
  });
}
