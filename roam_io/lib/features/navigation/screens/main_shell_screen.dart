/*
 * Author: Sanjevan Rajasegar
 * Last Modified: 24/04/2026
 * Description:
 *   Provides the authenticated app shell with persistent bottom navigation
 *   across the main feature tabs.
 */

import 'package:flutter/material.dart';

import '../../map/data/map_page.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../journeys/screens/journeys_screen.dart';
import '../../quests/screens/quests_screen.dart';
import '../../analytics/screens/analytics_screen.dart';
import '../../profile/screens/profile_screen.dart';

/// Stateful shell that keeps each main tab alive in an indexed stack.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int selectedIndex = 2;

  final pages = const [
    JourneysScreen(),
    QuestsScreen(),
    MapPage(),
    AnalyticsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          if (index == selectedIndex) return;
          setState(() => selectedIndex = index);
        },
      ),
    );
  }
}
