/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Session coordinator that turns persisted follow inbox documents into
 *   ART2-96 in-app banners. Handles cold-start unread summary (one banner),
 *   live single-follow banners, and per-UID session dedupe so rebuilds and
 *   account switches do not replay or leak banners. Does not mark
 *   notifications read — that happens on Notifications screen.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../notifications/notification.dart';
import '../data/friendship_service.dart';
import '../data/social_notification_service.dart';
import '../domain/social_notification.dart';

/// Bridges persisted social notifications to [NotificationService] banners.
class SocialNotificationCoordinator extends ChangeNotifier {
  SocialNotificationCoordinator({
    SocialNotificationService? notificationService,
    FriendshipService? friendshipService,
    NotificationService? bannerService,
  }) : _notificationService =
           notificationService ?? SocialNotificationService(),
       _friendshipService = friendshipService ?? FriendshipService(),
       _bannerService = bannerService ?? NotificationService.instance;

  final SocialNotificationService _notificationService;
  final FriendshipService _friendshipService;
  final NotificationService _bannerService;

  StreamSubscription<SocialNotificationRecentSnapshot>? _recentSub;
  StreamSubscription<int>? _unreadSub;

  String? _boundUid;
  int _bindGeneration = 0;
  final Set<String> _surfacedBannerIds = <String>{};
  var _coldStartHandled = false;
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;
  String? get boundUid => _boundUid;

  /// Binds watches for [uid]. Clears session banner state on user change.
  void bindUid(String? uid) {
    if (_boundUid == uid && _recentSub != null && _unreadSub != null) {
      return;
    }

    _recentSub?.cancel();
    _unreadSub?.cancel();
    _recentSub = null;
    _unreadSub = null;
    _boundUid = uid;
    _bindGeneration += 1;
    final generation = _bindGeneration;
    _surfacedBannerIds.clear();
    _coldStartHandled = false;
    _unreadCount = 0;
    notifyListeners();

    if (uid == null) return;

    _unreadSub = _notificationService
        .watchUnreadCount(uid)
        .listen(
          (count) {
            if (_boundUid != uid || generation != _bindGeneration) return;
            if (_unreadCount == count) return;
            _unreadCount = count;
            notifyListeners();
          },
          onError: (Object error) {
            debugPrint(
              '[SocialNotifCoordinator] unreadCount uid=$uid error=$error',
            );
          },
        );

    _recentSub = _notificationService
        .watchRecentSnapshots(uid)
        .listen(
          (snapshot) async {
            if (_boundUid != uid || generation != _bindGeneration) return;
            try {
              await _onNotifications(
                items: snapshot.items,
                isFromCache: snapshot.isFromCache,
                expectedUid: uid,
                generation: generation,
              );
            } catch (error, stackTrace) {
              debugPrint(
                '[SocialNotifCoordinator] onNotifications uid=$uid '
                'error=$error\n$stackTrace',
              );
            }
          },
          onError: (Object error) {
            debugPrint(
              '[SocialNotifCoordinator] watchRecent uid=$uid error=$error',
            );
          },
        );
  }

  Future<void> _onNotifications({
    required List<SocialNotification> items,
    required bool isFromCache,
    required String expectedUid,
    required int generation,
  }) async {
    if (!_isCurrentBind(expectedUid, generation)) return;

    final followItems = items.where((item) => item.isFollow).toList();
    final unreadFollows = followItems
        .where((item) => !item.isRead)
        .toList(growable: false);

    if (!_coldStartHandled) {
      // Skip provisional empty cache emits so cold-start summary still works
      // when server data arrives after login / account switch.
      if (isFromCache && unreadFollows.isEmpty) {
        return;
      }

      _coldStartHandled = true;
      if (unreadFollows.isEmpty) {
        _surfacedBannerIds.addAll(followItems.map((item) => item.id));
        return;
      }

      _surfacedBannerIds.addAll(unreadFollows.map((item) => item.id));
      _surfacedBannerIds.addAll(
        followItems.where((item) => item.isRead).map((item) => item.id),
      );

      if (unreadFollows.length == 1) {
        final only = unreadFollows.first;
        final actor = await _friendshipService.getPublicProfile(only.actorId);
        if (!_isCurrentBind(expectedUid, generation)) return;
        final name = actor?.displayName ?? actor?.username ?? 'Someone';
        await _bannerService.show(
          NotificationTemplates.followedYou(
            name,
            notificationId: only.id,
            actorId: only.actorId,
          ),
        );
      } else {
        if (!_isCurrentBind(expectedUid, generation)) return;
        await _bannerService.show(
          NotificationTemplates.followSummary(unreadFollows.length),
        );
      }
      return;
    }

    for (final item in followItems) {
      if (!_isCurrentBind(expectedUid, generation)) return;
      if (!_surfacedBannerIds.add(item.id)) continue;
      if (item.isRead) continue;
      final actor = await _friendshipService.getPublicProfile(item.actorId);
      if (!_isCurrentBind(expectedUid, generation)) return;
      final name = actor?.displayName ?? actor?.username ?? 'Someone';
      await _bannerService.show(
        NotificationTemplates.followedYou(
          name,
          notificationId: item.id,
          actorId: item.actorId,
        ),
      );
    }
  }

  bool _isCurrentBind(String expectedUid, int generation) {
    return _boundUid == expectedUid && generation == _bindGeneration;
  }

  @override
  void dispose() {
    _recentSub?.cancel();
    _unreadSub?.cancel();
    _recentSub = null;
    _unreadSub = null;
    _boundUid = null;
    _bindGeneration += 1;
    _surfacedBannerIds.clear();
    super.dispose();
  }
}
