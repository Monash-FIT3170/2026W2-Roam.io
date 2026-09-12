/*
 * Description:
 *   Widget tests for PartyScreen create/join flow and party-home view.
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
import 'package:roam_io/features/party/data/party_service.dart';
import 'package:roam_io/features/party/domain/party.dart';
import 'package:roam_io/features/party/screens/party_map_screen.dart';
import 'package:roam_io/features/party/screens/party_screen.dart';

import '../../../support/fake_firebase_user.dart';

Future<void> _pumpPartyScreen(
  WidgetTester tester, {
  required PartyService partyService,
  required String uid,
  Party? initialParty,
  ValueChanged<Party?>? onPartyChanged,
}) async {
  final auth = AuthProvider(authRepository: _PartyAuthRepository(uid));
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        home: PartyScreen(
          partyService: partyService,
          initialParty: initialParty,
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

  testWidgets('no active party shows the create/join form', (tester) async {
    final partyService = PartyService(firestore: FakeFirebaseFirestore());

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');

    expect(find.text('Create Party'), findsOneWidget);
    expect(find.text('Join Party'), findsOneWidget);
  });

  testWidgets(
    'an external join replaces create and join with the active party',
    (tester) async {
      final service = PartyService(firestore: FakeFirebaseFirestore());
      await _pumpPartyScreen(tester, partyService: service, uid: 'user-1');
      final party = await service.createParty(uid: 'user-2');
      await service.joinParty(code: party.joinCode, uid: 'user-1');
      await tester.pumpAndSettle();

      expect(find.text('Your Party'), findsOneWidget);
      expect(find.text('Create Party'), findsNothing);
      expect(find.text('Join Party'), findsNothing);
    },
  );

  testWidgets('tapping Create Party opens the party map with join code', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    await tester.tap(find.text('Create Party'));
    await tester.pumpAndSettle();

    final created = await firestore.collection('parties').get();
    final joinCode = created.docs.single.data()['joinCode'] as String;

    expect(find.byType(PartyMapScreen), findsOneWidget);
    expect(find.text('Party: $joinCode'), findsOneWidget);
  });

  testWidgets('creating a party assigns the creator to a team', (tester) async {
    final partyService = PartyService(firestore: FakeFirebaseFirestore());

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    await tester.tap(find.text('Create Party'));
    await tester.pumpAndSettle();

    expect(find.text('Team A (You)'), findsOneWidget);
  });

  testWidgets('entering a code in Join Party joins that party and opens map', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty(uid: 'user-1');
    await partyService.joinParty(code: party.joinCode, uid: 'user-1');

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-2');
    await tester.tap(find.text('Join Party'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), party.joinCode);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.byType(PartyMapScreen), findsOneWidget);
    expect(find.text('Team B (You)'), findsOneWidget);
  });

  testWidgets('an invalid join code shows a clear error', (tester) async {
    final partyService = PartyService(firestore: FakeFirebaseFirestore());

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    await tester.tap(find.text('Join Party'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'BADCOD');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('No party found for that code.'), findsOneWidget);
  });

  testWidgets('Leave Party returns to the create/join form', (tester) async {
    final partyService = PartyService(firestore: FakeFirebaseFirestore());
    final party = await partyService.createParty(uid: 'user-1');
    await partyService.joinParty(code: party.joinCode, uid: 'user-1');

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    expect(find.text('Leave'), findsOneWidget);
    expect(find.text('Create Party'), findsNothing);
    expect(find.text('Join Party'), findsNothing);
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('Create Party'), findsOneWidget);
    expect(find.text('Join Party'), findsOneWidget);
  });

  testWidgets('onPartyChanged fires with the joined party', (tester) async {
    final partyService = PartyService(firestore: FakeFirebaseFirestore());
    final changes = <Party?>[];

    await _pumpPartyScreen(
      tester,
      partyService: partyService,
      uid: 'user-1',
      onPartyChanged: changes.add,
    );
    await tester.tap(find.text('Create Party'));
    await tester.pumpAndSettle();

    expect(changes.first?.teamAMembers, ['user-1']);
  });

  testWidgets('a Create Party failure shows an error instead of nothing', (
    tester,
  ) async {
    final partyService = _FailingPartyService();

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    await tester.tap(find.text('Create Party'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not create a party. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the current party without create or join actions', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty(uid: 'user-1');
    await partyService.joinParty(code: party.joinCode, uid: 'user-1');

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');

    expect(find.text('Your Party'), findsOneWidget);
    expect(find.textContaining(party.joinCode), findsOneWidget);
    expect(find.text('View Map'), findsOneWidget);
    expect(find.text('Create Party'), findsNothing);
    expect(find.text('Join Party'), findsNothing);
  });

  testWidgets('tapping View Map opens PartyMapScreen for that party', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty(uid: 'user-1');
    await partyService.joinParty(code: party.joinCode, uid: 'user-1');

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');

    expect(find.text('View Map'), findsOneWidget);
    await tester.tap(find.text('View Map'));
    await tester.pumpAndSettle();

    expect(find.byType(PartyMapScreen), findsOneWidget);
    expect(find.text('Party: ${party.joinCode}'), findsOneWidget);
  });
}

class _FailingPartyService implements PartyService {
  @override
  Future<Party> createParty({required String uid}) async {
    throw Exception('permission-denied');
  }

  @override
  Stream<List<Party>> watchUserParties(String uid) => Stream.value([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PartyAuthRepository implements AuthRepository {
  _PartyAuthRepository(String uid)
    : _user = FakeFirebaseUser(uid: uid, email: '$uid@test.com');

  final firebase_auth.User _user;

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield _user;
  }

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
