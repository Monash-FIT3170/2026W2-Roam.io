import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_header.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Your Analytics',
              subtitle: 'Stats & progress',
            ),

            SizedBox(height: 16),

            Center(
              child: Text('Analytics content goes here'),
            ),
          ],
        ),
      ),
    );
  }
}