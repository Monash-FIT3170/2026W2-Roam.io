/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Product-facing full-page Glaze list backed by the stable activity kudos
 *   subcollection.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../../social/screens/other_user_profile_screen.dart';
import '../../social/widgets/social_avatar.dart';
import '../data/kudos_service.dart';

class ActivityGlazersSheet extends StatelessWidget {
  const ActivityGlazersSheet({
    super.key,
    required this.activityId,
    required this.kudosService,
  });

  final String activityId;
  final KudosService kudosService;

  static Future<void> show({
    required BuildContext context,
    required String activityId,
    required KudosService kudosService,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ActivityGlazersSheet(
          activityId: activityId,
          kudosService: kudosService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(
        backgroundColor: AppSurfaces.pageBackground(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(),
        title: Text(
          'Glazes',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppSurfaces.textPrimary(context),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<ActivityGlazer>>(
          stream: kudosService.watchGlazers(activityId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load Glazes.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppSurfaces.textMuted(context),
                    ),
                  ),
                ),
              );
            }
            final glazers = snapshot.data ?? const <ActivityGlazer>[];
            if (snapshot.connectionState == ConnectionState.waiting &&
                glazers.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (glazers.isEmpty) {
              return Center(
                child: Text(
                  'No Glazes yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppSurfaces.textMuted(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: glazers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final glazer = glazers[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  leading: SocialAvatar(
                    displayName: glazer.displayName,
                    photoUrl: glazer.photoUrl,
                    radius: 22,
                  ),
                  title: Text(
                    glazer.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: glazer.username == null
                      ? null
                      : Text('@${glazer.username}'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OtherUserProfileScreen(
                          selectedUserId: glazer.userId,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
