import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/party/data/party_service.dart';
import 'package:roam_io/features/party/domain/party.dart';
import 'package:roam_io/features/party/providers/current_party_provider.dart';

void main() {
  test('setParty updates currentParty and notifies listeners', () {
    final provider = CurrentPartyProvider();
    var notifyCount = 0;
    provider.addListener(() => notifyCount++);
    const party = Party(
      id: 'p1',
      joinCode: 'ABC123',
      teamAMembers: ['u1'],
      teamBMembers: [],
    );

    provider.setParty(party);

    expect(provider.currentParty, party);
    expect(notifyCount, 1);
  });

  test('the current party stays live after the party screen is closed', () async {
    final partyService = PartyService(firestore: FakeFirebaseFirestore());
    final provider = CurrentPartyProvider(partyService: partyService);
    final created = await partyService.createParty();
    final joined = await partyService.joinParty(
      code: created.joinCode,
      uid: 'user-1',
    );

    provider.setParty(joined);
    await partyService.joinParty(code: created.joinCode, uid: 'user-2');
    await Future<void>.delayed(Duration.zero);

    final members = [
      ...?provider.currentParty?.teamAMembers,
      ...?provider.currentParty?.teamBMembers,
    ];
    expect(members, containsAll(['user-1', 'user-2']));

    provider.dispose();
  });
}
