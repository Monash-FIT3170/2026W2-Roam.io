/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Firestore-backed social privacy and access decisions. Private profile
 *   activity is visible to the owner and approved followers only; aggregate
 *   public identity remains available through public_profiles.
 */

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/social_privacy_settings.dart';

/// Resolved access permissions for a viewer/profile pair.
class SocialAccessPermissions {
  const SocialAccessPermissions({
    required this.canViewProfileActivity,
    required this.isPrivateAccount,
  });

  final bool canViewProfileActivity;
  final bool isPrivateAccount;
}

/// Owns privacy settings and reusable profile-activity access checks.
class SocialPrivacyService {
  SocialPrivacyService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profile(String uid) {
    return _firestore.collection('profiles').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _publicProfile(String uid) {
    return _firestore.collection('public_profiles').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _follow({
    required String followerId,
    required String followeeId,
  }) {
    return _firestore.collection('follows').doc('${followerId}_$followeeId');
  }

  /// Watches authoritative privacy settings. Missing privacy means public.
  Stream<SocialPrivacySettings> watchPrivacy(String uid) {
    return _profile(uid).snapshots().map((doc) {
      final data = doc.data();
      return SocialPrivacySettings.fromMap(data?['privacy']);
    });
  }

  /// Updates private account state on profiles/{uid}. The public projection is
  /// best-effort so the authoritative setting is never rolled back by mirror
  /// failures.
  Future<void> updatePrivateAccount({
    required String uid,
    required bool enabled,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _profile(uid).update(<String, dynamic>{
      'privacy.isPrivateAccount': enabled,
      'updatedAt': now,
    });

    try {
      await _publicProfile(uid).set(<String, dynamic>{
        'isPrivateAccount': enabled,
        'updatedAt': now,
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      debugPrint(
        '[SocialPrivacyService.updatePrivateAccount] public projection failed '
        '(privacy kept) uid=$uid enabled=$enabled error=$error\n$stackTrace',
      );
    }

    if (!enabled) {
      await _tryResolvePendingRequestsForPublicTarget(uid);
    }
  }

  /// One-shot access check for service callers.
  Future<bool> canViewProfileActivity({
    required String? viewerId,
    required String profileId,
  }) async {
    if (viewerId == profileId) return true;
    if (viewerId == null || viewerId.isEmpty) return false;

    final publicDoc = await _publicProfile(profileId).get();
    final isPrivate = publicDoc.data()?['isPrivateAccount'] as bool? ?? false;
    if (!isPrivate) return true;

    final followDoc = await _follow(
      followerId: viewerId,
      followeeId: profileId,
    ).get();
    return followDoc.exists;
  }

  /// Reactive access decision for profile screens.
  Stream<SocialAccessPermissions> watchProfileActivityAccess({
    required String? viewerId,
    required String profileId,
  }) {
    if (viewerId == profileId) {
      return _publicProfile(profileId).snapshots().map((doc) {
        return SocialAccessPermissions(
          canViewProfileActivity: true,
          isPrivateAccount: doc.data()?['isPrivateAccount'] as bool? ?? false,
        );
      });
    }
    if (viewerId == null || viewerId.isEmpty) {
      return _publicProfile(profileId).snapshots().map((doc) {
        final isPrivate = doc.data()?['isPrivateAccount'] as bool? ?? false;
        return SocialAccessPermissions(
          canViewProfileActivity: !isPrivate,
          isPrivateAccount: isPrivate,
        );
      });
    }

    late StreamController<SocialAccessPermissions> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? privacySub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? followSub;
    var isPrivate = false;
    var follows = false;
    var hasPrivacy = false;
    var hasFollow = false;

    void emit() {
      if (controller.isClosed || !hasPrivacy || !hasFollow) return;
      controller.add(
        SocialAccessPermissions(
          isPrivateAccount: isPrivate,
          canViewProfileActivity: !isPrivate || follows,
        ),
      );
    }

    controller = StreamController<SocialAccessPermissions>.broadcast(
      onListen: () {
        privacySub = _publicProfile(profileId).snapshots().listen((doc) {
          isPrivate = doc.data()?['isPrivateAccount'] as bool? ?? false;
          hasPrivacy = true;
          emit();
        }, onError: controller.addError);
        followSub = _follow(followerId: viewerId, followeeId: profileId)
            .snapshots()
            .listen((doc) {
              follows = doc.exists;
              hasFollow = true;
              emit();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await privacySub?.cancel();
        await followSub?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> _tryResolvePendingRequestsForPublicTarget(
    String targetId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('follow_requests')
          .where('targetId', isEqualTo: targetId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (error, stackTrace) {
      debugPrint(
        '[SocialPrivacyService.updatePrivateAccount] stale request cleanup '
        'failed targetId=$targetId error=$error\n$stackTrace',
      );
    }
  }
}
