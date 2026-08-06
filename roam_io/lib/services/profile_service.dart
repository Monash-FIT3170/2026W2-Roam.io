/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Provides Firestore profile document operations for account details,
 *   preferences, profile photo metadata, and timestamped XP gain events.
 *   Canonical XP/level on profiles/{uid} is authoritative; xp_events history
 *   is secondary analytics and must never block progression.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../features/profile/domain/profile_model.dart';
import '../features/profile/domain/xp_award_result.dart';
import '../features/profile/domain/xp_event.dart';

/// Owns reads and writes for Firestore documents in the `profiles` collection.
class ProfileService {
  static const String _profilesCollectionName = 'profiles';
  static const String _xpEventsCollectionName = 'xp_events';

  ProfileService({
    FirebaseFirestore? firestore,
    Future<void> Function(String uid, XpEvent event)? recordXpEvent,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _recordXpEventOverride = recordXpEvent;

  final FirebaseFirestore _firestore;

  /// Optional seam for tests to force XP history write failures without
  /// affecting the canonical progression transaction.
  final Future<void> Function(String uid, XpEvent event)?
  _recordXpEventOverride;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection(_profilesCollectionName);

  CollectionReference<Map<String, dynamic>> _xpEvents(String uid) {
    return _profiles.doc(uid).collection(_xpEventsCollectionName);
  }

  /// Creates/replaces profile document at `profiles/{uid}`.
  Future<void> createProfile(ProfileModel profile) {
    return _profiles.doc(profile.uid).set(profile.toMap());
  }

  /// Updates editable profile fields and refreshes `updatedAt`.
  Future<void> updateProfile({
    required String uid,
    required String username,
    required String displayName,
    String? photoUrl,
  }) {
    final data = <String, dynamic>{
      'username': username,
      'displayName': displayName,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }
    return _profiles.doc(uid).update(data);
  }

  /// Updates the user's saved dark mode preference.
  Future<void> updateDarkModePreference({
    required String uid,
    required bool enabled,
  }) {
    return _profiles.doc(uid).update(<String, dynamic>{
      'darkModeEnabled': enabled,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Stores the user's profile photo URL and content hash.
  Future<void> updateProfilePhoto({
    required String uid,
    required String photoUrl,
    required String photoHash,
  }) {
    return _profiles.doc(uid).update(<String, dynamic>{
      'photoUrl': photoUrl,
      'photoHash': photoHash,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Stores a content hash for an existing profile photo.
  Future<void> updateProfilePhotoHash({
    required String uid,
    required String photoHash,
  }) {
    return _profiles.doc(uid).update(<String, dynamic>{
      'photoHash': photoHash,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Reads a profile by uid. Returns null when not found.
  Future<ProfileModel?> getProfile(String uid) async {
    final doc = await _profiles.doc(uid).get();
    final data = doc.data();
    if (data == null) return null;

    final xpValue = (data['xp'] as num?)?.toInt() ?? 0;
    final expectedLevel = ProfileModel.levelFromXp(xpValue);
    final hasLevel = data.containsKey('level') && data['level'] != null;
    final currentLevel = (data['level'] as num?)?.toInt();

    final updateData = <String, dynamic>{};
    if (!data.containsKey('xp') || data['xp'] == null) {
      updateData['xp'] = 0;
      data['xp'] = 0;
    }
    if (!hasLevel || currentLevel != expectedLevel) {
      updateData['level'] = expectedLevel;
      data['level'] = expectedLevel;
    }
    if (updateData.isNotEmpty) {
      await _profiles.doc(uid).update(updateData);
    }

    return ProfileModel.fromMap(data);
  }

  /// Updates the display name shown in profile surfaces.
  Future<void> updateDisplayName(String uid, String displayName) async {
    await _profiles.doc(uid).update(<String, dynamic>{
      'displayName': displayName,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Updates the username stored on the profile document.
  Future<void> updateUsername(String uid, String username) async {
    await _profiles.doc(uid).update(<String, dynamic>{
      'username': username,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Updates the user's XP and recalculates level if necessary.
  ///
  /// Does not create an XP history event. Prefer [addXp] for awards so a
  /// best-effort timestamped event can be recorded after progression.
  Future<void> updateXp(String uid, int newXp) async {
    final expectedLevel = ProfileModel.levelFromXp(newXp);
    await _profiles.doc(uid).update(<String, dynamic>{
      'xp': newXp,
      'level': expectedLevel,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Awards XP on the canonical profile document, then best-effort records
  /// a timestamped xp_events entry for analytics.
  ///
  /// Canonical XP/level is written in a Firestore transaction that does **not**
  /// include history. A failure to write `xp_events` never rolls back or
  /// fails the award — [XpAwardResult.historyRecorded] is false in that case.
  /// History begins when events are recorded; existing aggregate XP is never
  /// reverse-engineered into fabricated past events.
  Future<XpAwardResult> addXp(
    String uid,
    int xpToAdd, {
    XpEventSource source = XpEventSource.unknown,
    String? sourceId,
  }) async {
    if (xpToAdd <= 0) {
      return XpAwardResult.failed(amount: xpToAdd);
    }

    final profileRef = _profiles.doc(uid);
    final earnedAt = DateTime.now();

    var previousXp = 0;
    var newXp = 0;
    var previousLevel = 1;
    var newLevel = 1;
    var profileFound = false;

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(profileRef);
        final data = snapshot.data();
        if (data == null) {
          profileFound = false;
          return;
        }

        profileFound = true;
        previousXp = (data['xp'] as num?)?.toInt() ?? 0;
        previousLevel = ProfileModel.levelFromXp(previousXp);
        newXp = previousXp + xpToAdd;
        newLevel = ProfileModel.levelFromXp(newXp);

        transaction.update(profileRef, <String, dynamic>{
          'xp': newXp,
          'level': newLevel,
          'updatedAt': earnedAt.toIso8601String(),
        });
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[ProfileService.addXp] Canonical XP update failed '
        'uid=$uid amount=$xpToAdd source=${source.wireValue} '
        'sourceId=$sourceId error=$error\n$stackTrace',
      );
      return XpAwardResult.failed(amount: xpToAdd);
    }

    if (!profileFound) {
      debugPrint(
        '[ProfileService.addXp] Profile missing; XP not awarded '
        'uid=$uid amount=$xpToAdd source=${source.wireValue}',
      );
      return XpAwardResult.failed(amount: xpToAdd);
    }

    final historyRecorded = await _tryRecordXpEvent(
      uid: uid,
      event: XpEvent(
        id: _xpEvents(uid).doc().id,
        amount: xpToAdd,
        earnedAt: earnedAt,
        source: source,
        sourceId: sourceId,
      ),
    );

    return XpAwardResult.success(
      amount: xpToAdd,
      previousXp: previousXp,
      newXp: newXp,
      previousLevel: previousLevel,
      newLevel: newLevel,
      historyRecorded: historyRecorded,
    );
  }

  Future<bool> _tryRecordXpEvent({
    required String uid,
    required XpEvent event,
  }) async {
    try {
      final override = _recordXpEventOverride;
      if (override != null) {
        await override(uid, event);
      } else {
        await _xpEvents(uid).doc(event.id).set(event.toMap());
      }
      return true;
    } catch (error, stackTrace) {
      final code = error is FirebaseException ? error.code : 'unknown';
      debugPrint(
        '[ProfileService.addXp] XP history write failed (progression kept) '
        'uid=$uid amount=${event.amount} source=${event.source.wireValue} '
        'sourceId=${event.sourceId} code=$code error=$error\n$stackTrace',
      );
      return false;
    }
  }

  /// Streams XP gain events newest-first for reactive weekly XP Gained graphs.
  Stream<List<XpEvent>> watchXpEvents(String uid, {int limit = 200}) {
    return _xpEvents(uid)
        .orderBy('earnedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => XpEvent.fromMap(doc.id, doc.data()))
              .toList();
        });
  }
}
