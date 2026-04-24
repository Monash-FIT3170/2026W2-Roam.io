import 'package:flutter/material.dart';

import '../../../home/presentation/screens/home_screen.dart';
import '../../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../home/presentation/screens/journeys_screen.dart';
import '../../../home/presentation/screens/quests_screen.dart';
import '../../../home/presentation/screens/analytics_screen.dart';
import '../../../home/presentation/screens/profile_screen.dart';

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
    HomeScreen(),
    AnalyticsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
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