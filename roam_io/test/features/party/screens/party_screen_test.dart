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

  testWidgets('tapping Create Party shows the generated join code', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    await tester.tap(find.text('Create Party'));
    await tester.pumpAndSettle();

    final created = await firestore.collection('parties').get();
    final joinCode = created.docs.single.data()['joinCode'] as String;

    expect(find.textContaining(joinCode), findsOneWidget);
  });

  testWidgets('creating a party assigns the creator to a team', (
    tester,
  ) async {
    final partyService = PartyService(firestore: FakeFirebaseFirestore());

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    await tester.tap(find.text('Create Party'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Team A'), findsOneWidget);
  });

  testWidgets('entering a code in Join Party joins that party', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty();
    await partyService.joinParty(code: party.joinCode, uid: 'user-1');

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-2');
    await tester.tap(find.text('Join Party'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), party.joinCode);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Team B'), findsOneWidget);
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

  testWidgets('Leave Party returns to the no-active-party state', (
    tester,
  ) async {
    final partyService = PartyService(firestore: FakeFirebaseFirestore());

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    await tester.tap(find.text('Create Party'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave Party'));
    await tester.pumpAndSettle();

    expect(find.text('Create Party'), findsOneWidget);
    expect(find.text('Join Party'), findsOneWidget);
  });

  testWidgets('onPartyChanged fires with the joined party, then null on leave', (
    tester,
  ) async {
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
    await tester.tap(find.text('Leave Party'));
    await tester.pumpAndSettle();

    // The live party subscription can echo extra snapshots, so only the first
    // and last transitions are contractual.
    expect(changes.first?.teamAMembers, ['user-1']);
    expect(changes.last, isNull);
    expect(changes.whereType<Party>(), isNotEmpty);
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

  testWidgets('reopening with an existing party shows the party home', (
    tester,
  ) async {
    final partyService = PartyService(firestore: FakeFirebaseFirestore());
    final created = await partyService.createParty();
    final joined = await partyService.joinParty(
      code: created.joinCode,
      uid: 'user-1',
    );

    await _pumpPartyScreen(
      tester,
      partyService: partyService,
      uid: 'user-1',
      initialParty: joined,
    );

    expect(find.text('Leave Party'), findsOneWidget);
    expect(find.textContaining(created.joinCode), findsOneWidget);
  });

  testWidgets(
    'the party-home view live-updates when another user joins remotely',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final partyService = PartyService(firestore: firestore);

      await _pumpPartyScreen(
        tester,
        partyService: partyService,
        uid: 'user-1',
      );
      await tester.tap(find.text('Create Party'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Team B: []'), findsOneWidget);

      final created = await firestore.collection('parties').get();
      final joinCode = created.docs.single.data()['joinCode'] as String;
      await partyService.joinParty(code: joinCode, uid: 'user-2');
      await tester.pumpAndSettle();

      expect(find.textContaining('Team B: [user-2]'), findsOneWidget);
    },
  );

  testWidgets(
    'shows user parties in Your Parties list when not viewing a single party',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final partyService = PartyService(firestore: firestore);
      final party = await partyService.createParty();
      await partyService.joinParty(code: party.joinCode, uid: 'user-1');

      await _pumpPartyScreen(
        tester,
        partyService: partyService,
        uid: 'user-1',
      );

      expect(find.text('Your Parties'), findsOneWidget);
      expect(find.textContaining(party.joinCode), findsOneWidget);
      expect(find.text('View Map'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping View Party Map opens PartyMapScreen for that party',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final partyService = PartyService(firestore: firestore);
      final party = await partyService.createParty();
      final joined = await partyService.joinParty(
        code: party.joinCode,
        uid: 'user-1',
      );

      await _pumpPartyScreen(
        tester,
        partyService: partyService,
        uid: 'user-1',
        initialParty: joined,
      );

      expect(find.text('View Party Map'), findsOneWidget);
      await tester.tap(find.text('View Party Map'));
      await tester.pumpAndSettle();

      expect(find.byType(PartyMapScreen), findsOneWidget);
      expect(find.text('Party: ${party.joinCode}'), findsOneWidget);
    },
  );
}

class _FailingPartyService implements PartyService {
  @override
  Future<Party> createParty() async {
    throw Exception('permission-denied');
  }

  @override
  Stream<List<Party>> watchUserParties(String uid) => const Stream.empty();

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
