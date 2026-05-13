import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_page_header.dart';


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

            Center(
              child: Text('Quest content goes here'),
            ),
          ],
        ),
      ),
    );
  }
}