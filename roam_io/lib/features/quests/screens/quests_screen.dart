/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Provides reusable quest discovery content for Home and transitional
 *   standalone quest views.
 */

import 'package:flutter/material.dart';
import '../../../shared/widgets/app_page_header.dart';

/// Displays quest content inside Home or as a standalone transitional screen.
class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key, this.showHeader = true});

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              const AppPageHeader(
                title: 'Quests',
                subtitle: 'Discover new places and hidden challenges.',
              ),

            SizedBox(height: showHeader ? 12 : 24),

            const Center(child: Text('Quest content goes here')),
          ],
        ),
      ),
    );
  }
}
