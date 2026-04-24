import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_header.dart';

class JourneysScreen extends StatelessWidget {
  const JourneysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Journeys',
              subtitle: 'Your past urban explorations and discoveries',
            ),

            SizedBox(height: 12),

            Center(
              child: Text('Journey content goes here'),
            ),
          ],
        ),
      ),
    );
  }
}