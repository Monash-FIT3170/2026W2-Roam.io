import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Sends a single dwell ping to the server-trusted callable or fallback store.
typedef SendDwellPing =
    Future<void> Function({
      required String partyId,
      required String? team,
      required String tileId,
      required String uid,
      required DateTime pingAt,
    });

/// Directly records a dwell ping into Firestore `parties/{partyId}` tiles map
/// and `parties/{partyId}/tiles/{tileId}` subcollection.
Future<void> recordDwellPingDirectly({
  required String partyId,
  required String? team,
  required String tileId,
  required String uid,
  required DateTime pingAt,
  double? addedDwellSeconds,
  FirebaseFirestore? firestore,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final partyDocRef = db.collection('parties').doc(partyId);
  final subDocRef = partyDocRef.collection('tiles').doc(tileId);

  try {
    final partyDoc = await partyDocRef.get();
    if (!partyDoc.exists || partyDoc.data() == null) return;

    final partyData = partyDoc.data()!;
    var resolvedTeam = team;
    if (resolvedTeam == null) {
      final teamA = List<String>.from(
        partyData['teamAMembers'] as List? ?? const [],
      );
      final teamB = List<String>.from(
        partyData['teamBMembers'] as List? ?? const [],
      );
      if (teamA.contains(uid)) {
        resolvedTeam = 'A';
      } else if (teamB.contains(uid)) {
        resolvedTeam = 'B';
      }
    }

    if (resolvedTeam == null) return;

    final subDoc = await subDocRef.get();

    final existingTiles = Map<String, dynamic>.from(
      partyData['tiles'] as Map? ?? const {},
    );

    final subData = subDoc.exists && subDoc.data() != null
        ? Map<String, dynamic>.from(subDoc.data()!)
        : null;

    final docData = existingTiles[tileId] is Map
        ? Map<String, dynamic>.from(existingTiles[tileId] as Map)
        : null;

    var baseA = max(
      (subData?['teamADwellSeconds'] as num?)?.toDouble() ?? 0.0,
      (docData?['teamADwellSeconds'] as num?)?.toDouble() ?? 0.0,
    );
    var baseB = max(
      (subData?['teamBDwellSeconds'] as num?)?.toDouble() ?? 0.0,
      (docData?['teamBDwellSeconds'] as num?)?.toDouble() ?? 0.0,
    );

    final lastPingByUser = Map<String, dynamic>.from(
      subData?['lastPingByUser'] as Map? ??
          docData?['lastPingByUser'] as Map? ??
          const {},
    );

    if (addedDwellSeconds != null && addedDwellSeconds > 0) {
      if (resolvedTeam == 'A') {
        baseA += addedDwellSeconds;
      } else {
        baseB += addedDwellSeconds;
      }
    } else {
      final prev = lastPingByUser[uid] as Map<String, dynamic>?;
      if (prev != null &&
          prev['team'] == resolvedTeam &&
          prev['pingAt'] != null) {
        final prevPingAt = DateTime.tryParse(prev['pingAt'] as String);
        if (prevPingAt != null) {
          final elapsed = pingAt.difference(prevPingAt).inMilliseconds / 1000.0;
          if (elapsed > 0 && elapsed <= 300) {
            if (resolvedTeam == 'A') {
              baseA += elapsed;
            } else {
              baseB += elapsed;
            }
          }
        }
      }
    }

    lastPingByUser[uid] = {
      'team': resolvedTeam,
      'pingAt': pingAt.toIso8601String(),
    };

    final rawTileData = <String, dynamic>{
      'teamADwellSeconds': baseA,
      'teamBDwellSeconds': baseB,
      'lastPingByUser': lastPingByUser,
    };

    existingTiles[tileId] = rawTileData;

    await subDocRef.set(rawTileData, SetOptions(merge: true));
    await partyDocRef.set({'tiles': existingTiles}, SetOptions(merge: true));
  } catch (e) {
    debugPrint('[PartyDwellPing] Error updating party document tiles: $e');
  }
}

/// Calls direct Firestore write and then triggers Cloud Function if available.
Future<void> _callSubmitDwellPing({
  required String partyId,
  required String? team,
  required String tileId,
  required String uid,
  required DateTime pingAt,
  double? addedDwellSeconds,
  FirebaseFirestore? firestore,
}) async {
  await recordDwellPingDirectly(
    partyId: partyId,
    team: team,
    tileId: tileId,
    uid: uid,
    pingAt: pingAt,
    addedDwellSeconds: addedDwellSeconds,
    firestore: firestore,
  );
  try {
    await FirebaseFunctions.instanceFor(
      region: 'australia-southeast1',
    ).httpsCallable('submitDwellPing').call({
      'partyId': partyId,
      'tileId': tileId,
      'pingAt': pingAt.toIso8601String(),
    });
  } catch (_) {}
}

/// Periodically reports the current user's tile to the party-dwell pipeline
/// while Party Mode is engaged, queuing and retrying pings that fail (e.g.
/// while offline) in order, using their original timestamps.
class PartyDwellPingService {
  PartyDwellPingService({
    SendDwellPing? sendPing,
    this.pingInterval = const Duration(seconds: 60),
    FirebaseFirestore? firestore,
  }) : _firestore = firestore,
       sendPing =
           sendPing ??
           (({
             required String partyId,
             required String? team,
             required String tileId,
             required String uid,
             required DateTime pingAt,
           }) => _callSubmitDwellPing(
             partyId: partyId,
             team: team,
             tileId: tileId,
             uid: uid,
             pingAt: pingAt,
             firestore: firestore,
           ));

  final SendDwellPing sendPing;
  final Duration pingInterval;
  final FirebaseFirestore? _firestore;

  bool _isEngaged = false;
  String? _partyId;
  String? _uid;
  String? _team;
  String? _currentTileId;
  DateTime? _lastSentAt;
  final List<DateTime> _queuedPingAts = <DateTime>[];

  Future<void> tick(DateTime now) async {
    if (!_isEngaged ||
        _partyId == null ||
        _currentTileId == null ||
        _uid == null) {
      return;
    }
    if (_lastSentAt != null && now.difference(_lastSentAt!) < pingInterval) {
      return;
    }
    _lastSentAt = now;
    _queuedPingAts.add(now);
    await _flushQueue();
  }

  /// Immediately commits any accumulated dwell time up to [now] for the active tile.
  Future<void> flushNow({
    required DateTime now,
    required String partyId,
    required String uid,
    required String? team,
    required String tileId,
    double? addedDwellSeconds,
  }) async {
    _partyId = partyId;
    _uid = uid;
    _team = team;
    try {
      if (addedDwellSeconds != null) {
        await recordDwellPingDirectly(
          partyId: partyId,
          team: team,
          tileId: tileId,
          uid: uid,
          pingAt: now,
          addedDwellSeconds: addedDwellSeconds,
          firestore: _firestore,
        );
      } else {
        await sendPing(
          partyId: partyId,
          team: team,
          tileId: tileId,
          uid: uid,
          pingAt: now,
        );
      }
    } catch (_) {}
  }

  Future<void> _flushQueue() async {
    if (_partyId == null || _currentTileId == null || _uid == null) {
      _queuedPingAts.clear();
      return;
    }
    while (_queuedPingAts.isNotEmpty) {
      final pingAt = _queuedPingAts.first;
      try {
        await sendPing(
          partyId: _partyId!,
          team: _team,
          tileId: _currentTileId!,
          uid: _uid!,
          pingAt: pingAt,
        );
        _queuedPingAts.removeAt(0);
      } catch (_) {
        return;
      }
    }
  }

  void configure({required String partyId, required String uid, String? team}) {
    _partyId = partyId;
    _uid = uid;
    _team = team;
  }

  void updateCurrentTile(String? tileId) {
    _currentTileId = tileId;
  }

  void setEngaged(bool engaged) {
    _isEngaged = engaged;
  }
}
