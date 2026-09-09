import 'package:flutter_test/flutter_test.dart';
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
}
