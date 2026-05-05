/*
 * Author: [Insert Name Here]
 * Last Modified: 6/05/2026
 * Description:
 *   Provides the quests screen UI for discovering challenge and exploration
 *   content.
 */

import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_header.dart';

/// Displays the quests tab content inside the main shell.
class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Quests',
              subtitle: 'Discover new places and hidden challenges.',
            ),

            SizedBox(height: 12),

            Center(child: Text('Quest content goes here')),
          ],
        ),
      ),
    );
  }
}
