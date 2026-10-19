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
    final party = await partyService.createParty(uid: 'user-1');
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

    expect(find.text(party.displayName), findsOneWidget);
    expect(find.text('Team A (You)'), findsOneWidget);
    expect(find.text('Team B'), findsOneWidget);
    expect(find.text('0 tiles'), findsNWidgets(2));
    expect(find.text('Locating Tile...'), findsOneWidget);
  });

  testWidgets('map title updates when a member renames the party', (
    tester,
  ) async {
    final service = PartyService(firestore: FakeFirebaseFirestore());
    final party = await service.createParty(uid: 'user-1', name: 'Old Name');
    await _pumpPartyMapScreen(
      tester,
      party: party,
      partyService: service,
      uid: 'user-1',
    );

    expect(find.text('Old Name'), findsOneWidget);
    await service.renameParty(
      partyId: party.id,
      uid: 'user-1',
      name: 'New Name',
    );
    await tester.pumpAndSettle();

    expect(find.text('New Name'), findsOneWidget);
    expect(find.text('Old Name'), findsNothing);
  });

  testWidgets(
    'shows a compact unclaimed tile summary and expands its dwell stats',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firestore = FakeFirebaseFirestore();
      final partyService = PartyService(firestore: firestore);
      final party = await partyService.createParty(uid: 'user-1');
      final joined = await partyService.joinParty(
        code: party.joinCode,
        uid: 'user-1',
      );

      const tileName = 'Clayton (North) - Nottingham Avenue SA1';
      final mapController = MapController();
      mapController.currentRegion = const RegionPolygon(
        id: 'tile-101',
        name: tileName,
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

      expect(find.text(tileName), findsOneWidget);
      expect(tester.widget<Text>(find.text(tileName)).maxLines, isNull);
      expect(tester.getSize(find.text(tileName)).height, greaterThan(25));
      expect(find.text('Unclaimed Tile'), findsOneWidget);
      expect(find.text('00:30 to claim'), findsOneWidget);
      expect(find.text('Show more'), findsOneWidget);
      expect(find.textContaining('Time in tile:'), findsNothing);
      expect(find.text('Team A: 00:00 · Team B: 00:00'), findsNothing);
      final collapsedTop = tester.getTopLeft(find.text(tileName)).dy;

      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text(tileName)).dy, lessThan(collapsedTop));
      expect(find.textContaining('Time in tile:'), findsOneWidget);
      expect(find.text('Team A: 00:00 · Team B: 00:00'), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Time in tile:'), findsNothing);
    },
  );

  testWidgets('shows countdown to overtake when inside an enemy-claimed tile', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty(uid: 'user-1');
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
    expect(find.text('Claimed by Team B'), findsOneWidget);
    expect(find.text('06:41 to overtake'), findsOneWidget);
    expect(find.textContaining('Enemy tile (Team B: 06:40)'), findsNothing);
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enemy tile (Team B: 06:40)'), findsOneWidget);
  });

  testWidgets('shows claimed status when tile is owned by user team', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty(uid: 'user-1');
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
    expect(find.text('Tile Claimed!'), findsNothing);
    expect(find.textContaining('Lead: +05:50'), findsNothing);
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(find.text('Tile Claimed!'), findsOneWidget);
    expect(find.textContaining('Lead: +05:50'), findsOneWidget);
    expect(find.text('1 tiles'), findsOneWidget); // Team A has 1 tile
    expect(mapController.partyTileOwnership['tile-101'], 'A');
  });

  testWidgets(
    'claimed tile remains owned and scoreboard persists when moving to another tile',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final partyService = PartyService(firestore: firestore);
      final party = await partyService.createParty(uid: 'user-1');
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
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);

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
      expect(find.text('Show more'), findsOneWidget);
      expect(find.textContaining('Time in tile:'), findsNothing);
    },
  );

  testWidgets('tapping info icon opens details bottom sheet with rosters', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty(uid: 'user-1');
    await partyService.joinParty(code: party.joinCode, uid: 'user-1');
    final joined = await partyService.joinParty(
      code: party.joinCode,
      uid: 'user-2',
    );
    await firestore.collection('public_profiles').doc('user-2').set({
      'uid': 'user-2',
      'displayName': 'Alex Morgan',
      'username': 'alex',
    });

    await _pumpPartyMapScreen(
      tester,
      party: joined,
      partyService: partyService,
      uid: 'user-1',
    );

    await tester.tap(find.byTooltip('Party info'));
    await tester.pumpAndSettle();

    expect(find.text('Party Details'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('user-2'), findsNothing);
    expect(find.text('Leave Party'), findsOneWidget);
  });

  testWidgets('leaving party from details sheet calls leave and pops', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty(uid: 'user-1');
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

    expect(find.text('Are you sure?'), findsOneWidget);
    expect(latestParty, isNotNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(latestParty, isNotNull);

    await tester.tap(find.text('Leave Party'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Leave Party'),
      ),
    );
    await tester.pumpAndSettle();

    expect(latestParty, isNull);
  });
}
