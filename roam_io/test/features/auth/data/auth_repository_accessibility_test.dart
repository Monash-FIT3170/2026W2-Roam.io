/*
 * Description:
 *   Verifies AuthRepository's accessibility preference writes: each one
 *   targets the signed-in user's profile, and all fail without a user.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/services/auth_service.dart';
import 'package:roam_io/services/profile_service.dart';
import 'package:roam_io/services/storage_service.dart';

void main() {
  late _RecordingProfileService profileService;

  AuthRepository repositoryFor(firebase_auth.User? user) => AuthRepository(
    authService: _StubAuthService(user),
    profileService: profileService,
    storageService: _StubStorageService(),
  );

  setUp(() => profileService = _RecordingProfileService());

  group('with a signed-in user', () {
    late AuthRepository repository;

    setUp(() {
      repository = repositoryFor(MockUser(uid: 'user-1'));
    });

    test('updateHighContrastPreference writes for the current uid', () async {
      await repository.updateHighContrastPreference(true);

      expect(profileService.calls, <String>['highContrast user-1 true']);
    });

    test('updateLargerTextPreference writes for the current uid', () async {
      await repository.updateLargerTextPreference(false);

      expect(profileService.calls, <String>['largerText user-1 false']);
    });

    test('updateLargerTextScale writes for the current uid', () async {
      await repository.updateLargerTextScale(1.4);

      expect(profileService.calls, <String>['textScale user-1 1.4']);
    });
  });

  group('without a signed-in user', () {
    late AuthRepository repository;

    setUp(() {
      repository = repositoryFor(null);
    });

    for (final entry in <String, Future<void> Function(AuthRepository)>{
      'updateHighContrastPreference': (r) =>
          r.updateHighContrastPreference(true),
      'updateLargerTextPreference': (r) => r.updateLargerTextPreference(true),
      'updateLargerTextScale': (r) => r.updateLargerTextScale(1.4),
    }.entries) {
      test('${entry.key} throws user-not-found and writes nothing', () async {
        await expectLater(
          entry.value(repository),
          throwsA(
            isA<firebase_auth.FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'user-not-found',
            ),
          ),
        );
        expect(profileService.calls, isEmpty);
      });
    }
  });
}

class _StubAuthService implements AuthService {
  _StubAuthService(this._user);

  final firebase_auth.User? _user;

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubStorageService implements StorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingProfileService implements ProfileService {
  final List<String> calls = <String>[];

  @override
  Future<void> updateHighContrastPreference({
    required String uid,
    required bool enabled,
  }) async => calls.add('highContrast $uid $enabled');

  @override
  Future<void> updateLargerTextPreference({
    required String uid,
    required bool enabled,
  }) async => calls.add('largerText $uid $enabled');

  @override
  Future<void> updateLargerTextScale({
    required String uid,
    required double scale,
  }) async => calls.add('textScale $uid $scale');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
