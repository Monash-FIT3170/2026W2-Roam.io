import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/party.dart';

/// Thrown when a join code does not resolve to an existing party.
class PartyNotFoundException implements Exception {
  const PartyNotFoundException(this.code);

  final String code;

  @override
  String toString() => 'No party found for join code "$code"';
}

/// Thrown when both teams are already at the max team size.
class PartyFullException implements Exception {
  const PartyFullException(this.partyId);

  final String partyId;

  @override
  String toString() => 'Party "$partyId" is full';
}

/// Firestore persistence for Party Mode parties, at `parties/{partyId}`.
class PartyService {
  PartyService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String partiesCollection = 'parties';
  static const int _joinCodeLength = 6;
  static const String _joinCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int maxTeamSize = 8;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _parties =>
      _firestore.collection(partiesCollection);

  Future<Party> createParty() async {
    final ref = _parties.doc();
    final party = Party(
      id: ref.id,
      joinCode: _generateJoinCode(),
      teamAMembers: const [],
      teamBMembers: const [],
    );
    await ref.set(party.toMap());
    return party;
  }

  String _generateJoinCode() {
    final random = Random.secure();
    return List<String>.generate(
      _joinCodeLength,
      (_) => _joinCodeAlphabet[random.nextInt(_joinCodeAlphabet.length)],
    ).join();
  }

  Future<Party> joinParty({required String code, required String uid}) async {
    return _firestore.runTransaction<Party>((transaction) async {
      final query = await _parties.where('joinCode', isEqualTo: code).get();
      if (query.docs.isEmpty) {
        throw PartyNotFoundException(code);
      }
      final doc = query.docs.single;
      final party = Party.fromMap(doc.id, doc.data());

      if (party.teamAMembers.length >= maxTeamSize &&
          party.teamBMembers.length >= maxTeamSize) {
        throw PartyFullException(party.id);
      }

      final joinTeamA = party.teamAMembers.length <= party.teamBMembers.length;
      final updated = Party(
        id: party.id,
        joinCode: party.joinCode,
        teamAMembers: joinTeamA
            ? [...party.teamAMembers, uid]
            : party.teamAMembers,
        teamBMembers: joinTeamA
            ? party.teamBMembers
            : [...party.teamBMembers, uid],
      );

      transaction.set(doc.reference, updated.toMap());
      return updated;
    });
  }

  /// Removes [uid] from whichever team it belongs to. Does not rebalance or
  /// otherwise re-validate the remaining members' team assignments.
  Future<Party> leaveParty({required String partyId, required String uid}) {
    return _firestore.runTransaction<Party>((transaction) async {
      final ref = _parties.doc(partyId);
      final doc = await transaction.get(ref);
      final data = doc.data();
      if (data == null) {
        throw PartyNotFoundException(partyId);
      }
      final party = Party.fromMap(doc.id, data);

      final updated = Party(
        id: party.id,
        joinCode: party.joinCode,
        teamAMembers: party.teamAMembers.where((m) => m != uid).toList(),
        teamBMembers: party.teamBMembers.where((m) => m != uid).toList(),
      );

      transaction.set(ref, updated.toMap());
      return updated;
    });
  }
}
