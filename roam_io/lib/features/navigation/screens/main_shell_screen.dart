/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Provides the authenticated app shell with persistent bottom navigation
 *   across the main feature tabs and production notification action feedback.
 *   Shares one CommentService across Home and You for live comment counts.
 *   Wires SocialNotificationCoordinator for follow inbox banners and You
 *   unread badge.
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

  /// Injected for tests; production uses the default coordinator services.
  final SocialNotificationCoordinator? socialNotificationCoordinator;

  const MainShellScreen({
    super.key,
    this.requestNotificationPermission = true,
    this.commentService,
    this.friendshipService,
    this.socialNotificationCoordinator,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int selectedIndex = 2;

  StreamSubscription<NotificationActionEvent>? _actionSubscription;
  StreamSubscription? _incomingRequestSubscription;
  StreamSubscription? _acceptedRequestSubscription;
  late final CommentService _commentService;
  late final FriendshipService _friendshipService;
  late final SocialNotificationCoordinator _socialNotificationCoordinator;
  late final List<Widget> pages;
  final Set<String> _seenIncomingRequestIds = <String>{};
  final Set<String> _seenAcceptedRequestIds = <String>{};
  var _hasSeededIncomingRequests = false;
  var _hasSeededAcceptedRequests = false;
  var _ownsCoordinator = false;

  @override
  void initState() {
    super.initState();

    _commentService = widget.commentService ?? CommentService();
    _friendshipService = widget.friendshipService ?? FriendshipService();
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
      const SocialScreen(),
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
      _startFriendRequestListeners();
      _bindSocialNotifications();
    });
  }

  @override
  void dispose() {
    _actionSubscription?.cancel();
    _incomingRequestSubscription?.cancel();
    _acceptedRequestSubscription?.cancel();
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

    AppToast.success(context, _messageForNotificationAction(event));
  }

  String _messageForNotificationAction(NotificationActionEvent event) {
    return switch (event.action.type) {
      NotificationActionType.accept => 'Friend request accepted.',
      NotificationActionType.decline => 'Friend request declined.',
      _ => '${event.action.label} selected for ${event.notification.title}.',
    };
  }

  void _startFriendRequestListeners() {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    if (currentUserId == null) return;

    _incomingRequestSubscription?.cancel();
    _acceptedRequestSubscription?.cancel();
    _seenIncomingRequestIds.clear();
    _seenAcceptedRequestIds.clear();
    _hasSeededIncomingRequests = false;
    _hasSeededAcceptedRequests = false;

    _incomingRequestSubscription = _friendshipService
        .watchIncomingRequests(currentUserId)
        .listen((requests) async {
          if (!_hasSeededIncomingRequests) {
            _seenIncomingRequestIds.addAll(
              requests.map((request) => request.id),
            );
            _hasSeededIncomingRequests = true;
            return;
          }

          for (final request in requests) {
            if (!_seenIncomingRequestIds.add(request.id)) continue;
            final sender = await _friendshipService.getPublicProfile(
              request.senderId,
            );
            await NotificationService.instance.show(
              NotificationTemplates.friendRequest(
                sender?.displayName ?? sender?.username ?? 'Someone',
                friendRequestId: request.id,
                senderId: request.senderId,
              ),
            );
          }
        });

    _acceptedRequestSubscription = _friendshipService
        .watchAcceptedRequestsForSender(currentUserId)
        .listen((requests) async {
          if (!_hasSeededAcceptedRequests) {
            _seenAcceptedRequestIds.addAll(
              requests.map((request) => request.id),
            );
            _hasSeededAcceptedRequests = true;
            return;
          }

          for (final request in requests) {
            if (!_seenAcceptedRequestIds.add(request.id)) continue;
            final recipient = await _friendshipService.getPublicProfile(
              request.recipientId,
            );
            await NotificationService.instance.show(
              NotificationTemplates.friendAccepted(
                recipient?.displayName ?? recipient?.username ?? 'Someone',
              ),
            );
          }
        });
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
              youHasUnread: coordinator.hasUnread,
            );
          },
        ),
      ),
    );
  }
}
