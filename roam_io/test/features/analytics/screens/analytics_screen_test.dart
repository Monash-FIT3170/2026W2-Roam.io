import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/analytics/screens/analytics_screen.dart';
import 'package:roam_io/features/auth/data/auth_repository.dart';
import 'package:roam_io/features/auth/providers/auth_provider.dart';
import 'package:roam_io/features/map/data/visit_service.dart';

class _UnauthenticatedAuthRepository implements AuthRepository {
  @override
  Stream<firebase_auth.User?> authStateChanges() async* {
    yield null;
  }

  @override
  firebase_auth.User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('renders analytics header and stat labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) =>
              AuthProvider(authRepository: _UnauthenticatedAuthRepository()),
          child: Scaffold(
            body: AnalyticsScreen(
              visitService: VisitService(firestore: FakeFirebaseFirestore()),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Your Analytics'), findsOneWidget);
    expect(find.text('Activity Map'), findsOneWidget);
    expect(find.text('XP Count'), findsOneWidget);
    expect(find.text('Tiles Visited'), findsOneWidget);
  });
}
