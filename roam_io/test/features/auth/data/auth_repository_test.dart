import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';
import 'package:roam_io/services/auth_service.dart';
import 'package:roam_io/services/profile_service.dart';
import 'package:roam_io/services/storage_service.dart';

void main() {
  late MockUser user;
  late _FakeAuthService authService;
  late _FakeProfileService profileService;
  late _FakeStorageService storageService;
  late AuthRepository repository;

  setUp(() {
    user = MockUser(uid: 'user-1', email: 'traveller@example.com');
    authService = _FakeAuthService(currentUserValue: user);
    profileService = _FakeProfileService(profile: _profile(uid: user.uid));
    storageService = _FakeStorageService();
    repository = AuthRepository(
      authService: authService,
      profileService: profileService,
      storageService: storageService,
    );
  });

  group('AuthRepository delegates', () {
    test('exposes auth state and current user from the auth service', () async {
      expect(repository.currentUser, user);
      expect(await repository.authStateChanges().first, user);
      expect(authService.authStateListenCount, 1);
    });

    test(
      'delegates simple auth workflows to the injected auth service',
      () async {
        await repository.signIn(
          email: 'traveller@example.com',
          password: 'secret',
        );
        await repository.sendPasswordResetEmail('traveller@example.com');
        await repository.sendVerificationEmail();
        await repository.reloadCurrentUser();
        await repository.changePassword(
          currentPassword: 'old-secret',
          newPassword: 'new-secret',
        );
        await repository.signOut();

        expect(authService.signInEmail, 'traveller@example.com');
        expect(authService.signInPassword, 'secret');
        expect(authService.passwordResetEmail, 'traveller@example.com');
        expect(authService.sendVerificationCount, 1);
        expect(authService.reloadCount, 1);
        expect(authService.changePasswordCurrent, 'old-secret');
        expect(authService.changePasswordNew, 'new-secret');
        expect(authService.signOutCount, 1);
      },
    );
  });

  group('AuthRepository signUp', () {
    test('creates profile and sends verification email', () async {
      authService.signUpCredential = _FakeUserCredential(
        MockUser(uid: 'new-user', email: 'new@example.com'),
      );

      await repository.signUp(
        email: 'new@example.com',
        password: 'secret',
        username: 'newbie',
        displayName: 'New Traveller',
      );

      final created = profileService.createdProfile;
      expect(authService.signUpEmail, 'new@example.com');
      expect(authService.signUpPassword, 'secret');
      expect(created, isNotNull);
      expect(created!.uid, 'new-user');
      expect(created.username, 'newbie');
      expect(created.displayName, 'New Traveller');
      expect(created.email, 'new@example.com');
      expect(created.darkModeEnabled, isFalse);
      expect(authService.sendVerificationCount, 1);
    });

    test('throws when Firebase returns a credential without a user', () async {
      authService.signUpCredential = _NullUserCredential();

      await expectLater(
        repository.signUp(
          email: 'new@example.com',
          password: 'secret',
          username: 'newbie',
          displayName: 'New Traveller',
        ),
        throwsA(
          isA<firebase_auth.FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'user-not-found',
          ),
        ),
      );

      expect(profileService.createdProfile, isNull);
      expect(authService.sendVerificationCount, 0);
    });
  });

  group('AuthRepository profile operations', () {
    test('updates display name for the current user', () async {
      await repository.updateDisplayName('New Name');

      expect(profileService.updatedDisplayNameUid, user.uid);
      expect(profileService.updatedDisplayName, 'New Name');
      expect(authService.updatedDisplayName, 'New Name');
    });

    test('throws when updating display name without a current user', () async {
      authService.currentUserValue = null;

      await expectLater(
        repository.updateDisplayName('New Name'),
        throwsA(isA<firebase_auth.FirebaseAuthException>()),
      );

      expect(profileService.updatedDisplayName, isNull);
    });

    test('loads the current profile only when signed in', () async {
      expect(await repository.getCurrentUserProfile(), profileService.profile);
      expect(profileService.requestedProfileUid, user.uid);

      authService.currentUserValue = null;
      expect(await repository.getCurrentUserProfile(), isNull);
    });

    test('updates dark mode, XP, and added XP for the current user', () async {
      await repository.updateDarkModePreference(true);
      await repository.updateXp(125);
      await repository.addXp(50);

      expect(profileService.darkModeUid, user.uid);
      expect(profileService.darkModeEnabled, isTrue);
      expect(profileService.updatedXpUid, user.uid);
      expect(profileService.updatedXp, 125);
      expect(profileService.addedXpUid, user.uid);
      expect(profileService.addedXp, 50);
    });

    test('throws guarded update calls when signed out', () async {
      authService.currentUserValue = null;

      await expectLater(
        repository.updateDarkModePreference(true),
        throwsA(isA<firebase_auth.FirebaseAuthException>()),
      );
      await expectLater(
        repository.updateXp(125),
        throwsA(isA<firebase_auth.FirebaseAuthException>()),
      );
      await expectLater(
        repository.addXp(50),
        throwsA(isA<firebase_auth.FirebaseAuthException>()),
      );
    });
  });

  group('AuthRepository profile photo uploads', () {
    test('throws when uploading a photo without a current user', () async {
      authService.currentUserValue = null;

      await expectLater(
        repository.uploadProfilePicture(image: _image([1, 2, 3])),
        throwsA(isA<firebase_auth.FirebaseAuthException>()),
      );

      expect(storageService.uploadCount, 0);
    });

    test('returns unchanged when selected bytes match stored hash', () async {
      final bytes = <int>[1, 2, 3];
      profileService.profile = _profile(uid: user.uid, photoHash: _hash(bytes));

      final result = await repository.uploadProfilePicture(
        image: _image(bytes),
      );

      expect(result, ProfilePhotoUploadResult.unchanged);
      expect(storageService.uploadCount, 0);
      expect(profileService.updatedPhotoUrl, isNull);
    });

    test('stores a hash for matching legacy photo URLs', () async {
      final bytes = <int>[1, 2, 3];
      profileService.profile = _profile(
        uid: user.uid,
        photoUrl: 'https://example.com/current.jpg',
      );
      storageService.downloadedBytes = Uint8List.fromList(bytes);

      final result = await repository.uploadProfilePicture(
        image: _image(bytes),
      );

      expect(result, ProfilePhotoUploadResult.unchanged);
      expect(storageService.downloadedUrl, 'https://example.com/current.jpg');
      expect(profileService.updatedPhotoHashUid, user.uid);
      expect(profileService.updatedPhotoHash, _hash(bytes));
      expect(storageService.uploadCount, 0);
    });

    test('uploads and stores changed profile photos', () async {
      final bytes = <int>[9, 8, 7];
      profileService.profile = _profile(
        uid: user.uid,
        photoUrl: 'https://example.com/current.jpg',
        photoHash: _hash([1, 2, 3]),
      );
      storageService.uploadedUrl = 'https://storage.example.com/new.jpg';

      final result = await repository.uploadProfilePicture(
        image: _image(bytes, name: 'new.jpg'),
      );

      expect(result, ProfilePhotoUploadResult.updated);
      expect(storageService.uploadUid, user.uid);
      expect(storageService.uploadedBytes, bytes);
      expect(storageService.uploadedFilename, isNotNull);
      expect(profileService.updatedPhotoUid, user.uid);
      expect(profileService.updatedPhotoUrl, storageService.uploadedUrl);
      expect(profileService.updatedPhotoHash, _hash(bytes));
    });

    test('uploads when legacy photo download fails or has no data', () async {
      final bytes = <int>[4, 5, 6];
      profileService.profile = _profile(
        uid: user.uid,
        photoUrl: 'https://example.com/current.jpg',
      );
      storageService.throwOnDownload = true;

      final result = await repository.uploadProfilePicture(
        image: _image(bytes),
      );

      expect(result, ProfilePhotoUploadResult.updated);
      expect(storageService.uploadCount, 1);
      expect(profileService.updatedPhotoHash, _hash(bytes));
    });
  });
}

ProfileModel _profile({
  required String uid,
  String? photoUrl,
  String? photoHash,
}) {
  final now = DateTime(2026, 5, 18, 12);
  return ProfileModel(
    uid: uid,
    username: 'traveller',
    displayName: 'Traveller',
    email: 'traveller@example.com',
    createdAt: now,
    updatedAt: now,
    darkModeEnabled: false,
    photoUrl: photoUrl,
    photoHash: photoHash,
  );
}

XFile _image(List<int> bytes, {String name = 'profile.jpg'}) {
  return XFile.fromData(Uint8List.fromList(bytes), name: name);
}

String _hash(List<int> bytes) => sha256.convert(bytes).toString();

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.currentUserValue});

  firebase_auth.User? currentUserValue;
  firebase_auth.UserCredential signUpCredential = _FakeUserCredential(
    MockUser(),
  );
  String? signUpEmail;
  String? signUpPassword;
  String? signInEmail;
  String? signInPassword;
  String? passwordResetEmail;
  String? updatedDisplayName;
  String? changePasswordCurrent;
  String? changePasswordNew;
  int authStateListenCount = 0;
  int sendVerificationCount = 0;
  int reloadCount = 0;
  int signOutCount = 0;

  @override
  Stream<firebase_auth.User?> authStateChanges() {
    authStateListenCount += 1;
    return Stream<firebase_auth.User?>.value(currentUserValue);
  }

  @override
  firebase_auth.User? get currentUser => currentUserValue;

  @override
  Future<firebase_auth.UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signUpEmail = email;
    signUpPassword = password;
    return signUpCredential;
  }

  @override
  Future<firebase_auth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInEmail = email;
    signInPassword = password;
    return _FakeUserCredential(currentUserValue);
  }

  @override
  Future<void> sendEmailVerification() async {
    sendVerificationCount += 1;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    passwordResetEmail = email;
  }

  @override
  Future<void> reloadCurrentUser() async {
    reloadCount += 1;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCurrent = currentPassword;
    changePasswordNew = newPassword;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    updatedDisplayName = displayName;
  }

  @override
  Future<void> signOut() async {
    signOutCount += 1;
  }
}

class _FakeProfileService implements ProfileService {
  _FakeProfileService({this.profile});

  ProfileModel? profile;
  ProfileModel? createdProfile;
  String? requestedProfileUid;
  String? updatedDisplayNameUid;
  String? updatedDisplayName;
  String? darkModeUid;
  bool? darkModeEnabled;
  String? updatedPhotoUid;
  String? updatedPhotoUrl;
  String? updatedPhotoHash;
  String? updatedPhotoHashUid;
  String? updatedXpUid;
  int? updatedXp;
  String? addedXpUid;
  int? addedXp;

  @override
  Future<void> createProfile(ProfileModel profile) async {
    createdProfile = profile;
  }

  @override
  Future<ProfileModel?> getProfile(String uid) async {
    requestedProfileUid = uid;
    return profile;
  }

  @override
  Future<void> updateDisplayName(String uid, String displayName) async {
    updatedDisplayNameUid = uid;
    updatedDisplayName = displayName;
  }

  @override
  Future<void> updateDarkModePreference({
    required String uid,
    required bool enabled,
  }) async {
    darkModeUid = uid;
    darkModeEnabled = enabled;
  }

  @override
  Future<void> updateProfilePhoto({
    required String uid,
    required String photoUrl,
    required String photoHash,
  }) async {
    updatedPhotoUid = uid;
    updatedPhotoUrl = photoUrl;
    updatedPhotoHash = photoHash;
  }

  @override
  Future<void> updateProfilePhotoHash({
    required String uid,
    required String photoHash,
  }) async {
    updatedPhotoHashUid = uid;
    updatedPhotoHash = photoHash;
  }

  @override
  Future<void> updateXp(String uid, int newXp) async {
    updatedXpUid = uid;
    updatedXp = newXp;
  }

  @override
  Future<void> addXp(String uid, int xpToAdd) async {
    addedXpUid = uid;
    addedXp = xpToAdd;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStorageService implements StorageService {
  String uploadedUrl = 'https://storage.example.com/profile.jpg';
  String? uploadUid;
  List<int>? uploadedBytes;
  String? uploadedFilename;
  String? downloadedUrl;
  Uint8List? downloadedBytes;
  bool throwOnDownload = false;
  int uploadCount = 0;

  @override
  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    required String filename,
  }) async {
    uploadCount += 1;
    uploadUid = uid;
    uploadedBytes = bytes.toList();
    uploadedFilename = filename;
    return uploadedUrl;
  }

  @override
  Future<Uint8List?> downloadBytesFromUrl(String url) async {
    downloadedUrl = url;
    if (throwOnDownload) {
      throw StateError('download failed');
    }
    return downloadedBytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserCredential implements firebase_auth.UserCredential {
  _FakeUserCredential(this.user);

  @override
  final firebase_auth.User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NullUserCredential extends _FakeUserCredential {
  _NullUserCredential() : super(null);
}
