import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

import '../../../support/fake_firebase_user.dart';

void main() {
  late _Repository repository;
  late AuthProvider auth;

  setUp(() async {
    repository = _Repository();
    auth = AuthProvider(authRepository: repository);
    await auth.refreshCurrentUser();
  });
  tearDown(() async {
    auth.dispose();
    await repository.events.close();
  });

  test('completion awaits persistence and preserves profile edits', () async {
    final saving = auth.completeOnboarding();
    expect(auth.currentProfile!.onboardingCompleted, isFalse);
    repository.profile = repository.profile.copyWith(displayName: 'Updated');
    await auth.refreshCurrentUser();
    repository.write.complete();
    await saving;
    expect(auth.currentProfile!.onboardingCompleted, isTrue);
    expect(auth.currentProfile!.displayName, 'Updated');
  });

  test(
    'failed persistence leaves tutorial pending and propagates failure',
    () async {
      final saving = auth.completeOnboarding();
      repository.write.completeError(StateError('Offline'));
      await expectLater(saving, throwsStateError);
      expect(auth.currentProfile!.onboardingCompleted, isFalse);
    },
  );

  test(
    'finishing an old account cannot mark a different account complete',
    () async {
      final saving = auth.completeOnboarding();
      repository.user = FakeFirebaseUser(
        uid: 'second',
        email: 'second@example.com',
        emailVerified: true,
      );
      repository.events.add(repository.user);
      await Future<void>.delayed(Duration.zero);
      expect(auth.currentProfile, isNull);
      repository.profile = ProfileModel.fromMap({
        'uid': 'second',
        'onboardingCompleted': false,
      });
      await auth.refreshCurrentUser();
      repository.write.complete();
      await saving;
      expect(auth.currentProfile!.uid, 'second');
      expect(auth.currentProfile!.onboardingCompleted, isFalse);
    },
  );

  test('cannot complete with a missing or mismatched profile', () async {
    repository.user = FakeFirebaseUser(
      uid: 'different',
      email: 'different@example.com',
    );
    repository.events.add(repository.user);
    await Future<void>.delayed(Duration.zero);
    await expectLater(auth.completeOnboarding(), throwsStateError);
    await auth.refreshCurrentUser();
    await expectLater(auth.completeOnboarding(), throwsStateError);
    expect(repository.writes, 0);
  });
}

class _Repository implements AuthRepository {
  User user = FakeFirebaseUser(
    uid: 'new',
    email: 'new@example.com',
    emailVerified: true,
  );
  ProfileModel profile = ProfileModel.fromMap({
    'uid': 'new',
    'onboardingCompleted': false,
  });
  final events = StreamController<User?>.broadcast();
  final write = Completer<void>();
  int writes = 0;

  @override
  Stream<User?> authStateChanges() => events.stream;
  @override
  User? get currentUser => user;
  @override
  Future<void> reloadCurrentUser() async {}
  @override
  Future<ProfileModel?> getCurrentUserProfile() async => profile;
  @override
  Future<void> completeOnboarding() {
    writes++;
    return write.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
