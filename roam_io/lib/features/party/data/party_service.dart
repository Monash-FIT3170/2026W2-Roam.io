import 'dart:async';
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

  FirebaseFirestore get firestore => _firestore;

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

  /// Live updates for a party doc (e.g. teammates joining/leaving), or `null`
  /// once the party no longer exists.
  Stream<Party?> watchParty(String partyId) {
    return _parties.doc(partyId).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : Party.fromMap(doc.id, data);
    });
  }

  String _generateJoinCode() {
    final random = Random.secure();
    return List<String>.generate(
      _joinCodeLength,
      (_) => _joinCodeAlphabet[random.nextInt(_joinCodeAlphabet.length)],
    ).join();
  }

  Future<Party> joinParty({required String code, required String uid}) async {
    // Queries cannot run inside a transaction, so the code is resolved to a
    // document reference first and the roster is then read transactionally.
    final query = await _parties
        .where('joinCode', isEqualTo: code)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw PartyNotFoundException(code);
    }
    final ref = query.docs.first.reference;

    return _firestore.runTransaction<Party>((transaction) async {
      final doc = await transaction.get(ref);
      final data = doc.data();
      if (data == null) {
        throw PartyNotFoundException(code);
      }
      final party = Party.fromMap(doc.id, data);

      if (party.teamAMembers.contains(uid) ||
          party.teamBMembers.contains(uid)) {
        return party;
      }

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

      transaction.set(ref, updated.toMap());
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

  /// Live updates for all parties where [uid] is in either Team A or Team B.
  Stream<List<Party>> watchUserParties(String uid) {
    late final StreamController<List<Party>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subA;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subB;
    var partiesA = <String, Party>{};
    var partiesB = <String, Party>{};

    void emit() {
      final combined = <String, Party>{...partiesA, ...partiesB};
      if (!controller.isClosed) {
        controller.add(combined.values.toList());
      }
    }

    controller = StreamController<List<Party>>.broadcast(
      onListen: () {
        subA = _parties
            .where('teamAMembers', arrayContains: uid)
            .snapshots()
            .listen(
              (snapshot) {
                partiesA = {
                  for (final doc in snapshot.docs)
                    doc.id: Party.fromMap(doc.id, doc.data()),
                };
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                if (!controller.isClosed) {
                  controller.addError(error, stackTrace);
                }
              },
            );

        subB = _parties
            .where('teamBMembers', arrayContains: uid)
            .snapshots()
            .listen(
              (snapshot) {
                partiesB = {
                  for (final doc in snapshot.docs)
                    doc.id: Party.fromMap(doc.id, doc.data()),
                };
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                if (!controller.isClosed) {
                  controller.addError(error, stackTrace);
                }
              },
            );
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
      },
    );

    return controller.stream;
  }

  /// Gets all parties where [uid] is in either Team A or Team B.
  Future<List<Party>> getUserParties(String uid) async {
    final resA = await _parties.where('teamAMembers', arrayContains: uid).get();
    final resB = await _parties.where('teamBMembers', arrayContains: uid).get();
    final parties = <String, Party>{};
    for (final doc in resA.docs) {
      parties[doc.id] = Party.fromMap(doc.id, doc.data());
    }
    for (final doc in resB.docs) {
      parties[doc.id] = Party.fromMap(doc.id, doc.data());
    }
    return parties.values.toList();
  }
}
