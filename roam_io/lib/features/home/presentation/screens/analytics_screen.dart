import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_header.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Added theme reference

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(
              title: 'Your Analytics',
              subtitle: 'Stats & progress',
            ),
            const SizedBox(height: 24),
            
            // TODO: Add Summary Stats
            
            // TODO: Add Heatmap
            
            // TODO: Add Milestones
          ],
        ),
      ),
    );
  }
}