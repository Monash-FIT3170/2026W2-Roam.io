/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Displays a read-only public profile for another registered user loaded
 *   from the safe public_profiles projection.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../../profile/widgets/profile_identity_header.dart';
import '../data/friendship_service.dart';
import '../domain/public_profile.dart';

/// Read-only social profile for a selected user.
class OtherUserProfileScreen extends StatelessWidget {
  const OtherUserProfileScreen({
    super.key,
    required this.selectedUserId,
    FriendshipService? friendshipService,
  }) : _friendshipService = friendshipService;

  final String selectedUserId;
  final FriendshipService? _friendshipService;

  @override
  Widget build(BuildContext context) {
    final friendshipService = _friendshipService ?? FriendshipService();

    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: FutureBuilder<PublicProfile?>(
          future: friendshipService.getPublicProfile(selectedUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final profile = snapshot.data;
            if (profile == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'This profile is unavailable.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppSurfaces.textMuted(context),
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileIdentityHeader(
                    displayName: profile.displayName,
                    username: profile.username,
                    photoUrl: profile.photoUrl,
                    level: profile.level,
                    xp: profile.xp,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Activity and stats are not public yet.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppSurfaces.textMuted(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
