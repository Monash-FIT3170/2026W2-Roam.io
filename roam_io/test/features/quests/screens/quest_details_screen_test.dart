import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/data/user_quest.dart';
import 'package:roam_io/features/quests/screens/quest_controller.dart';
import 'package:roam_io/features/quests/screens/quest_details_screen.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';
import 'package:roam_io/features/quests/screens/quest_photo_service.dart';
import 'package:roam_io/theme/app_theme.dart';

void main() {
  group('QuestDetailsScreen', () {
    testWidgets('renders core quest information', (tester) async {
      final controller = _FakeQuestController();

      await _pumpScreen(
        tester,
        controller: controller,
        quest: _quest(
          title: 'Museum Explorer',
          description: 'Explore the museum.',
          rewardXp: 250,
          estimatedMinutes: 60,
          verificationRadiusMetres: 200,
        ),
      );

      expect(find.text('Side Quest'), findsOneWidget);
      expect(find.text('Museum Explorer'), findsOneWidget);
      expect(find.text('Explore the museum.'), findsOneWidget);

      // Hero reward.
      expect(find.text('+250 XP'), findsOneWidget);

      // Info-card reward.
      expect(find.text('250 XP'), findsOneWidget);

      expect(find.text('60 min'), findsOneWidget);
      expect(find.text('200 m'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);

      expect(find.text('Reward'), findsOneWidget);
      expect(find.text('Verification'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Location radius'), findsOneWidget);
    });

    testWidgets('unstarted quest shows Start Quest', (tester) async {
      final controller = _FakeQuestController();

      await _pumpScreen(tester, controller: controller, quest: _quest());

      expect(find.text('Start Quest'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('active GPS quest shows GPS verification UI', (tester) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
      );

      await _pumpScreen(
        tester,
        controller: controller,
        quest: _quest(verificationType: QuestVerificationType.gps),
      );

      expect(find.text('Quest in progress'), findsOneWidget);

      expect(
        find.text('Your current location will be checked.'),
        findsOneWidget,
      );

      expect(find.text('Verify & Complete'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

      expect(find.text('Add proof photo'), findsNothing);
      expect(find.text('Photo tip'), findsNothing);
    });

    testWidgets('active photo quest shows photo verification UI', (
      tester,
    ) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
      );

      await _pumpScreen(
        tester,
        controller: controller,
        quest: _quest(
          category: QuestCategory.photography,
          verificationType: QuestVerificationType.photo,
          verificationPrompt: 'Show the landmark clearly.',
        ),
      );

      expect(find.text('Quest in progress'), findsOneWidget);

      expect(
        find.text('Your proof photo will be checked by AI.'),
        findsOneWidget,
      );

      expect(find.text('Photo tip'), findsOneWidget);

      expect(
        find.text('Keep the landmark or main subject clearly visible.'),
        findsOneWidget,
      );

      expect(find.text('Add proof photo'), findsOneWidget);
      expect(find.text('Add Photo to Verify'), findsOneWidget);
      expect(find.byIcon(Icons.add_a_photo_rounded), findsWidgets);
    });

    testWidgets('active GPS and photo quest shows both requirements', (
      tester,
    ) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
      );

      await _pumpScreen(
        tester,
        controller: controller,
        quest: _quest(
          verificationType: QuestVerificationType.gpsAndPhoto,
          verificationPrompt: 'Show the attraction.',
        ),
      );

      expect(
        find.text('Your location and proof photo must both pass verification.'),
        findsOneWidget,
      );

      expect(find.text('Photo tip'), findsOneWidget);
      expect(find.text('Add proof photo'), findsOneWidget);
      expect(find.text('Add Photo to Verify'), findsOneWidget);
    });

    testWidgets('manual quest shows specialised verification message', (
      tester,
    ) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
      );

      await _pumpScreen(
        tester,
        controller: controller,
        quest: _quest(verificationType: QuestVerificationType.manual),
      );

      expect(
        find.text('This quest uses a specialised verification method.'),
        findsOneWidget,
      );

      expect(find.text('Verify & Complete'), findsOneWidget);
    });

    testWidgets('fitness quest shows fitness photo tip', (tester) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
      );

      await _pumpScreen(
        tester,
        controller: controller,
        quest: _quest(
          category: QuestCategory.fitness,
          verificationType: QuestVerificationType.photo,
          verificationPrompt: 'Show the trail.',
        ),
      );

      expect(
        find.text(
          'Include the trail, steps, landmark or surrounding area clearly.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('nature quest shows nature photo tip', (tester) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
      );

      await _pumpScreen(
        tester,
        controller: controller,
        quest: _quest(
          category: QuestCategory.nature,
          verificationType: QuestVerificationType.photo,
          verificationPrompt: 'Show the environment.',
        ),
      );

      expect(
        find.text(
          'Capture a clear view of the location and surrounding environment.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('culture quest shows venue photo tip', (tester) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
      );

      await _pumpScreen(
        tester,
        controller: controller,
        quest: _quest(
          category: QuestCategory.culture,
          verificationType: QuestVerificationType.photo,
          verificationPrompt: 'Show the venue.',
        ),
      );

      expect(
        find.text('Include a recognisable part of the venue or landmark.'),
        findsOneWidget,
      );
    });

    testWidgets('history quest shows venue photo tip', (tester) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
      );

      await _pumpScreen(
        tester,
        controller: controller,
        quest: _quest(
          category: QuestCategory.history,
          verificationType: QuestVerificationType.photo,
          verificationPrompt: 'Show the landmark.',
        ),
      );

      expect(
        find.text('Include a recognisable part of the venue or landmark.'),
        findsOneWidget,
      );
    });

    testWidgets('adventure photo quest shows default photo tip', (
      tester,
    ) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
      );

      await _pumpScreen(
        tester,
        controller: controller,
        quest: _quest(
          category: QuestCategory.adventure,
          verificationType: QuestVerificationType.photo,
          verificationPrompt: 'Show the location.',
        ),
      );

      expect(
        find.text('Include the landmark or surroundings clearly in the frame.'),
        findsOneWidget,
      );
    });

    testWidgets('completed quest shows completed state', (tester) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.completed),
      );

      await _pumpScreen(tester, controller: controller, quest: _quest());

      expect(find.text('Quest completed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      expect(find.text('Start Quest'), findsNothing);
      expect(find.text('Verify & Complete'), findsNothing);
    });

    testWidgets('submitted quest shows waiting state', (tester) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.submitted),
      );

      await _pumpScreen(tester, controller: controller, quest: _quest());

      expect(find.text('Waiting for verification'), findsOneWidget);
      expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
    });

    testWidgets('rejected quest shows rejected state', (tester) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.rejected),
      );

      await _pumpScreen(tester, controller: controller, quest: _quest());

      expect(find.text('Verification rejected'), findsOneWidget);
      expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
    });

    testWidgets('expired quest shows expired state', (tester) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.expired),
      );

      await _pumpScreen(tester, controller: controller, quest: _quest());

      expect(find.text('Quest expired'), findsOneWidget);
    });

    testWidgets('available progress shows available state', (tester) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.available),
      );

      await _pumpScreen(tester, controller: controller, quest: _quest());

      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('successful completion message is rendered', (tester) async {
      final controller = _FakeQuestController(
        completionMessage: 'Quest completed! +200 XP',
        lastVerificationPassed: true,
      );

      await _pumpScreen(tester, controller: controller, quest: _quest());

      expect(find.text('Quest completed! +200 XP'), findsOneWidget);

      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('failed verification message is rendered as error', (
      tester,
    ) async {
      final controller = _FakeQuestController(
        completionMessage: 'Move closer to the quest location.',
        lastVerificationPassed: false,
      );

      await _pumpScreen(tester, controller: controller, quest: _quest());

      expect(find.text('Move closer to the quest location.'), findsOneWidget);

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('controller error message is rendered', (tester) async {
      final controller = _FakeQuestController(
        errorMessage: 'Could not complete quest.',
      );

      await _pumpScreen(tester, controller: controller, quest: _quest());

      expect(find.text('Could not complete quest.'), findsOneWidget);

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('starting state disables start button and changes label', (
      tester,
    ) async {
      final controller = _FakeQuestController(isStartingQuestValue: true);

      await _pumpScreen(tester, controller: controller, quest: _quest());

      expect(find.text('Starting...'), findsOneWidget);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));

      expect(button.onPressed, isNull);
    });

    testWidgets('completing state displays verifying state', (tester) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
        isCompletingQuestValue: true,
      );

      await _pumpScreen(
        tester,
        controller: controller,
        quest: _quest(verificationType: QuestVerificationType.gps),
      );

      expect(find.text('Verifying...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('photo button opens proof source sheet', (tester) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
      );

      await _pumpScreen(
        tester,
        controller: controller,
        quest: _quest(
          verificationType: QuestVerificationType.photo,
          verificationPrompt: 'Show the location.',
        ),
      );

      await tester.tap(find.text('Add proof photo'));
      await tester.pumpAndSettle();

      expect(find.text('Add quest proof'), findsOneWidget);

      expect(
        find.text(
          'Choose a clear photo showing the quest location or activity.',
        ),
        findsOneWidget,
      );

      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
    });

    testWidgets('camera option safely handles cancelled photo selection', (
      tester,
    ) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
      );

      final photoService = _FakeQuestPhotoService();

      await _pumpScreen(
        tester,
        controller: controller,
        photoService: photoService,
        quest: _quest(
          verificationType: QuestVerificationType.photo,
          verificationPrompt: 'Show the location.',
        ),
      );

      await tester.tap(find.text('Add proof photo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      expect(photoService.takePhotoCalls, 1);

      // No photo was returned, so the original empty state remains.
      expect(find.text('Add proof photo'), findsOneWidget);
    });

    testWidgets('gallery option safely handles cancelled photo selection', (
      tester,
    ) async {
      final controller = _FakeQuestController(
        progress: _progress(QuestStatus.active),
      );

      final photoService = _FakeQuestPhotoService();

      await _pumpScreen(
        tester,
        controller: controller,
        photoService: photoService,
        quest: _quest(
          verificationType: QuestVerificationType.photo,
          verificationPrompt: 'Show the location.',
        ),
      );

      await tester.tap(find.text('Add proof photo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(photoService.galleryCalls, 1);
      expect(find.text('Add proof photo'), findsOneWidget);
    });

    testWidgets('all quest categories render successfully', (tester) async {
      for (final category in QuestCategory.values) {
        final controller = _FakeQuestController();

        await _pumpScreen(
          tester,
          controller: controller,
          quest: _quest(
            id: 'quest-${category.name}',
            title: '${category.displayName} Test Quest',
            category: category,
          ),
        );

        expect(find.text('${category.displayName} Test Quest'), findsOneWidget);

        expect(find.text(category.displayName.toUpperCase()), findsOneWidget);
      }
    });
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeQuestController controller,
  required Quest quest,
  _FakeQuestPhotoService? photoService,
}) async {
  // Give the test a tall viewport so the full quest details ListView
  // is rendered without needing to scroll for normal assertions.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 2400);

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ChangeNotifierProvider<QuestController>.value(
      value: controller,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: QuestDetailsScreen(
          quest: quest,
          photoService: photoService ?? _FakeQuestPhotoService(),
        ),
      ),
    ),
  );

  // Do not use pumpAndSettle here.
  // CircularProgressIndicator intentionally animates forever.
  await tester.pump();
}

Quest _quest({
  String id = 'quest-1',
  String title = 'Test Quest',
  String description = 'Complete this quest.',
  QuestCategory category = QuestCategory.adventure,
  QuestDifficulty difficulty = QuestDifficulty.easy,
  QuestVerificationType verificationType = QuestVerificationType.gps,
  int rewardXp = 200,
  double? verificationRadiusMetres = 200,
  String? verificationPrompt,
  int? estimatedMinutes = 45,
}) {
  return Quest(
    id: id,
    title: title,
    description: description,
    category: category,
    difficulty: difficulty,
    rewardXp: rewardXp,
    verificationType: verificationType,
    isActive: true,
    latitude: -37.81,
    longitude: 144.96,
    verificationRadiusMetres: verificationRadiusMetres,
    verificationPrompt: verificationPrompt,
    estimatedMinutes: estimatedMinutes,
  );
}

UserQuest _progress(QuestStatus status) {
  return UserQuest(
    id: 'quest-1',
    userId: 'user-1',
    questId: 'quest-1',
    status: status,
    startedAt: DateTime(2026, 8, 20),
    submittedAt: status == QuestStatus.submitted ? DateTime(2026, 8, 21) : null,
    completedAt: status == QuestStatus.completed ? DateTime(2026, 8, 21) : null,
    rejectionReason: status == QuestStatus.rejected
        ? 'Verification rejected.'
        : null,
  );
}

/// Lightweight controller double.
///
/// This deliberately implements QuestController instead of constructing the
/// real controller. That prevents QuestVerificationService from constructing
/// QuestAiVerificationService/FirebaseFunctions during widget tests.
class _FakeQuestController extends ChangeNotifier implements QuestController {
  _FakeQuestController({
    this.progress,
    this.completionMessage,
    this.errorMessage,
    this.lastVerificationPassed,
    this.isStartingQuestValue = false,
    this.isCompletingQuestValue = false,
  });

  final UserQuest? progress;

  @override
  String? completionMessage;

  @override
  String? errorMessage;

  @override
  bool? lastVerificationPassed;

  final bool isStartingQuestValue;
  final bool isCompletingQuestValue;

  @override
  bool get isStartingQuest => isStartingQuestValue;

  @override
  bool get isCompletingQuest => isCompletingQuestValue;

  @override
  UserQuest? progressForQuest(String questId) {
    return progress;
  }

  @override
  void clearMessages({bool notify = true}) {
    completionMessage = null;
    errorMessage = null;
    lastVerificationPassed = null;

    if (notify) {
      notifyListeners();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

/// Photo-service double that never touches Firebase Storage or image_picker.
class _FakeQuestPhotoService implements QuestPhotoService {
  int takePhotoCalls = 0;
  int galleryCalls = 0;
  int uploadCalls = 0;

  @override
  Future<QuestPhotoSelection?> takePhoto() async {
    takePhotoCalls += 1;
    return null;
  }

  @override
  Future<QuestPhotoSelection?> chooseFromGallery() async {
    galleryCalls += 1;
    return null;
  }

  @override
  Future<String> uploadQuestProof({
    required String userId,
    required String questId,
    required QuestPhotoSelection photo,
  }) async {
    uploadCalls += 1;
    return 'https://example.com/test-proof.jpg';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}
