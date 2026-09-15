import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/party/data/party_dwell_ping_service.dart';

void main() {
  test('tick sends nothing when Party Mode is not engaged', () async {
    var sendCount = 0;
    final service = PartyDwellPingService(
      sendPing:
          ({
            required partyId,
            required team,
            required tileId,
            required uid,
            required pingAt,
          }) async {
            sendCount++;
          },
    );
    service.configure(partyId: 'p1', uid: 'u1');
    service.updateCurrentTile('t1');

    await service.tick(DateTime.utc(2026, 1, 1));

    expect(sendCount, 0);
  });

  test(
    'tick sends a ping when engaged with a party and a current tile',
    () async {
      String? sentPartyId;
      String? sentTileId;
      String? sentUid;
      DateTime? sentPingAt;
      final service = PartyDwellPingService(
        sendPing:
            ({
              required partyId,
              required team,
              required tileId,
              required uid,
              required pingAt,
            }) async {
              sentPartyId = partyId;
              sentTileId = tileId;
              sentUid = uid;
              sentPingAt = pingAt;
            },
      );
      service.configure(partyId: 'p1', uid: 'u1');
      service.updateCurrentTile('t1');
      service.setEngaged(true);

      final now = DateTime.utc(2026, 1, 1);
      await service.tick(now);

      expect(sentPartyId, 'p1');
      expect(sentTileId, 't1');
      expect(sentUid, 'u1');
      expect(sentPingAt, now);
    },
  );

  test(
    'ticking again before the interval elapses does not send again',
    () async {
      var sendCount = 0;
      final service = PartyDwellPingService(
        sendPing:
            ({
              required partyId,
              required team,
              required tileId,
              required uid,
              required pingAt,
            }) async {
              sendCount++;
            },
      );
      service.configure(partyId: 'p1', uid: 'u1');
      service.updateCurrentTile('t1');
      service.setEngaged(true);

      final firstTick = DateTime.utc(2026, 1, 1, 0, 0, 0);
      await service.tick(firstTick);
      await service.tick(firstTick.add(const Duration(seconds: 30)));

      expect(sendCount, 1);
    },
  );

  test('ticking after the interval elapses sends again', () async {
    var sendCount = 0;
    final service = PartyDwellPingService(
      sendPing:
          ({
            required partyId,
            required team,
            required tileId,
            required uid,
            required pingAt,
          }) async {
            sendCount++;
          },
    );
    service.configure(partyId: 'p1', uid: 'u1');
    service.updateCurrentTile('t1');
    service.setEngaged(true);

    final firstTick = DateTime.utc(2026, 1, 1, 0, 0, 0);
    await service.tick(firstTick);
    await service.tick(firstTick.add(const Duration(seconds: 61)));

    expect(sendCount, 2);
  });

  test(
    'a ping that fails to send is queued and flushed with its original timestamp',
    () async {
      final sentPingAts = <DateTime>[];
      var shouldFail = true;
      final service = PartyDwellPingService(
        sendPing:
            ({
              required partyId,
              required team,
              required tileId,
              required uid,
              required pingAt,
            }) async {
              if (shouldFail) throw Exception('offline');
              sentPingAts.add(pingAt);
            },
      );
      service.configure(partyId: 'p1', uid: 'u1');
      service.updateCurrentTile('t1');
      service.setEngaged(true);

      final failedAt = DateTime.utc(2026, 1, 1, 0, 0, 0);
      await service.tick(failedAt);
      expect(sentPingAts, isEmpty);

      shouldFail = false;
      final secondTick = failedAt.add(const Duration(seconds: 61));
      await service.tick(secondTick);

      expect(sentPingAts, [failedAt, secondTick]);
    },
  );

  test('tick never throws even when every ping attempt fails', () async {
    final service = PartyDwellPingService(
      sendPing:
          ({
            required partyId,
            required team,
            required tileId,
            required uid,
            required pingAt,
          }) async {
            throw Exception('offline');
          },
    );
    service.configure(partyId: 'p1', uid: 'u1');
    service.updateCurrentTile('t1');
    service.setEngaged(true);

    await service.tick(DateTime.utc(2026, 1, 1));
    await service.tick(DateTime.utc(2026, 1, 1, 0, 2));

    // Reaching here without an uncaught exception is the assertion.
  });
}
