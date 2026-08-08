/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Provides the Social destination with Find People and compact private
 *   account Follow Request management. The Find People search icon uses
 *   standard text-primary foreground colour.
 */

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/follow_request_service.dart';
import '../data/follow_service.dart';
import '../data/friendship_service.dart';
import '../domain/follow_request.dart';
import '../domain/public_profile.dart';
import 'find_people_screen.dart';

/// Top-level Social tab for follow and community functionality.
class SocialScreen extends StatelessWidget {
  const SocialScreen({
    super.key,
    FriendshipService? friendshipService,
    FollowService? followService,
    FollowRequestService? followRequestService,
  }) : _friendshipService = friendshipService,
       _followService = followService,
       _followRequestService = followRequestService;

  final FriendshipService? _friendshipService;
  final FollowService? _followService;
  final FollowRequestService? _followRequestService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = _currentUserId(context);
    final friendshipService =
        _friendshipService ??
        (Firebase.apps.isNotEmpty
            ? FriendshipService()
            : _EmptyFriendshipService());
    final followRequestService =
        _followRequestService ??
        (Firebase.apps.isNotEmpty
            ? FollowRequestService()
            : _EmptyFollowRequestService());

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
                subtitle: 'Follow and community tools',
                trailing: IconButton(
                  tooltip: 'Find people',
                  // Use standard header foreground, not the sage primary accent.
                  color: AppSurfaces.textPrimary(context),
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FindPeopleScreen(
                          friendshipService: friendshipService,
                          followService: _followService,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: uid == null
                    ? Text(
                        'Sign in to manage follow requests.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppSurfaces.textMuted(context),
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : _FollowRequestSections(
                        currentUserId: uid,
                        friendshipService: friendshipService,
                        followRequestService: followRequestService,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _currentUserId(BuildContext context) {
    try {
      return context.watch<AuthProvider>().currentUser?.uid;
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _EmptyFriendshipService implements FriendshipService {
  @override
  Future<List<PublicProfile>> searchUsers({
    required String query,
    required String currentUserId,
    int limit = 20,
  }) async {
    return const <PublicProfile>[];
  }

  @override
  Stream<PublicProfile?> watchPublicProfile(String uid) {
    return Stream<PublicProfile?>.value(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyFollowRequestService implements FollowRequestService {
  @override
  Stream<List<FollowRequest>> watchIncomingFollowRequests(String uid) {
    return Stream<List<FollowRequest>>.value(const <FollowRequest>[]);
  }

  @override
  Stream<List<FollowRequest>> watchOutgoingFollowRequests(String uid) {
    return Stream<List<FollowRequest>>.value(const <FollowRequest>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FollowRequestSections extends StatelessWidget {
  const _FollowRequestSections({
    required this.currentUserId,
    required this.friendshipService,
    required this.followRequestService,
  });

  final String currentUserId;
  final FriendshipService friendshipService;
  final FollowRequestService followRequestService;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RequestSection(
          title: 'Follow Requests',
          emptyText: 'No incoming requests',
          stream: followRequestService.watchIncomingFollowRequests(
            currentUserId,
          ),
          rowBuilder: (request) => _IncomingRequestRow(
            request: request,
            currentUserId: currentUserId,
            friendshipService: friendshipService,
            followRequestService: followRequestService,
          ),
        ),
        const SizedBox(height: 18),
        _RequestSection(
          title: 'Requested',
          emptyText: 'No outgoing requests',
          stream: followRequestService.watchOutgoingFollowRequests(
            currentUserId,
          ),
          rowBuilder: (request) => _OutgoingRequestRow(
            request: request,
            friendshipService: friendshipService,
            followRequestService: followRequestService,
          ),
        ),
      ],
    );
  }
}

class _RequestSection extends StatelessWidget {
  const _RequestSection({
    required this.title,
    required this.emptyText,
    required this.stream,
    required this.rowBuilder,
  });

  final String title;
  final String emptyText;
  final Stream<List<FollowRequest>> stream;
  final Widget Function(FollowRequest request) rowBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        StreamBuilder<List<FollowRequest>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const _RequestCard(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final requests = snapshot.data ?? const <FollowRequest>[];
            if (requests.isEmpty) {
              return _RequestCard(
                child: Text(
                  emptyText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppSurfaces.textMuted(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (var index = 0; index < requests.length; index += 1) ...[
                  if (index > 0) const SizedBox(height: 10),
                  rowBuilder(requests[index]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: child,
    );
  }
}

class _IncomingRequestRow extends StatefulWidget {
  const _IncomingRequestRow({
    required this.request,
    required this.currentUserId,
    required this.friendshipService,
    required this.followRequestService,
  });

  final FollowRequest request;
  final String currentUserId;
  final FriendshipService friendshipService;
  final FollowRequestService followRequestService;

  @override
  State<_IncomingRequestRow> createState() => _IncomingRequestRowState();
}

class _IncomingRequestRowState extends State<_IncomingRequestRow> {
  var _busy = false;

  Future<void> _accept() async {
    await _run(() {
      return widget.followRequestService.acceptFollowRequest(
        requestId: widget.request.id,
        currentUserId: widget.currentUserId,
      );
    });
  }

  Future<void> _decline() async {
    await _run(() {
      return widget.followRequestService.declineFollowRequest(
        requestId: widget.request.id,
        currentUserId: widget.currentUserId,
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      debugPrint('[SocialScreen] follow request action failed: $error');
      if (mounted) {
        AppToast.error(context, 'Could not update follow request.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PublicProfile?>(
      stream: widget.friendshipService.watchPublicProfile(
        widget.request.requesterId,
      ),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return _RequestCard(
          child: Row(
            children: [
              _RequestAvatar(profile: profile),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            profile?.displayName ??
                            profile?.username ??
                            'Someone',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppSurfaces.textPrimary(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: ' requested to follow you',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppSurfaces.textMuted(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy ? null : _decline,
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Decline'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: _busy ? null : _accept,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Accept'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OutgoingRequestRow extends StatefulWidget {
  const _OutgoingRequestRow({
    required this.request,
    required this.friendshipService,
    required this.followRequestService,
  });

  final FollowRequest request;
  final FriendshipService friendshipService;
  final FollowRequestService followRequestService;

  @override
  State<_OutgoingRequestRow> createState() => _OutgoingRequestRowState();
}

class _OutgoingRequestRowState extends State<_OutgoingRequestRow> {
  var _busy = false;

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.followRequestService.cancelFollowRequest(
        requesterId: widget.request.requesterId,
        targetId: widget.request.targetId,
      );
    } catch (error) {
      debugPrint('[SocialScreen] cancel follow request failed: $error');
      if (mounted) {
        AppToast.error(context, 'Could not cancel request.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PublicProfile?>(
      stream: widget.friendshipService.watchPublicProfile(
        widget.request.targetId,
      ),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return _RequestCard(
          child: Row(
            children: [
              _RequestAvatar(profile: profile),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.displayName ?? profile?.username ?? 'Traveller',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppSurfaces.textPrimary(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      profile == null
                          ? widget.request.targetId
                          : '@${profile.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppSurfaces.textMuted(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy ? null : _cancel,
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Requested'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RequestAvatar extends StatelessWidget {
  const _RequestAvatar({required this.profile});

  final PublicProfile? profile;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile?.photoUrl;
    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
          ? NetworkImage(photoUrl)
          : null,
      child: photoUrl != null && photoUrl.isNotEmpty
          ? null
          : const Icon(Icons.person_rounded, size: 20),
    );
  }
}
