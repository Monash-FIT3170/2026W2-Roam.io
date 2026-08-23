/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Product-facing Glaze list backed by the stable activity kudos
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
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ActivityGlazersSheet(
        activityId: activityId,
        kudosService: kudosService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Glazed by',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppSurfaces.textPrimary(context),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: StreamBuilder<List<ActivityGlazer>>(
                stream: kudosService.watchGlazers(activityId),
                builder: (context, snapshot) {
                  final glazers = snapshot.data ?? const <ActivityGlazer>[];
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      glazers.isEmpty) {
                    return const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (glazers.isEmpty) {
                    return SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          'No Glaze yet',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppSurfaces.textMuted(context),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: glazers.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppSurfaces.border(context)),
                    itemBuilder: (context, index) {
                      final glazer = glazers[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: SocialAvatar(
                          displayName: glazer.displayName,
                          photoUrl: glazer.photoUrl,
                          radius: 22,
                        ),
                        title: Text(
                          glazer.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: glazer.username == null
                            ? null
                            : Text('@${glazer.username}'),
                        onTap: () {
                          Navigator.of(context).pop();
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
          ],
        ),
      ),
    );
  }
}
