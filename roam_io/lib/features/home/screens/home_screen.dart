/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Provides the Home destination that consolidates existing journey and quest
 *   experiences ahead of the future social feed expansion.
 */

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_page_header.dart';
import '../../../theme/app_surfaces.dart';
import '../../journeys/screens/journeys_screen.dart';
import '../../quests/screens/quests_screen.dart';

/// Top-level Home tab for activity-oriented content.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Container(
        color: AppSurfaces.pageBackground(context),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Home',
                subtitle: 'Your journeys, quests, and activity foundations',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppSurfaces.softCard(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppSurfaces.border(context)),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: theme.colorScheme.onPrimary,
                    unselectedLabelColor: AppSurfaces.textMuted(context),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: const [
                      Tab(text: 'Journeys'),
                      Tab(text: 'Quests'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Expanded(
                child: TabBarView(
                  children: [
                    JourneysScreen(showHeader: false),
                    QuestsScreen(showHeader: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
