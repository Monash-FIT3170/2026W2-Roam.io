import 'package:flutter/material.dart';

import '../../../home/presentation/screens/home_screen.dart';
import '../../../../shared/widgets/app_bottom_nav_bar.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int selectedIndex = 2;

  final pages = const [
    Center(child: Text('Journeys')),
    Center(child: Text('Quests')),
    HomeScreen(),
    Center(child: Text('Stats')),
    Center(child: Text('You')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    );
  }
}