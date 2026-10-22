import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/quest_controller.dart';
import 'package:roam_io/features/quests/screens/quest_details_screen.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';
import 'package:roam_io/features/quests/screens/quest_service.dart';
import 'package:roam_io/features/quests/screens/quest_submission.dart';
import 'package:roam_io/features/quests/screens/quest_verification.dart';
import 'package:roam_io/features/quests/screens/quest_verification_service.dart';
import 'package:roam_io/features/quests/screens/quests_screen.dart';
import 'package:roam_io/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestFirebaseCoreHostApi.setUp(_FirebaseApp());
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  });

  testWidgets(
    'start and complete updates counts, preserves filters and awards XP once',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await _seed(db);
      final controller = await _pump(tester, db);
      await tester.tap(find.byKey(const ValueKey('quest-status-available')));
      await tester.ensureVisible(find.text('Nature'));
      await tester.tap(find.text('Nature'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Garden walk'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Quest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Quest'));
      await tester.pumpAndSettle();
      expect(find.text('Active'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(controller.selectedStatus, QuestStatusFilter.available);
      expect(controller.selectedCategory, QuestCategory.nature);
      expect(find.text('Available (0)'), findsOneWidget);
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('No available quests here'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('quest-status-active')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Garden walk'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Verify & Complete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify & Complete'));
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      await tester.ensureVisible(find.text('Back to Side Quests'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to Side Quests'));
      await tester.pumpAndSettle();
      expect(controller.selectedStatus, QuestStatusFilter.active);
      expect(controller.selectedCategory, QuestCategory.nature);
      expect(find.text('Active (0)'), findsOneWidget);
      expect(find.text('Completed (1)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quest-status-completed')));
      await tester.pumpAndSettle();
      expect(find.text('Garden walk'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(controller.selectedStatus, QuestStatusFilter.completed);
      expect(find.text('Completed (1)'), findsOneWidget);
      await tester.tap(find.text('Garden walk'));
      await tester.pumpAndSettle();
      expect(find.text('Start Quest'), findsNothing);
      expect(find.text('Verify & Complete'), findsNothing);
      expect((await db.doc('profiles/uat-user').get()).data()!['xp'], 200);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'historical completion and expired activity have matching detail states',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await _seed(db, active: false, status: QuestStatus.completed);
      final controller = await _pump(tester, db);
      await tester.tap(find.byKey(const ValueKey('quest-status-completed')));
      await tester.pumpAndSettle();
      expect(find.text('Garden walk'), findsOneWidget);
      await tester.tap(find.text('Garden walk'));
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Verify & Complete'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await db.doc('profiles/uat-user/quests/garden').update({
        'status': 'active',
      });
      await controller.loadQuests(userId: 'uat-user');
      controller.resetFilters();
      await tester.pumpAndSettle();
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Active (0)'), findsOneWidget);
      await tester.tap(find.text('Garden walk'));
      await tester.pumpAndSettle();
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Start Quest'), findsNothing);
      expect(find.text('Verify & Complete'), findsNothing);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'small screen with large text supports filters and details (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = FakeFirebaseFirestore();
        await _seed(db, status: QuestStatus.submitted);
        await _pump(tester, db, textScale: 2, dark: dark);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('quest-status-active')),
        );
        await tester.tap(find.byKey(const ValueKey('quest-status-active')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Garden walk'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Garden walk'));
        await tester.pumpAndSettle();
        expect(find.byType(QuestDetailsScreen), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Awaiting verification'),
          150,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Awaiting verification'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _seed(
  FakeFirebaseFirestore db, {
  bool active = true,
  QuestStatus? status,
}) async {
  await db.doc('quests/garden').set({
    'title': 'Garden walk',
    'description': 'Explore the gardens.',
    'category': 'nature',
    'difficulty': 'easy',
    'rewardXp': 200,
    'verificationType': 'gps',
    'isActive': active,
    'estimatedMinutes': 45,
  });
  if (status != null) {
    await db.doc('profiles/uat-user/quests/garden').set({
      'questId': 'garden',
      'status': status.name,
    });
  }
}

Future<QuestController> _pump(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  double textScale = 1,
  bool dark = false,
}) async {
  final controller = QuestController(
    questService: QuestService(firestore: db),
    verificationService: _Verification(),
  );
  final auth = AuthProvider(authRepository: _AuthRepository());
  await tester.pump();
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: QuestsScreen(controller: controller)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(controller.dispose);
  addTearDown(auth.dispose);
  return controller;
}

class _AuthRepository implements AuthRepository {
  @override
  final User currentUser = MockUser(uid: 'uat-user');
  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Verification extends QuestVerificationService {
  @override
  Future<QuestSubmission> createSubmission({required Quest quest}) async =>
      QuestSubmission(questId: quest.id);
  @override
  Future<QuestVerificationResult> verify({
    required Quest quest,
    required QuestSubmission submission,
    Uint8List? photoBytes,
    String photoMimeType = 'image/jpeg',
  }) async =>
      const QuestVerificationResult(isVerified: true, message: 'Verified.');
}

class _FirebaseApp extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    final apps = await super.initializeCore();
    apps.single.options.storageBucket = 'test-project.appspot.com';
    return apps;
  }
}
