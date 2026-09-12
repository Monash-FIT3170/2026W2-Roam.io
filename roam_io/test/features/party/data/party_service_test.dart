import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/party/data/party_service.dart';
import 'package:roam_io/features/party/domain/party.dart';

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

  test('watchParty emits live updates as another user joins', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PartyService(firestore: firestore);
    final party = await service.createParty();
    await service.joinParty(code: party.joinCode, uid: 'user-1');

    final emissions = <Party?>[];
    final subscription = service.watchParty(party.id).listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    await service.joinParty(code: party.joinCode, uid: 'user-2');
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(emissions.last?.teamAMembers, ['user-1']);
    expect(emissions.last?.teamBMembers, ['user-2']);
  });

  test('getUserParties returns all parties the user belongs to across teams', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PartyService(firestore: firestore);

    final party1 = await service.createParty();
    await service.joinParty(code: party1.joinCode, uid: 'user-1'); // Team A

    final party2 = await service.createParty();
    await service.joinParty(code: party2.joinCode, uid: 'other'); // Team A
    await service.joinParty(code: party2.joinCode, uid: 'user-1'); // Team B

    final party3 = await service.createParty();
    await service.joinParty(code: party3.joinCode, uid: 'other'); // not in party3

    final userParties = await service.getUserParties('user-1');
    expect(userParties.map((p) => p.id), containsAll([party1.id, party2.id]));
    expect(userParties.map((p) => p.id), isNot(contains(party3.id)));
  });

  test('watchUserParties streams updates when a user joins or leaves a party', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PartyService(firestore: firestore);

    final emissions = <List<Party>>[];
    final subscription = service.watchUserParties('user-1').listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    final party = await service.createParty();
    await service.joinParty(code: party.joinCode, uid: 'user-1');
    await Future<void>.delayed(Duration.zero);

    expect(emissions.last.map((p) => p.id), contains(party.id));
    await subscription.cancel();
  });
}
