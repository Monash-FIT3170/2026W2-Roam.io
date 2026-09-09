import 'package:cloud_functions/cloud_functions.dart';

/// Sends a single dwell ping to the server-trusted callable.
typedef SendDwellPing =
    Future<void> Function({
      required String partyId,
      required String? team,
      required String tileId,
      required String uid,
      required DateTime pingAt,
    });

/// Calls the `submitDwellPing` callable; the server resolves the caller's
/// team from the party roster, so [team] isn't sent (kept in [SendDwellPing]
/// only so tests can observe what the caller believed its team was).
Future<void> _callSubmitDwellPing({
  required String partyId,
  required String? team,
  required String tileId,
  required String uid,
  required DateTime pingAt,
}) async {
  await FirebaseFunctions.instance.httpsCallable('submitDwellPing').call({
    'partyId': partyId,
    'tileId': tileId,
    'pingAt': pingAt.toIso8601String(),
  });
}

/// Periodically reports the current user's tile to the party-dwell pipeline
/// while Party Mode is engaged, queuing and retrying pings that fail (e.g.
/// while offline) in order, using their original timestamps.
///
/// [tick] is called externally (e.g. by a `Timer.periodic` in the owning
/// widget); all gating/queueing logic lives here so it's testable without a
/// real timer.
class PartyDwellPingService {
  PartyDwellPingService({
    SendDwellPing? sendPing,
    this.pingInterval = const Duration(seconds: 60),
  }) : sendPing = sendPing ?? _callSubmitDwellPing;

  final SendDwellPing sendPing;
  final Duration pingInterval;

  bool _isEngaged = false;
  String? _partyId;
  String? _uid;
  String? _currentTileId;
  DateTime? _lastSentAt;
  final List<DateTime> _queuedPingAts = <DateTime>[];

  Future<void> tick(DateTime now) async {
    if (!_isEngaged || _partyId == null || _currentTileId == null) return;
    if (_lastSentAt != null && now.difference(_lastSentAt!) < pingInterval) {
      return;
    }
    _lastSentAt = now;
    _queuedPingAts.add(now);
    await _flushQueue();
  }

  Future<void> _flushQueue() async {
    while (_queuedPingAts.isNotEmpty) {
      final pingAt = _queuedPingAts.first;
      try {
        await sendPing(
          partyId: _partyId!,
          team: null,
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

  void configure({required String partyId, required String uid}) {
    _partyId = partyId;
    _uid = uid;
  }

  void updateCurrentTile(String? tileId) {
    _currentTileId = tileId;
  }

  void setEngaged(bool engaged) {
    _isEngaged = engaged;
  }
}
