/*
 * Description:
 *   Verifies AuthProvider's High Contrast and Larger Text state: defaults,
 *   persisted updates, the unsaved slider preview, and failure handling.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  late _AccessibilityRepository repository;
  late AuthProvider provider;

  Future<void> signIn({bool failWrites = false}) async {
    repository = _AccessibilityRepository(failWrites: failWrites);
    provider = AuthProvider(authRepository: repository);
    await Future<void>.delayed(Duration.zero);
    await provider.refreshCurrentUser();
  }

  tearDown(() => provider.dispose());

  test('exposes the profile defaults', () async {
    await signIn();

    expect(provider.highContrastEnabled, isFalse);
    expect(provider.largerTextEnabled, isFalse);
    expect(provider.largerTextScale, ProfileModel.defaultTextScale);
  });

  test('updateHighContrastPreference saves and updates local state', () async {
    await signIn();
    final before = provider.currentProfile!.updatedAt;

    await provider.updateHighContrastPreference(true);

    expect(repository.highContrastWrites, <bool>[true]);
    expect(provider.highContrastEnabled, isTrue);
    expect(provider.largerTextEnabled, isFalse);
    expect(provider.currentProfile!.updatedAt.isAfter(before), isTrue);
  });

  test('updateLargerTextPreference saves and updates local state', () async {
    await signIn();

    await provider.updateLargerTextPreference(true);

    expect(repository.largerTextWrites, <bool>[true]);
    expect(provider.largerTextEnabled, isTrue);
    expect(provider.highContrastEnabled, isFalse);
  });

  test('previewLargerTextScale updates state without saving', () async {
    await signIn();
    var notified = 0;
    provider.addListener(() => notified++);

    provider.previewLargerTextScale(1.6);

    expect(provider.largerTextScale, 1.6);
    expect(notified, 1);
    expect(repository.scaleWrites, isEmpty);
  });

  test('updateLargerTextScale saves and updates local state', () async {
    await signIn();

    await provider.updateLargerTextScale(1.4);

    expect(repository.scaleWrites, <double>[1.4]);
    expect(provider.largerTextScale, 1.4);
  });

  test(
    'a failed write leaves the preference unchanged and sets an error',
    () async {
      await signIn(failWrites: true);

      await provider.updateHighContrastPreference(true);

      expect(provider.highContrastEnabled, isFalse);
      expect(provider.errorMessage, isNotNull);
    },
  );
}

class _AccessibilityRepository implements AuthRepository {
  _AccessibilityRepository({this.failWrites = false});

  final bool failWrites;
  final firebase_auth.User _user = FakeFirebaseUser(
    uid: 'u1',
    email: 't@t.com',
  );
  final List<bool> highContrastWrites = <bool>[];
  final List<bool> largerTextWrites = <bool>[];
  final List<double> scaleWrites = <double>[];

  final ProfileModel _profile = ProfileModel(
    uid: 'u1',
    username: 't',
    displayName: 'Traveller',
    email: 't@t.com',
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
  );

  void _maybeFail() {
    if (failWrites) {
      throw firebase_auth.FirebaseAuthException(code: 'network-request-failed');
    }
  }

  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield _user;
  }

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<ProfileModel?> getCurrentUserProfile() async => _profile;

  @override
  Future<void> updateHighContrastPreference(bool enabled) async {
    _maybeFail();
    highContrastWrites.add(enabled);
  }

  @override
  Future<void> updateLargerTextPreference(bool enabled) async {
    _maybeFail();
    largerTextWrites.add(enabled);
  }

  @override
  Future<void> updateLargerTextScale(double scale) async {
    _maybeFail();
    scaleWrites.add(scale);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
