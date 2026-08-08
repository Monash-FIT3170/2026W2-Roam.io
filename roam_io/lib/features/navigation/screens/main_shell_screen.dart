/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Provides the authenticated app shell with persistent bottom navigation
 *   across the main feature tabs and production notification action feedback.
 *   Shares one CommentService across Home and You for live comment counts.
 *   Wires SocialNotificationCoordinator for social inbox banners, You unread
 *   badge, and follow-request banner actions. Rebinds coordinator when auth UID
 *   changes.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/notifications/notification.dart';

import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../activity_feed/data/comment_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/screens/home_screen.dart';
import '../../map/data/map_page.dart';
import '../../settings/screens/settings_screen.dart';
import '../../social/data/follow_request_service.dart';
import '../../social/data/friendship_service.dart';
import '../../social/data/social_notification_coordinator.dart';
import '../../social/data/social_notification_service.dart';
import '../../social/screens/social_screen.dart';
import '../../you/screens/you_screen.dart';

/// Stateful shell that keeps each main tab alive in an indexed stack.
class MainShellScreen extends StatefulWidget {
  final bool requestNotificationPermission;

  /// Injected for tests; production uses the default [CommentService].
  final CommentService? commentService;

  /// Injected for tests; production uses the default [FriendshipService].
  final FriendshipService? friendshipService;

  /// Injected for tests; production uses the default [FollowRequestService].
  final FollowRequestService? followRequestService;

  /// Injected for tests; production uses the default coordinator services.
  final SocialNotificationCoordinator? socialNotificationCoordinator;

  const MainShellScreen({
    super.key,
    this.requestNotificationPermission = true,
    this.commentService,
    this.friendshipService,
    this.followRequestService,
    this.socialNotificationCoordinator,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int selectedIndex = 2;

  StreamSubscription<NotificationActionEvent>? _actionSubscription;
  late final CommentService _commentService;
  late final FriendshipService _friendshipService;
  late final FollowRequestService _followRequestService;
  late final SocialNotificationCoordinator _socialNotificationCoordinator;
  late final List<Widget> pages;
  var _ownsCoordinator = false;

  @override
  void initState() {
    super.initState();

    _commentService = widget.commentService ?? CommentService();
    _friendshipService = widget.friendshipService ?? FriendshipService();
    _followRequestService =
        widget.followRequestService ?? FollowRequestService();
    if (widget.socialNotificationCoordinator != null) {
      _socialNotificationCoordinator = widget.socialNotificationCoordinator!;
      _ownsCoordinator = false;
    } else {
      _socialNotificationCoordinator = SocialNotificationCoordinator(
        friendshipService: _friendshipService,
        notificationService: SocialNotificationService(),
      );
      _ownsCoordinator = true;
    }
    pages = [
      HomeScreen(commentService: _commentService),
      SocialScreen(friendshipService: _friendshipService),
      const MapPage(),
      YouScreen(commentService: _commentService),
      const SettingsScreen(),
    ];

    //Initialise the Android notification service
    if (widget.requestNotificationPermission &&
        defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final granted = await AndroidNotificationService.instance
            .requestPermission();

        debugPrint('Notification permission granted: $granted');
      });
    }

    // Handles domain-specific notification actions before showing feedback.
    _actionSubscription = NotificationService.instance.actionEvents.listen(
      _handleNotificationAction,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bindSocialNotifications();
    });
  }

  @override
  void dispose() {
    _actionSubscription?.cancel();
    if (_ownsCoordinator) {
      _socialNotificationCoordinator.dispose();
    }
    super.dispose();
  }

  void _bindSocialNotifications() {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    _socialNotificationCoordinator.bindUid(currentUserId);
  }

  Future<void> _handleNotificationAction(NotificationActionEvent event) async {
    if (!mounted) return;

    if (event.notification.type == NotificationType.friendRequest) {
      final requestId = event.notification.data['friendRequestId'];
      final currentUserId = context.read<AuthProvider>().currentUser?.uid;
      if (requestId == null || currentUserId == null) return;

      try {
        if (event.action.type == NotificationActionType.accept) {
          await _friendshipService.acceptRequest(
            requestId: requestId,
            currentUserId: currentUserId,
          );
        } else if (event.action.type == NotificationActionType.decline) {
          await _friendshipService.declineRequest(
            requestId: requestId,
            currentUserId: currentUserId,
          );
        } else {
          AppToast.success(context, _messageForNotificationAction(event));
          return;
        }
        if (!mounted) return;
        AppToast.success(context, _messageForNotificationAction(event));
      } catch (_) {
        if (mounted) {
          AppToast.error(context, 'Could not update friend request.');
        }
      }
      return;
    }

    if (event.notification.type == NotificationType.followRequest) {
      final requestId = event.notification.data['requestId'];
      final currentUserId = context.read<AuthProvider>().currentUser?.uid;
      if (requestId == null || currentUserId == null) return;

      try {
        if (event.action.type == NotificationActionType.accept) {
          await _followRequestService.acceptFollowRequest(
            requestId: requestId,
            currentUserId: currentUserId,
          );
        } else if (event.action.type == NotificationActionType.decline) {
          await _followRequestService.declineFollowRequest(
            requestId: requestId,
            currentUserId: currentUserId,
          );
        } else {
          AppToast.success(context, _messageForNotificationAction(event));
          return;
        }
        if (!mounted) return;
        AppToast.success(context, _messageForNotificationAction(event));
      } catch (_) {
        if (mounted) {
          AppToast.error(context, 'Could not update follow request.');
        }
      }
      return;
    }

    AppToast.success(context, _messageForNotificationAction(event));
  }

  String _messageForNotificationAction(NotificationActionEvent event) {
    if (event.notification.type == NotificationType.friendRequest) {
      return switch (event.action.type) {
        NotificationActionType.accept => 'Friend request accepted.',
        NotificationActionType.decline => 'Friend request declined.',
        _ => '${event.action.label} selected for ${event.notification.title}.',
      };
    }

    return switch (event.action.type) {
      NotificationActionType.accept => 'Follow request accepted.',
      NotificationActionType.decline => 'Follow request declined.',
      _ => '${event.action.label} selected for ${event.notification.title}.',
    };
  }

  void _selectPage(int index) {
    if (index == selectedIndex) return;

    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Re-bind when auth uid changes (e.g. after refresh).
    final uid = context.watch<AuthProvider>().currentUser?.uid;
    if (_socialNotificationCoordinator.boundUid != uid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _socialNotificationCoordinator.bindUid(uid);
      });
    }

    return ChangeNotifierProvider<SocialNotificationCoordinator>.value(
      value: _socialNotificationCoordinator,
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: selectedIndex, children: pages),
        bottomNavigationBar: Consumer<SocialNotificationCoordinator>(
          builder: (context, coordinator, _) {
            return AppBottomNavBar(
              currentIndex: selectedIndex,
              onTap: _selectPage,
              youUnreadCount: coordinator.unreadCount,
            );
          },
        ),
      ),
    );
  }
}
