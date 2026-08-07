/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Provides the Social destination foundation for future friend and community
 *   functionality without implementing feed features.
 */

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_page_header.dart';
import '../../../theme/app_surfaces.dart';

/// Top-level Social tab for friend and community functionality.
class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppSurfaces.pageBackground(context),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Social',
                subtitle: 'Friends and community tools',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppSurfaces.card(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppSurfaces.border(context)),
                    boxShadow: [
                      BoxShadow(
                        color: AppSurfaces.shadow(context),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.groups_2_outlined,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Social hub',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppSurfaces.textPrimary(context),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Friend requests, friends, and community tools will live here as they are introduced.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppSurfaces.textMuted(context),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
