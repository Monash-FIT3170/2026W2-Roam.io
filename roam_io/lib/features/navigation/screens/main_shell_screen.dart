/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 05/08/2026
 * Description:
 *   Provides the authenticated app shell with persistent bottom navigation
 *   across the main feature tabs and app-styled notification action feedback.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:roam_io/notifications/notification.dart';

import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../analytics/screens/analytics_screen.dart';
import '../../journeys/screens/journeys_screen.dart';
import '../../map/data/map_page.dart';
import '../../profile/screens/profile_screen.dart';
import '../../quests/screens/quests_screen.dart';

/// Stateful shell that keeps each main tab alive in an indexed stack.
class MainShellScreen extends StatefulWidget {
  final bool requestNotificationPermission;

  const MainShellScreen({super.key, this.requestNotificationPermission = true});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int selectedIndex = 2;

  StreamSubscription<NotificationActionEvent>? _actionSubscription;

  final List<Widget> pages = const [
    JourneysScreen(),
    QuestsScreen(),
    MapPage(),
    AnalyticsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

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

  void _showTestNotification() {
    NotificationService.instance.show(
      NotificationTemplates.friendRequest('Alex'),
    );
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

      body: IndexedStack(index: selectedIndex, children: pages),

      // Temporary button used to test the notification system.
      floatingActionButton: FloatingActionButton(
        onPressed: _showTestNotification,
        tooltip: 'Test notification',
        child: const Icon(Icons.notifications),
      ),

      bottomNavigationBar: AppBottomNavBar(
        currentIndex: selectedIndex,
        onTap: _selectPage,
      ),
    );
  }
}
