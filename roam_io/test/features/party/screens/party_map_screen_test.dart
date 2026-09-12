/*
 * Author: Sanjevan Rajasegar & Copilot
 * Description:
 *   Widget tests for PartyMapScreen.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/map/data/map_controller.dart';
import 'package:roam_io/features/map/data/region_polygon.dart';
import 'package:roam_io/features/party/data/party_service.dart';
import 'package:roam_io/features/party/data/party_tile_ownership_service.dart';
import 'package:roam_io/features/party/domain/party.dart';
import 'package:roam_io/features/party/screens/party_map_screen.dart';

import '../../../support/fake_firebase_user.dart';

class _PartyAuthRepo implements AuthRepository {
  _PartyAuthRepo(String uid)
    : _user = FakeFirebaseUser(uid: uid, email: '$uid@test.com');

  final firebase_auth.User _user;

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield _user;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpPartyMapScreen(
  WidgetTester tester, {
  required Party party,
  required PartyService partyService,
  required String uid,
  PartyTileOwnershipService? tileOwnershipService,
  MapController? mapController,
  ValueChanged<Party?>? onPartyChanged,
}) async {
  final auth = AuthProvider(authRepository: _PartyAuthRepo(uid));
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        home: PartyMapScreen(
          party: party,
          partyService: partyService,
          partyTileOwnershipService: tileOwnershipService,
          mapController: mapController,
          onPartyChanged: onPartyChanged,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  testWidgets('renders party join code, team scoreboard and locating banner', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty();
    final joined = await partyService.joinParty(
      code: party.joinCode,
      uid: 'user-1',
    );

    await _pumpPartyMapScreen(
      tester,
      party: joined,
      partyService: partyService,
      uid: 'user-1',
    );

    expect(find.text('Party: ${party.joinCode}'), findsOneWidget);
    expect(find.text('Team A (You)'), findsOneWidget);
    expect(find.text('Team B'), findsOneWidget);
    expect(find.text('0 tiles'), findsNWidgets(2));
    expect(find.text('Locating Tile...'), findsOneWidget);
  });

  testWidgets(
    'shows countdown to claim and dwell time when inside an unclaimed tile',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final partyService = PartyService(firestore: firestore);
      final party = await partyService.createParty();
      final joined = await partyService.joinParty(
        code: party.joinCode,
        uid: 'user-1',
      );

      final mapController = MapController();
      mapController.currentRegion = const RegionPolygon(
        id: 'tile-101',
        name: 'Swanston Street SA1',
        areaSquareMetres: 2000,
        geometry: {'type': 'Polygon', 'coordinates': []},
      );

      await _pumpPartyMapScreen(
        tester,
        party: joined,
        partyService: partyService,
        mapController: mapController,
        uid: 'user-1',
      );

      expect(find.text('Swanston Street SA1'), findsOneWidget);
      expect(find.text('Unclaimed Tile'), findsOneWidget);
      expect(find.text('00:30 to claim'), findsOneWidget);
      expect(find.textContaining('Time in tile:'), findsOneWidget);
      expect(
        find.text('Team A: 00:00 · Team B: 00:00'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows countdown to overtake when inside an enemy-claimed tile',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final partyService = PartyService(firestore: firestore);
      final party = await partyService.createParty();
      final joined = await partyService.joinParty(
        code: party.joinCode,
        uid: 'user-1', // Team A
      );

      // Enemy team B has 400 seconds dwell on tile-101 (claimed by B)
      await firestore
          .collection('parties')
          .doc(party.id)
          .collection('tiles')
          .doc('tile-101')
          .set({'teamADwellSeconds': 0, 'teamBDwellSeconds': 400});

      final mapController = MapController();
      mapController.currentRegion = const RegionPolygon(
        id: 'tile-101',
        name: 'Flinders SA1',
        areaSquareMetres: 2000,
        geometry: {'type': 'Polygon', 'coordinates': []},
      );

      await _pumpPartyMapScreen(
        tester,
        party: joined,
        partyService: partyService,
        mapController: mapController,
        uid: 'user-1',
      );

      expect(find.text('Flinders SA1'), findsOneWidget);
      expect(find.text('Team B Territory'), findsOneWidget);
      expect(find.text('06:41 to overtake'), findsOneWidget);
      expect(find.textContaining('Enemy tile (Team B: 06:40)'), findsOneWidget);
    },
  );

  testWidgets(
    'shows claimed status when tile is owned by user team',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final partyService = PartyService(firestore: firestore);
      final party = await partyService.createParty();
      final joined = await partyService.joinParty(
        code: party.joinCode,
        uid: 'user-1', // Team A
      );

      // Team A has 450 seconds dwell on tile-101 (claimed by A)
      await firestore
          .collection('parties')
          .doc(party.id)
          .collection('tiles')
          .doc('tile-101')
          .set({'teamADwellSeconds': 450, 'teamBDwellSeconds': 100});

      final mapController = MapController();
      mapController.currentRegion = const RegionPolygon(
        id: 'tile-101',
        name: 'Bourke Street SA1',
        areaSquareMetres: 2000,
        geometry: {'type': 'Polygon', 'coordinates': []},
      );

      await _pumpPartyMapScreen(
        tester,
        party: joined,
        partyService: partyService,
        mapController: mapController,
        uid: 'user-1',
      );

      expect(find.text('Bourke Street SA1'), findsOneWidget);
      expect(find.text('Claimed by You'), findsOneWidget);
      expect(find.text('Tile Claimed!'), findsOneWidget);
      expect(find.textContaining('Lead: +05:50'), findsOneWidget);
      expect(find.text('1 tiles'), findsOneWidget); // Team A has 1 tile
      expect(mapController.partyTileOwnership['tile-101'], 'A');
    },
  );

  testWidgets(
    'claimed tile remains owned and scoreboard persists when moving to another tile',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final partyService = PartyService(firestore: firestore);
      final party = await partyService.createParty();
      final joined = await partyService.joinParty(
        code: party.joinCode,
        uid: 'user-1', // Team A
      );

      // Tile 101 already claimed with 450s dwell in Firestore
      await firestore
          .collection('parties')
          .doc(party.id)
          .collection('tiles')
          .doc('tile-101')
          .set({'teamADwellSeconds': 450, 'teamBDwellSeconds': 0});

      final mapController = MapController();
      // Initially in tile-101
      mapController.currentRegion = const RegionPolygon(
        id: 'tile-101',
        name: 'Tile 101',
        areaSquareMetres: 2000,
        geometry: {'type': 'Polygon', 'coordinates': []},
      );

      await _pumpPartyMapScreen(
        tester,
        party: joined,
        partyService: partyService,
        mapController: mapController,
        uid: 'user-1',
      );

      expect(mapController.partyTileOwnership['tile-101'], 'A');
      expect(find.text('1 tiles'), findsOneWidget);

      // Now move to tile-102 (unclaimed)
      mapController.currentRegion = const RegionPolygon(
        id: 'tile-102',
        name: 'Tile 102',
        areaSquareMetres: 2000,
        geometry: {'type': 'Polygon', 'coordinates': []},
      );
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      mapController.notifyListeners();
      await tester.pumpAndSettle();

      // Tile 101 should STILL be owned by Team A!
      expect(mapController.partyTileOwnership['tile-101'], 'A');
      expect(find.text('1 tiles'), findsOneWidget);
      expect(find.text('Tile 102'), findsOneWidget);
      expect(find.text('Unclaimed Tile'), findsOneWidget);
    },
  );

  testWidgets('tapping info icon opens details bottom sheet with rosters', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty();
    await partyService.joinParty(code: party.joinCode, uid: 'user-1');
    final joined = await partyService.joinParty(
      code: party.joinCode,
      uid: 'user-2',
    );

    await _pumpPartyMapScreen(
      tester,
      party: joined,
      partyService: partyService,
      uid: 'user-1',
    );

    await tester.tap(find.byTooltip('Party info'));
    await tester.pumpAndSettle();

    expect(find.text('Party Details'), findsOneWidget);
    expect(find.textContaining('user-1'), findsWidgets);
    expect(find.textContaining('user-2'), findsWidgets);
    expect(find.text('Leave Party'), findsOneWidget);
  });

  testWidgets('leaving party from details sheet calls leave and pops', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty();
    final joined = await partyService.joinParty(
      code: party.joinCode,
      uid: 'user-1',
    );

    Party? latestParty = joined;

    await _pumpPartyMapScreen(
      tester,
      party: joined,
      partyService: partyService,
      uid: 'user-1',
      onPartyChanged: (p) => latestParty = p,
    );

    await tester.tap(find.byTooltip('Party info'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leave Party'));
    await tester.pumpAndSettle();

    expect(latestParty, isNull);
  });
}
