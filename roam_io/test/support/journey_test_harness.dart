import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/journeys/data/journey_controller.dart';
import 'package:roam_io/features/journeys/domain/journey.dart';
import 'package:roam_io/features/journeys/domain/journey_location.dart';
import 'package:roam_io/features/journeys/domain/transport_mode.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

import 'fake_firebase_user.dart';

/// Auth repository that provides a stable signed-in user for journey widgets.
class JourneyTestAuthRepository implements AuthRepository {
  JourneyTestAuthRepository()
    : _user = FakeFirebaseUser(
        uid: 'journey-test-user',
        email: 'journey@test.com',
        emailVerified: true,
      ),
      _profile = ProfileModel(
        uid: 'journey-test-user',
        username: 'journey-test',
        displayName: 'Journey Test User',
        email: 'journey@test.com',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );

  final firebase_auth.User _user;
  final ProfileModel _profile;

  @override
  Stream<firebase_auth.User?> authStateChanges() => Stream.value(_user);

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<ProfileModel?> getCurrentUserProfile() async => _profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Journey controller backed by deterministic in-memory journey history.
class JourneyTestController extends JourneyController {
  @override
  Stream<List<Journey>> getJourneysStream(String userId) {
    return Stream.value(_journeys);
  }
}

final _journeys = <Journey>[
  _journey('one', 32),
  _journey('two', 50),
  _journey('three', 84),
];

Journey _journey(String id, int xp) {
  final start = DateTime(2026, 5, 1, 9);
  return Journey(
    id: id,
    userId: 'journey-test-user',
    startTime: start,
    endTime: start.add(const Duration(minutes: 20)),
    startLocation: const JourneyLocation(
      latLng: LatLng(-37.81, 144.96),
      displayName: 'Home',
    ),
    endLocation: const JourneyLocation(
      latLng: LatLng(-37.82, 144.97),
      displayName: 'Work',
    ),
    transportMode: TransportMode.walk,
    encodedRoute: '',
    distanceMeters: 1000,
    durationSeconds: 1200,
    xpEarned: xp,
    journeyXpEarned: xp,
  );
}
