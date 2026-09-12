/*
 * Description:
 *   Widget tests for PartyScreen create/join flow and party-home view.
 */

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Future<void> _createNamedParty(
  WidgetTester tester, {
  String name = 'Weekend Wanderers',
}) async {
  await tester.tap(find.text('Create Party'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    name,
  );
  await tester.pump();
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Create Party'),
    ),
  );
  await tester.pumpAndSettle();
  if (find.text('Invite friends').evaluate().isNotEmpty) {
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  testWidgets(
    'no active party shows the introduction and create/join actions',
    (tester) async {
      final partyService = PartyService(firestore: FakeFirebaseFirestore());

      await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');

      expect(find.text('Create Party'), findsOneWidget);
      expect(find.text('Join Party'), findsOneWidget);
      expect(find.text('Roam.io,\nreimagined.'), findsOneWidget);
    },
  );

  testWidgets('landing actions stay centred at the bottom on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = PartyService(firestore: FakeFirebaseFirestore());
    await _pumpPartyScreen(tester, partyService: service, uid: 'user-1');

    final create = find.widgetWithText(ElevatedButton, 'Create Party');
    final join = find.widgetWithText(OutlinedButton, 'Join Party');
    expect(tester.getCenter(create).dx, 160);
    expect(tester.getCenter(join).dx, 160);
    expect(tester.getBottomLeft(join).dy, 548);
    final originalPosition = tester.getTopLeft(create);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(create), originalPosition);
    expect(tester.takeException(), isNull);

    await tester.tap(join);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Roam.io,\nreimagined.'), findsOneWidget);
  });

  testWidgets(
    'an external join replaces create and join with the active party',
    (tester) async {
      final service = PartyService(firestore: FakeFirebaseFirestore());
      await _pumpPartyScreen(tester, partyService: service, uid: 'user-1');
      final party = await service.createParty(uid: 'user-2');
      await service.joinParty(code: party.joinCode, uid: 'user-1');
      await tester.pumpAndSettle();

      expect(find.text('Party #${party.joinCode}'), findsOneWidget);
      expect(find.text('Create Party'), findsNothing);
      expect(find.text('Join Party'), findsNothing);
    },
  );

  testWidgets('creation asks for a name before opening the party map', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    await tester.tap(find.text('Create Party'));
    await tester.pumpAndSettle();

    expect(find.text('Name your party'), findsOneWidget);
    expect((await firestore.collection('parties').get()).docs, isEmpty);
    final createAction = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Create Party'),
      ),
    );
    expect(createAction.onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Weekend Wanderers');
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Create Party'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invite friends'), findsOneWidget);
    expect(
      find.text('No friends or people you follow available to invite yet.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final created = await firestore.collection('parties').get();
    final joinCode = created.docs.single.data()['joinCode'] as String;

    expect(find.byType(PartyMapScreen), findsOneWidget);
    expect(find.text('Weekend Wanderers'), findsOneWidget);
    expect(created.docs.single.data()['name'], 'Weekend Wanderers');
    expect(joinCode, isNotEmpty);
  });

  testWidgets('canceling the name step does not create a party', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = PartyService(firestore: firestore);
    await _pumpPartyScreen(tester, partyService: service, uid: 'user-1');

    await tester.tap(find.text('Create Party'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Party'), findsOneWidget);
    expect((await firestore.collection('parties').get()).docs, isEmpty);
  });

  testWidgets('creating a party assigns the creator to a team', (tester) async {
    final partyService = PartyService(firestore: FakeFirebaseFirestore());

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    await _createNamedParty(tester);

    expect(find.text('Team A (You)'), findsOneWidget);
  });

  testWidgets('creator can invite a friend before opening the map', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    await firestore.collection('follows').doc('user-1_user-2').set({
      'followerId': 'user-1',
      'followeeId': 'user-2',
    });
    await firestore.collection('public_profiles').doc('user-2').set({
      'uid': 'user-2',
      'username': 'friend',
      'displayName': 'Alex',
    });
    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    await tester.tap(find.text('Create Party'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Saturday Roam');
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Create Party'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invite friends'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    final inbox = await firestore
        .collection('profiles')
        .doc('user-2')
        .collection('notifications')
        .get();
    expect(inbox.docs.single.data()['type'], 'partyInvite');
    expect(inbox.docs.single.data()['partyId'], isNotEmpty);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(PartyMapScreen), findsOneWidget);
  });

  testWidgets('a party member can invite a friend from Party Mode', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    await partyService.createParty(uid: 'user-1', name: 'Sunday Roam');
    await firestore.collection('follows').doc('user-1_user-2').set({
      'followerId': 'user-1',
      'followeeId': 'user-2',
    });
    await firestore.collection('public_profiles').doc('user-2').set({
      'uid': 'user-2',
      'username': 'friend',
      'displayName': 'Alex',
    });
    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    await tester.tap(find.text('Invite Friends'));
    await tester.pumpAndSettle();
    expect(find.text('Alex'), findsOneWidget);
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('a friend in another party is greyed out and explains why', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final parties = PartyService(firestore: firestore);
    await parties.createParty(uid: 'user-1');
    await parties.createParty(uid: 'user-2');
    await firestore.collection('follows').doc('user-1_user-2').set({
      'followerId': 'user-1',
      'followeeId': 'user-2',
    });
    await firestore.collection('public_profiles').doc('user-2').set({
      'uid': 'user-2',
      'username': 'friend',
      'displayName': 'Alex',
    });
    await _pumpPartyScreen(tester, partyService: parties, uid: 'user-1');
    await tester.tap(find.text('Invite Friends'));
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Already in a party'), findsOneWidget);
    expect(find.text('Invite'), findsNothing);
    final label = tester.widget<Text>(find.text('Alex'));
    expect(label.style?.color, isNotNull);
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Cannot invite because this user is already a member of another party',
      ),
      findsOneWidget,
    );
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
    expect(find.text('Leave Party'), findsOneWidget);
    expect(find.text('Create Party'), findsNothing);
    expect(find.text('Join Party'), findsNothing);
    await tester.tap(find.text('Leave Party'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure?'), findsOneWidget);
    expect(find.text('Create Party'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Leave Party'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Party'), findsOneWidget);
    expect(find.text('Join Party'), findsOneWidget);
  });

  testWidgets('canceling leave confirmation keeps the user in the party', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty(uid: 'user-1');
    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');

    await tester.tap(find.text('Leave Party'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure?'), findsNothing);
    expect(find.text('Party #${party.joinCode}'), findsOneWidget);
    expect((await partyService.getUserParties('user-1')).single.id, party.id);
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
    await _createNamedParty(tester);

    expect(changes.first?.teamAMembers, ['user-1']);
  });

  testWidgets('a Create Party failure shows an error instead of nothing', (
    tester,
  ) async {
    final partyService = _FailingPartyService();

    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');
    await _createNamedParty(tester);

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

    expect(find.text('Party #${party.joinCode}'), findsOneWidget);
    expect(find.text('Join code: ${party.joinCode}'), findsOneWidget);
    expect(find.byTooltip('Copy join code'), findsOneWidget);
    expect(find.text('Your Party'), findsNothing);
    expect(find.text('Team A'), findsOneWidget);
    expect(find.text('View Map'), findsOneWidget);
    expect(find.text('Tiles Claimed'), findsNothing);
    expect(find.text('Team A Members'), findsOneWidget);
    expect(find.text('Team B Members'), findsOneWidget);
    expect(find.text('Leave Party'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Leave Party'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Leave Party'), findsNothing);
    final leaveAction = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Leave Party'),
    );
    expect(
      leaveAction.style?.textStyle?.resolve(<WidgetState>{})?.decoration,
      TextDecoration.underline,
    );
    expect(find.text('Create Party'), findsNothing);
    expect(find.text('Join Party'), findsNothing);
    expect(find.text('You'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('You')).style?.fontWeight,
      FontWeight.w700,
    );

    final sections = [
      find.text('Party #${party.joinCode}'),
      find.text('Join code: ${party.joinCode}'),
      find.text('View Map'),
      find.text('Team A'),
      find.text('Team A Members'),
      find.text('Leave Party'),
    ];
    final tops = sections
        .map((section) => tester.getTopLeft(section).dy)
        .toList();
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets(
    'a member can edit the party name without changing its join code',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final service = PartyService(firestore: firestore);
      final party = await service.createParty(uid: 'user-1', name: 'Old Name');
      await _pumpPartyScreen(tester, partyService: service, uid: 'user-1');

      expect(find.text('Old Name'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit party name'));
      await tester.pumpAndSettle();
      expect(find.text('Edit party name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'New Name');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('New Name'), findsOneWidget);
      expect(find.text('Old Name'), findsNothing);
      expect(find.text('Join code: ${party.joinCode}'), findsOneWidget);
      final stored = await firestore.collection('parties').doc(party.id).get();
      expect(stored.data()?['name'], 'New Name');
      expect(stored.data()?['joinCode'], party.joinCode);
    },
  );

  testWidgets('tapping the join code copies it to the clipboard', (
    tester,
  ) async {
    final partyService = PartyService(firestore: FakeFirebaseFirestore());
    final party = await partyService.createParty(uid: 'user-1');
    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');

    String? copiedCode;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedCode =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.tap(find.text('Join code: ${party.joinCode}'));
    await tester.pumpAndSettle();

    expect(copiedCode, party.joinCode);
  });

  testWidgets('claimed tile counts update while Party Mode is open', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final partyService = PartyService(firestore: firestore);
    final party = await partyService.createParty(uid: 'user-1');
    await _pumpPartyScreen(tester, partyService: partyService, uid: 'user-1');

    expect(find.text('0 tiles'), findsNWidgets(2));

    final tiles = firestore
        .collection('parties')
        .doc(party.id)
        .collection('tiles');
    await tiles.doc('a-tile').set({
      'teamADwellSeconds': 31,
      'teamBDwellSeconds': 0,
    });
    await tiles.doc('b-tile').set({
      'teamADwellSeconds': 0,
      'teamBDwellSeconds': 31,
    });
    await tiles.doc('another-a-tile').set({
      'teamADwellSeconds': 40,
      'teamBDwellSeconds': 0,
    });
    await tester.pumpAndSettle();

    expect(find.text('2 tiles'), findsOneWidget);
    expect(find.text('1 tile'), findsOneWidget);
  });

  testWidgets('team rosters update while Party Mode is open', (tester) async {
    final service = PartyService(firestore: FakeFirebaseFirestore());
    final party = await service.createParty(uid: 'user-1');
    await _pumpPartyScreen(tester, partyService: service, uid: 'user-1');

    await service.joinParty(code: party.joinCode, uid: 'user-2');
    await tester.pumpAndSettle();

    expect(find.text('Team B Members'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('user-2'), findsNothing);

    final profile = service.firestore
        .collection('public_profiles')
        .doc('user-2');
    await profile.set({
      'uid': 'user-2',
      'displayName': 'Alex Morgan',
      'username': 'alex',
    });
    await tester.pumpAndSettle();
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Alex Morgan')).style?.fontWeight,
      isNot(FontWeight.w700),
    );

    await profile.update({'displayName': 'Alex Rivera'});
    await tester.pumpAndSettle();
    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsNothing);
  });

  testWidgets('active party sections fit a narrow phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = PartyService(firestore: FakeFirebaseFirestore());
    final party = await service.createParty(uid: 'user-1');
    await service.joinParty(code: party.joinCode, uid: 'user-2');
    await _pumpPartyScreen(tester, partyService: service, uid: 'user-1');
    await tester.ensureVisible(find.text('Leave Party'));
    await tester.pumpAndSettle();

    expect(find.text('Team A Members'), findsOneWidget);
    expect(find.text('Team B Members'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(find.text(party.displayName), findsOneWidget);
  });
}

class _FailingPartyService implements PartyService {
  @override
  Future<Party> createParty({required String uid, String? name}) async {
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
