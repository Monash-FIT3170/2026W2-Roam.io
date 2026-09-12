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

/// Thrown when a user tries to enter another party before leaving their own.
class AlreadyInPartyException implements Exception {
  const AlreadyInPartyException(this.partyId);

  final String partyId;

  @override
  String toString() => 'Already in party "$partyId"';
}

class NotPartyMemberException implements Exception {
  const NotPartyMemberException(this.partyId);

  final String partyId;
}

/// Firestore persistence for Party Mode parties, at `parties/{partyId}`.
class PartyService {
  PartyService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String partiesCollection = 'parties';
  static const String membershipsCollection = 'party_memberships';
  static const int _joinCodeLength = 6;
  static const String _joinCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int maxTeamSize = 8;
  static const int maxNameLength = 40;

  final FirebaseFirestore _firestore;

  FirebaseFirestore get firestore => _firestore;

  Future<Party?> getParty(String partyId) async {
    final doc = await _parties.doc(partyId).get();
    final data = doc.data();
    return data == null ? null : Party.fromMap(doc.id, data);
  }

  CollectionReference<Map<String, dynamic>> get _parties =>
      _firestore.collection(partiesCollection);

  DocumentReference<Map<String, dynamic>> _membership(String uid) =>
      _firestore.collection(membershipsCollection).doc(uid);

  /// Creates and joins a party in one transaction. The membership document is
  /// the single per-user lock shared by both create and join.
  Future<Party> createParty({required String uid, String? name}) async {
    await _checkLegacyMembership(uid);
    final ref = _parties.doc();
    final joinCode = _generateJoinCode();
    final party = Party(
      id: ref.id,
      joinCode: joinCode,
      name: _validatedName(name ?? 'Party #$joinCode'),
      teamAMembers: [uid],
      teamBMembers: const [],
    );
    await _firestore.runTransaction<void>((transaction) async {
      final membership = await transaction.get(_membership(uid));
      final existingPartyId = membership.data()?['partyId'] as String?;
      if (existingPartyId != null) {
        throw AlreadyInPartyException(existingPartyId);
      }
      transaction.set(ref, party.toMap());
      transaction.set(_membership(uid), {'partyId': ref.id});
    });
    return party;
  }

  static String _validatedName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > maxNameLength) {
      throw ArgumentError.value(
        name,
        'name',
        'Use 1–$maxNameLength characters.',
      );
    }
    return trimmed;
  }

  /// Renames an active party. Any current member may edit its shared name.
  Future<Party> renameParty({
    required String partyId,
    required String uid,
    required String name,
  }) {
    final validated = _validatedName(name);
    return _firestore.runTransaction<Party>((transaction) async {
      final ref = _parties.doc(partyId);
      final doc = await transaction.get(ref);
      final data = doc.data();
      if (data == null) throw PartyNotFoundException(partyId);
      final party = Party.fromMap(doc.id, data);
      if (!party.isMember(uid)) throw NotPartyMemberException(partyId);
      transaction.update(ref, {'name': validated});
      return Party.fromMap(doc.id, {...data, 'name': validated});
    });
  }

  // Older party documents have team rosters but no per-user membership record.
  // Keep those users from creating/joining again until they leave. Existing
  // rosters should be backfilled before enforcing the new rules in production.
  Future<void> _checkLegacyMembership(
    String uid, {
    String? allowedPartyId,
  }) async {
    final existing = await getUserParties(uid);
    for (final party in existing) {
      if (party.id != allowedPartyId) {
        throw AlreadyInPartyException(party.id);
      }
    }
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
    await _checkLegacyMembership(uid, allowedPartyId: ref.id);

    return _firestore.runTransaction<Party>((transaction) async {
      final membership = await transaction.get(_membership(uid));
      final existingPartyId = membership.data()?['partyId'] as String?;
      if (existingPartyId != null && existingPartyId != ref.id) {
        throw AlreadyInPartyException(existingPartyId);
      }
      final doc = await transaction.get(ref);
      final data = doc.data();
      if (data == null) {
        throw PartyNotFoundException(code);
      }
      final party = Party.fromMap(doc.id, data);

      if (party.teamAMembers.contains(uid) ||
          party.teamBMembers.contains(uid)) {
        if (existingPartyId == null) {
          transaction.set(_membership(uid), {'partyId': ref.id});
        }
        return party;
      }

      if (existingPartyId != null) {
        throw AlreadyInPartyException(existingPartyId);
      }

      if (party.teamAMembers.length >= maxTeamSize &&
          party.teamBMembers.length >= maxTeamSize) {
        throw PartyFullException(party.id);
      }

      final joinTeamA = party.teamAMembers.length <= party.teamBMembers.length;
      final updated = Party(
        id: party.id,
        joinCode: party.joinCode,
        name: party.name,
        teamAMembers: joinTeamA
            ? [...party.teamAMembers, uid]
            : party.teamAMembers,
        teamBMembers: joinTeamA
            ? party.teamBMembers
            : [...party.teamBMembers, uid],
        tiles: party.tiles,
      );

      transaction.update(ref, {
        'teamAMembers': updated.teamAMembers,
        'teamBMembers': updated.teamBMembers,
      });
      transaction.set(_membership(uid), {'partyId': ref.id});
      return updated;
    });
  }

  /// Removes [uid] from whichever team it belongs to. Does not rebalance or
  /// otherwise re-validate the remaining members' team assignments.
  Future<Party> leaveParty({required String partyId, required String uid}) {
    return _firestore.runTransaction<Party>((transaction) async {
      final ref = _parties.doc(partyId);
      final membershipRef = _membership(uid);
      final membership = await transaction.get(membershipRef);
      final doc = await transaction.get(ref);
      final data = doc.data();
      if (data == null) {
        throw PartyNotFoundException(partyId);
      }
      final party = Party.fromMap(doc.id, data);

      final updated = Party(
        id: party.id,
        joinCode: party.joinCode,
        name: party.name,
        teamAMembers: party.teamAMembers.where((m) => m != uid).toList(),
        teamBMembers: party.teamBMembers.where((m) => m != uid).toList(),
        tiles: party.tiles,
      );

      transaction.update(ref, {
        'teamAMembers': updated.teamAMembers,
        'teamBMembers': updated.teamBMembers,
      });
      if (membership.data()?['partyId'] == partyId) {
        transaction.delete(membershipRef);
      }
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
    var hasTeamA = false;
    var hasTeamB = false;

    void emit() {
      if (!hasTeamA || !hasTeamB) return;
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
                hasTeamA = true;
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
                hasTeamB = true;
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
