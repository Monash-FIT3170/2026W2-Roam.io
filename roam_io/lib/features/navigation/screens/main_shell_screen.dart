/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Provides the authenticated app shell with persistent bottom navigation
 *   across the main feature tabs and production notification action feedback.
 *   Shares one CommentService across Home and You for live comment counts.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:roam_io/notifications/notification.dart';

import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../activity_feed/data/comment_service.dart';
import '../../home/screens/home_screen.dart';
import '../../map/data/map_page.dart';
import '../../settings/screens/settings_screen.dart';
import '../../social/screens/social_screen.dart';
import '../../you/screens/you_screen.dart';

/// Stateful shell that keeps each main tab alive in an indexed stack.
class MainShellScreen extends StatefulWidget {
  final bool requestNotificationPermission;

  /// Injected for tests; production uses the default [CommentService].
  final CommentService? commentService;

  const MainShellScreen({
    super.key,
    this.requestNotificationPermission = true,
    this.commentService,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int selectedIndex = 2;

  StreamSubscription<NotificationActionEvent>? _actionSubscription;
  late final CommentService _commentService;
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();

    _commentService = widget.commentService ?? CommentService();
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

    // Displays app-styled feedback for notification actions.
    _actionSubscription = NotificationService.instance.actionEvents.listen((
      event,
    ) {
      if (!mounted) return;

      AppToast.success(context, _messageForNotificationAction(event));
    });
  }

  @override
  void dispose() {
    _actionSubscription?.cancel();
    super.dispose();
  }

  String _messageForNotificationAction(NotificationActionEvent event) {
    return switch (event.action.type) {
      NotificationActionType.accept => 'Friend request accepted.',
      NotificationActionType.decline => 'Friend request declined.',
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
    return Scaffold(
      extendBody: true,

      // IndexedStack keeps every page mounted with maintainAnimation: true, so
      // tickers on hidden tabs keep firing for as long as the app is open.
      // TickerMode mutes them, which matters most for the map's fog overlay —
      // it would otherwise animate clouds nobody can see.
      body: IndexedStack(
        index: selectedIndex,
        children: <Widget>[
          for (var index = 0; index < pages.length; index++)
            TickerMode(enabled: index == selectedIndex, child: pages[index]),
        ],
      ),

      bottomNavigationBar: AppBottomNavBar(
        currentIndex: selectedIndex,
        onTap: _selectPage,
      ),
    );
  }
}
