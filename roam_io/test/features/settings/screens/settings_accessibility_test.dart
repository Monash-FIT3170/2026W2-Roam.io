/*
 * Description:
 *   Tests the Settings accessibility controls: the High Contrast and Larger
 *   Text switches, and the text size slider that appears with Larger Text.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/features/settings/screens/settings_screen.dart';

import '../../../support/fake_firebase_user.dart';

const _contrastSwitch = ValueKey<String>('high-contrast-switch');
const _largerTextSwitch = ValueKey<String>('larger-text-switch');
const _slider = ValueKey<String>('text-size-slider');

void main() {
  late _FakeRepository repository;
  late AuthProvider provider;

  Future<void> pumpSettings(
    WidgetTester tester, {
    bool largerText = false,
    double scale = ProfileModel.defaultTextScale,
  }) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    repository = _FakeRepository(
      ProfileModel(
        uid: 'user-1',
        username: 'traveller',
        displayName: 'Traveller',
        email: 'traveller@example.com',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
        largerTextEnabled: largerText,
        largerTextScale: scale,
      ),
    );
    provider = AuthProvider(authRepository: repository);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> tapSwitch(WidgetTester tester, ValueKey<String> key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  testWidgets('shows both accessibility rows, switched off by default', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text('High Contrast'), findsOneWidget);
    expect(find.text('Larger Text'), findsOneWidget);
    expect(tester.widget<Switch>(find.byKey(_contrastSwitch)).value, isFalse);
    expect(tester.widget<Switch>(find.byKey(_largerTextSwitch)).value, isFalse);
    provider.dispose();
  });

  testWidgets('High Contrast switch persists the preference', (tester) async {
    await pumpSettings(tester);

    await tapSwitch(tester, _contrastSwitch);

    expect(repository.highContrastWrites, <bool>[true]);
    expect(provider.highContrastEnabled, isTrue);
    expect(tester.widget<Switch>(find.byKey(_contrastSwitch)).value, isTrue);
    provider.dispose();
  });

  testWidgets('Larger Text switch persists and reveals the slider', (
    tester,
  ) async {
    await pumpSettings(tester);
    expect(find.byKey(_slider), findsNothing);

    await tapSwitch(tester, _largerTextSwitch);

    expect(repository.largerTextWrites, <bool>[true]);
    expect(provider.largerTextEnabled, isTrue);
    expect(find.byKey(_slider), findsOneWidget);
    provider.dispose();
  });

  testWidgets('turning Larger Text off hides the slider', (tester) async {
    await pumpSettings(tester, largerText: true);
    expect(find.byKey(_slider), findsOneWidget);

    await tapSwitch(tester, _largerTextSwitch);

    expect(repository.largerTextWrites, <bool>[false]);
    expect(find.byKey(_slider), findsNothing);
    provider.dispose();
  });

  testWidgets('slider shows the current scale as a percentage', (tester) async {
    await pumpSettings(tester, largerText: true, scale: 1.4);

    await tester.ensureVisible(find.byKey(_slider));
    expect(find.text('140%'), findsOneWidget);
    expect(tester.widget<Slider>(find.byKey(_slider)).value, 1.4);
    provider.dispose();
  });

  testWidgets('dragging previews live and saves once on release', (
    tester,
  ) async {
    await pumpSettings(tester, largerText: true, scale: 1.2);
    await tester.ensureVisible(find.byKey(_slider));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_slider)),
    );
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();

    expect(provider.largerTextScale, greaterThan(1.2));
    expect(repository.scaleWrites, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(repository.scaleWrites, hasLength(1));
    expect(repository.scaleWrites.single, provider.largerTextScale);
    provider.dispose();
  });
}

class _FakeRepository implements AuthRepository {
  _FakeRepository(this._profile);

  final ProfileModel _profile;
  final firebase_auth.User _user = FakeFirebaseUser(
    uid: 'user-1',
    email: 'traveller@example.com',
  );
  final List<bool> highContrastWrites = <bool>[];
  final List<bool> largerTextWrites = <bool>[];
  final List<double> scaleWrites = <double>[];

  @override
  Stream<firebase_auth.User?> authStateChanges() =>
      Stream<firebase_auth.User?>.value(_user);

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Future<ProfileModel?> getCurrentUserProfile() async => _profile;

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> updateHighContrastPreference(bool enabled) async =>
      highContrastWrites.add(enabled);

  @override
  Future<void> updateLargerTextPreference(bool enabled) async =>
      largerTextWrites.add(enabled);

  @override
  Future<void> updateLargerTextScale(double scale) async =>
      scaleWrites.add(scale);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
