import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/quests/screens/quest_controller.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';
import 'package:roam_io/features/quests/screens/quest_service.dart';
import 'package:roam_io/features/quests/screens/quest_verification_service.dart';
import 'package:roam_io/features/quests/screens/quests_screen.dart';
import 'package:roam_io/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  group('QuestsScreen', () {
    testWidgets('renders Side Quests screen', (tester) async {
      final controller = await _controller();

      await tester.pumpWidget(_app(controller));

      await tester.pumpAndSettle();

      expect(find.text('Side Quests'), findsOneWidget);

      expect(find.byType(QuestsScreen), findsOneWidget);
    });

    testWidgets('renders quest loaded from Firestore', (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(
        firestore,
        id: 'museum',
        title: 'Melbourne Museum Explorer',
        category: QuestCategory.culture,
        rewardXp: 250,
      );

      final controller = await _controller(firestore: firestore);

      await tester.pumpWidget(_app(controller));

      await tester.pumpAndSettle();

      expect(find.text('Melbourne Museum Explorer'), findsOneWidget);

      expect(find.text('+250 XP'), findsOneWidget);
    });

    testWidgets('renders multiple quests', (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(
        firestore,
        id: 'museum',
        title: 'Museum Explorer',
        category: QuestCategory.culture,
      );

      await _seedQuest(
        firestore,
        id: 'gardens',
        title: 'Garden Wanderer',
        category: QuestCategory.nature,
      );

      final controller = await _controller(firestore: firestore);

      await tester.pumpWidget(_app(controller));

      await tester.pumpAndSettle();

      expect(find.text('Museum Explorer'), findsOneWidget);

      expect(find.text('Garden Wanderer'), findsOneWidget);
    });

    testWidgets('does not render inactive quests', (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(firestore, id: 'active', title: 'Active Quest');

      await _seedQuest(
        firestore,
        id: 'inactive',
        title: 'Inactive Quest',
        isActive: false,
      );

      final controller = await _controller(firestore: firestore);

      await tester.pumpWidget(_app(controller));

      await tester.pumpAndSettle();

      expect(find.text('Active Quest'), findsOneWidget);

      expect(find.text('Inactive Quest'), findsNothing);
    });

    testWidgets('renders XP reward', (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(firestore, id: 'xp', title: 'XP Quest', rewardXp: 500);

      final controller = await _controller(firestore: firestore);

      await tester.pumpWidget(_app(controller));

      await tester.pumpAndSettle();

      expect(find.text('XP Quest'), findsOneWidget);

      expect(find.text('+500 XP'), findsOneWidget);
    });

    testWidgets('renders adventure quest', (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(
        firestore,
        id: 'adventure',
        title: 'Adventure Quest',
        category: QuestCategory.adventure,
      );

      final controller = await _controller(firestore: firestore);

      await tester.pumpWidget(_app(controller));

      await tester.pumpAndSettle();

      expect(find.text('Adventure Quest'), findsOneWidget);
    });

    testWidgets('renders nature quest', (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(
        firestore,
        id: 'nature',
        title: 'Nature Quest',
        category: QuestCategory.nature,
      );

      final controller = await _controller(firestore: firestore);

      await tester.pumpWidget(_app(controller));

      await tester.pumpAndSettle();

      expect(find.text('Nature Quest'), findsOneWidget);
    });

    testWidgets('renders culture quest', (tester) async {
      final firestore = FakeFirebaseFirestore();

      await _seedQuest(
        firestore,
        id: 'culture',
        title: 'Culture Quest',
        category: QuestCategory.culture,
      );

      final controller = await _controller(firestore: firestore);

      await tester.pumpWidget(_app(controller));

      await tester.pumpAndSettle();

      expect(find.text('Culture Quest'), findsOneWidget);
    });
  });
}

Future<QuestController> _controller({FakeFirebaseFirestore? firestore}) async {
  final database = firestore ?? FakeFirebaseFirestore();

  final controller = QuestController(
    questService: QuestService(firestore: database),
    verificationService: _UnusedQuestVerificationService(),
  );

  await controller.initialise();

  return controller;
}

Widget _app(QuestController controller) {
  final authProvider = AuthProvider(
    authRepository: _UnauthenticatedAuthRepository(),
  );

  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: QuestsScreen(controller: controller),
    ),
  );
}

Future<void> _seedQuest(
  FakeFirebaseFirestore firestore, {
  required String id,
  required String title,
  QuestCategory category = QuestCategory.adventure,
  int rewardXp = 200,
  bool isActive = true,
}) {
  return firestore.collection('quests').doc(id).set({
    'title': title,
    'description': 'Explore this location and complete the quest.',
    'category': category.name,
    'difficulty': QuestDifficulty.easy.name,
    'rewardXp': rewardXp,
    'verificationType': QuestVerificationType.gps.name,
    'isActive': isActive,
    'latitude': -37.8206,
    'longitude': 144.9585,
    'verificationRadiusMetres': 200,
    'estimatedMinutes': 45,
  });
}

class _UnusedQuestVerificationService extends QuestVerificationService {}

class _UnauthenticatedAuthRepository implements AuthRepository {
  @override
  Stream<User?> authStateChanges() {
    return Stream<User?>.value(null);
  }

  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}
