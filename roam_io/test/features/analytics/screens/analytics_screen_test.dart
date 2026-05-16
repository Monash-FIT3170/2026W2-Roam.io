/*
 * Author: Nathan Nunes
 * Last Modified: 14/05/2026
 * Description:
 *   Regression tests for analytics screen profile-driven stat values.
 */

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/analytics/screens/analytics_screen.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/map/data/visit.dart';
import 'package:roam_io/features/map/data/visit_service.dart';
import 'package:roam_io/features/map/data/visited_region_service.dart';
import 'package:roam_io/features/profile/domain/profile_model.dart';

void main() {
  testWidgets('shows current profile XP instead of placeholder XP', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 12345)),
    );
    await provider.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: AnalyticsScreen(
              visitService: _FakeVisitService(totalVisitCount: 0),
              visitedRegionService: _FakeVisitedRegionService(<String>{}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('XP Count'), findsOneWidget);
    expect(find.text('12,345'), findsOneWidget);
    expect(find.text('2,450'), findsNothing);

    provider.dispose();
  });

  testWidgets('shows total visited tile count from all visited regions', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 50)),
    );
    await provider.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: AnalyticsScreen(
              visitService: _FakeVisitService(totalVisitCount: 9),
              visitedRegionService: _FakeVisitedRegionService(<String>{
                'region-1',
                'region-2',
                'region-3',
                'region-4',
                'region-5',
                'region-6',
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tiles Visited'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('48'), findsNothing);

    provider.dispose();
  });

  testWidgets('shows total completed visits separately from visited tiles', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 50)),
    );
    await provider.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: AnalyticsScreen(
              visitService: _FakeVisitService(totalVisitCount: 14),
              visitedRegionService: _FakeVisitedRegionService(<String>{
                'tile-a',
                'tile-b',
                'tile-c',
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tiles Visited'), findsOneWidget);
    expect(find.text('Total Visits'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('156'), findsNothing);

    provider.dispose();
  });

  testWidgets('shows most visited location bubble for repeated visits', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 75)),
    );
    await provider.refreshCurrentUser();

    final visits = <Visit>[
      Visit(
        placeId: 1,
        googlePlaceId: 'g-1',
        placeName: 'Lakeside Cafe',
        regionId: 'region-a',
        category: 'food_drink',
        visitedAt: DateTime(2026, 5, 10, 10),
      ),
      Visit(
        placeId: 2,
        googlePlaceId: 'g-2',
        placeName: 'City Park',
        regionId: 'region-b',
        category: 'nature',
        visitedAt: DateTime(2026, 5, 12, 12),
      ),
      Visit(
        placeId: 1,
        googlePlaceId: 'g-1',
        placeName: 'Lakeside Cafe',
        regionId: 'region-a',
        category: 'food_drink',
        visitedAt: DateTime(2026, 5, 15, 15),
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: AnalyticsScreen(
              visitService: _FakeVisitService(
                totalVisitCount: 3,
                allVisits: visits,
              ),
              visitedRegionService: _FakeVisitedRegionService(<String>{
                'region-a',
                'region-b',
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Most Visited Location'), findsOneWidget);
    expect(find.text('Your top location'), findsOneWidget);
    expect(find.text('Lakeside Cafe'), findsOneWidget);
    expect(find.text('City Park'), findsNothing);

    provider.dispose();
  });

  testWidgets('shows empty most visited location state when no visits', (
    tester,
  ) async {
    final provider = AuthProvider(
      authRepository: _FakeAuthRepository(_buildProfile(xp: 75)),
    );
    await provider.refreshCurrentUser();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: AnalyticsScreen(
              visitService: _FakeVisitService(
                totalVisitCount: 0,
                allVisits: const <Visit>[],
              ),
              visitedRegionService: _FakeVisitedRegionService(<String>{}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No locations yet'), findsOneWidget);
    expect(
      find.text('Visit places on the map to see your most visited location here.'),
      findsOneWidget,
    );
    expect(find.text('Most Visited Location'), findsOneWidget);

    provider.dispose();
  });
}

ProfileModel _buildProfile({required int xp}) {
  return ProfileModel(
    uid: 'user-1',
    username: 'traveller',
    displayName: 'Traveller',
    email: 'traveller@example.com',
    createdAt: DateTime(2026, 5, 1, 10),
    updatedAt: DateTime(2026, 5, 1, 11),
    xp: xp,
    level: ProfileModel.levelFromXp(xp),
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._profile);

  final ProfileModel _profile;
  final _FakeUser _user = _FakeUser(
    uid: 'user-1',
    email: 'traveller@example.com',
  );

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVisitService implements VisitService {
  _FakeVisitService({
    required this.totalVisitCount,
    this.allVisits = const <Visit>[],
  });

  final int totalVisitCount;
  final List<Visit> allVisits;

  @override
  Future<int> getVisitCount(String userId) async {
    return totalVisitCount;
  }

  @override
  Future<List<Visit>> getAllVisits(String userId) async {
    return allVisits;
  }

  @override
  Stream<List<Visit>> watchRecentVisits(String userId, {int limit = 5}) {
    return Stream<List<Visit>>.value(const <Visit>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVisitedRegionService implements VisitedRegionService {
  _FakeVisitedRegionService(this._visitedRegionIds);

  final Set<String> _visitedRegionIds;

  @override
  Future<Set<String>> loadVisitedRegionIds() async {
    return _visitedRegionIds;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements firebase_auth.User {
  _FakeUser({required this.uid, required this.email});

  @override
  final String uid;

  @override
  final String? email;

  @override
  bool get emailVerified => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
