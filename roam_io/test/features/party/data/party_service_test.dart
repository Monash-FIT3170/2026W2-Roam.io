import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/party/data/party_service.dart';
import 'package:roam_io/features/party/domain/party.dart';

void main() {
  test(
    'createParty creates the party and joins its creator atomically',
    () async {
      final service = PartyService(firestore: FakeFirebaseFirestore());

      final party = await service.createParty(uid: 'creator');

      expect(party.joinCode, isNotEmpty);
      expect(party.teamAMembers, ['creator']);
      expect(party.teamBMembers, isEmpty);
    },
  );

  test('joining a party assigns the next user to team B', () async {
    final service = PartyService(firestore: FakeFirebaseFirestore());
    final party = await service.createParty(uid: 'creator');

    final joined = await service.joinParty(code: party.joinCode, uid: 'user-1');

    expect(joined.teamAMembers, ['creator']);
    expect(joined.teamBMembers, ['user-1']);
  });

  test('joining assigns the user to whichever team is smaller', () async {
    final service = PartyService(firestore: FakeFirebaseFirestore());
    final party = await service.createParty(uid: 'creator');
    await service.joinParty(code: party.joinCode, uid: 'user-1');

    final joined = await service.joinParty(code: party.joinCode, uid: 'user-2');

    expect(joined.teamAMembers, ['creator', 'user-2']);
    expect(joined.teamBMembers, ['user-1']);
  });

  test('joining with an unknown code throws PartyNotFoundException', () async {
    final service = PartyService(firestore: FakeFirebaseFirestore());
    await service.createParty(uid: 'creator');

    expect(
      () => service.joinParty(code: 'NOPE00', uid: 'user-1'),
      throwsA(isA<PartyNotFoundException>()),
    );
  });

  test('joining a full party (8/8) throws PartyFullException', () async {
    final service = PartyService(firestore: FakeFirebaseFirestore());
    final party = await service.createParty(uid: 'creator');

    for (var i = 0; i < 15; i++) {
      await service.joinParty(code: party.joinCode, uid: 'user-$i');
    }

    expect(
      () => service.joinParty(code: party.joinCode, uid: 'user-overflow'),
      throwsA(isA<PartyFullException>()),
    );
  });

  test('a member cannot create or join a second party', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PartyService(firestore: firestore);
    final first = await service.createParty(uid: 'user-1');
    final second = await service.createParty(uid: 'user-2');

    await expectLater(
      service.createParty(uid: 'user-1'),
      throwsA(isA<AlreadyInPartyException>()),
    );
    await expectLater(
      service.joinParty(code: second.joinCode, uid: 'user-1'),
      throwsA(isA<AlreadyInPartyException>()),
    );

    expect((await firestore.collection('parties').get()).docs.length, 2);
    expect((await service.getUserParties('user-1')).single.id, first.id);
    expect(
      (await firestore.collection('party_memberships').doc('user-1').get())
          .data()?['partyId'],
      first.id,
    );
  });

  test('leaving clears membership so a user can join another party', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PartyService(firestore: firestore);
    final first = await service.createParty(uid: 'user-1');
    final second = await service.createParty(uid: 'user-2');

    await service.leaveParty(partyId: first.id, uid: 'user-1');
    expect(
      (await firestore.collection('party_memberships').doc('user-1').get())
          .exists,
      isFalse,
    );

    final joined = await service.joinParty(
      code: second.joinCode,
      uid: 'user-1',
    );
    expect(joined.teamForUser('user-1'), 'B');
    expect((await service.getUserParties('user-1')).single.id, second.id);
  });

  test(
    'joining the current party again does not duplicate membership',
    () async {
      final service = PartyService(firestore: FakeFirebaseFirestore());
      final party = await service.createParty(uid: 'user-1');

      final joined = await service.joinParty(
        code: party.joinCode,
        uid: 'user-1',
      );

      expect(joined.teamAMembers, ['user-1']);
      expect(joined.teamBMembers, isEmpty);
    },
  );

  test('legacy roster membership also blocks a second party', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PartyService(firestore: firestore);
    await firestore.collection('parties').doc('legacy').set({
      'joinCode': 'LEGACY',
      'teamAMembers': ['user-1'],
      'teamBMembers': <String>[],
      'tiles': <String, dynamic>{},
    });
    final other = await service.createParty(uid: 'other');

    await expectLater(
      service.createParty(uid: 'user-1'),
      throwsA(isA<AlreadyInPartyException>()),
    );
    await expectLater(
      service.joinParty(code: other.joinCode, uid: 'user-1'),
      throwsA(isA<AlreadyInPartyException>()),
    );
  });

  test('roster changes preserve existing tile data', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PartyService(firestore: firestore);
    final party = await service.createParty(uid: 'user-1');
    await firestore.collection('parties').doc(party.id).update({
      'tiles': {
        'tile-1': {'teamADwellSeconds': 5},
      },
    });

    await service.joinParty(code: party.joinCode, uid: 'user-2');
    await service.leaveParty(partyId: party.id, uid: 'user-2');

    final stored = await firestore.collection('parties').doc(party.id).get();
    expect(stored.data()?['tiles'], {
      'tile-1': {'teamADwellSeconds': 5},
    });
  });

  test('leaving a party removes the member without affecting others', () async {
    final service = PartyService(firestore: FakeFirebaseFirestore());
    final party = await service.createParty(uid: 'creator');
    await service.joinParty(code: party.joinCode, uid: 'user-1');
    await service.joinParty(code: party.joinCode, uid: 'user-2');

    final after = await service.leaveParty(partyId: party.id, uid: 'user-1');

    expect(after.teamAMembers, ['creator', 'user-2']);
    expect(after.teamBMembers, isEmpty);
  });

  test('watchParty emits live updates as another user joins', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PartyService(firestore: firestore);
    final party = await service.createParty(uid: 'creator');
    await service.joinParty(code: party.joinCode, uid: 'user-1');

    final emissions = <Party?>[];
    final subscription = service.watchParty(party.id).listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    await service.joinParty(code: party.joinCode, uid: 'user-2');
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(emissions.last?.teamAMembers, ['creator', 'user-2']);
    expect(emissions.last?.teamBMembers, ['user-1']);
  });

  test('getUserParties returns the one party the user belongs to', () async {
    final firestore = FakeFirebaseFirestore();
    final service = PartyService(firestore: firestore);

    final party1 = await service.createParty(uid: 'user-1');

    final party2 = await service.createParty(uid: 'other');

    final userParties = await service.getUserParties('user-1');
    expect(userParties.map((p) => p.id), [party1.id]);
    expect(userParties.map((p) => p.id), isNot(contains(party2.id)));
  });

  test(
    'watchUserParties streams updates when a user joins or leaves a party',
    () async {
      final firestore = FakeFirebaseFirestore();
      final service = PartyService(firestore: firestore);

      final emissions = <List<Party>>[];
      final subscription = service
          .watchUserParties('user-1')
          .listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      final party = await service.createParty(uid: 'creator');
      await service.joinParty(code: party.joinCode, uid: 'user-1');
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last.map((p) => p.id), contains(party.id));
      await subscription.cancel();
    },
  );
}
