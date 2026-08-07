/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Provides the Social destination foundation for future friend and community
 *   functionality. The Find People search icon uses standard text-primary
 *   foreground colour (not the sage primary accent).
 */

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_page_header.dart';
import '../../../theme/app_surfaces.dart';
import '../data/friendship_service.dart';
import 'find_people_screen.dart';

/// Top-level Social tab for friend and community functionality.
class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key, FriendshipService? friendshipService})
    : _friendshipService = friendshipService;

  final FriendshipService? _friendshipService;

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
              AppPageHeader(
                title: 'Social',
                subtitle: 'Friends and community tools',
                trailing: IconButton(
                  tooltip: 'Find people',
                  // Use standard header foreground, not the sage primary accent.
                  color: AppSurfaces.textPrimary(context),
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FindPeopleScreen(
                          friendshipService: _friendshipService,
                        ),
                      ),
                    );
                  },
                ),
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
