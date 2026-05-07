/*
 * Author: Alvin Liong
 * Last Modified: 24/04/2026
 * Description:
 *   Provides the home map placeholder screen shown from the main navigation
 *   shell.
 */

import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_header.dart';

/// Displays the home map tab content inside the main shell.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Map',
              subtitle: 'Explore nearby places and routes.',
            ),
            SizedBox(height: 12),
            Center(child: Text('Map content goes here')),
          ],
        ),
      ),
    );
  }
}
