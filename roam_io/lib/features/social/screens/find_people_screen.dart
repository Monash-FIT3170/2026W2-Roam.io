/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Provides live user search and friend-request actions for the Social tab.
 */

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/friendship_service.dart';
import '../domain/friend_relationship.dart';
import '../domain/public_profile.dart';
import 'other_user_profile_screen.dart';

/// Dedicated user-search screen for finding registered users.
class FindPeopleScreen extends StatefulWidget {
  const FindPeopleScreen({super.key, FriendshipService? friendshipService})
    : _friendshipService = friendshipService;

  final FriendshipService? _friendshipService;

  @override
  State<FindPeopleScreen> createState() => _FindPeopleScreenState();
}

class _FindPeopleScreenState extends State<FindPeopleScreen> {
  late final FriendshipService _friendshipService;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  var _results = const <PublicProfile>[];
  var _isSearching = false;
  var _hasCompletedSearch = false;
  var _searchFailed = false;
  var _query = '';
  var _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _friendshipService = widget._friendshipService ?? FriendshipService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    _query = query;

    if (query.isEmpty) {
      _searchGeneration += 1;
      setState(() {
        _isSearching = false;
        _hasCompletedSearch = false;
        _searchFailed = false;
        _results = const <PublicProfile>[];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    if (currentUserId == null) return;

    final generation = ++_searchGeneration;
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _friendshipService.searchUsers(
        query: query,
        currentUserId: currentUserId,
      );
      if (!mounted || generation != _searchGeneration || query != _query) {
        return;
      }
      setState(() {
        _results = results;
        _isSearching = false;
        _hasCompletedSearch = true;
        _searchFailed = false;
      });
    } catch (error, stackTrace) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _isSearching = false;
        _hasCompletedSearch = false;
        _searchFailed = true;
      });
      final code = error is FirebaseException ? error.code : 'unknown';
      debugPrint(
        '[FindPeopleScreen] Search failed operation=public_profiles_prefix '
        'query="$query" code=$code '
        'error=$error\n$stackTrace',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().currentUser?.uid;

    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(title: const Text('Find People')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                onChanged: _handleQueryChanged,
                decoration: const InputDecoration(
                  hintText: 'Search by name or username...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _SearchResults(
                currentUserId: currentUserId,
                query: _query,
                isSearching: _isSearching,
                hasCompletedSearch: _hasCompletedSearch,
                searchFailed: _searchFailed,
                results: _results,
                friendshipService: _friendshipService,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.currentUserId,
    required this.query,
    required this.isSearching,
    required this.hasCompletedSearch,
    required this.searchFailed,
    required this.results,
    required this.friendshipService,
  });

  final String? currentUserId;
  final String query;
  final bool isSearching;
  final bool hasCompletedSearch;
  final bool searchFailed;
  final List<PublicProfile> results;
  final FriendshipService friendshipService;

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Center(child: Text('Sign in to find people.'));
    }

    if (query.isEmpty || searchFailed) {
      return const SizedBox.shrink();
    }

    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasCompletedSearch && results.isEmpty) {
      return const Center(child: Text('No people found.'));
    }

    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _PersonResultRow(
          profile: results[index],
          currentUserId: currentUserId!,
          friendshipService: friendshipService,
        );
      },
    );
  }
}

class _PersonResultRow extends StatelessWidget {
  const _PersonResultRow({
    required this.profile,
    required this.currentUserId,
    required this.friendshipService,
  });

  final PublicProfile profile;
  final String currentUserId;
  final FriendshipService friendshipService;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OtherUserProfileScreen(
                      selectedUserId: profile.uid,
                      friendshipService: friendshipService,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  _ProfileAvatar(profile: profile),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppSurfaces.textPrimary(context),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${profile.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppSurfaces.textMuted(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          StreamBuilder<FriendRelationship>(
            stream: friendshipService.watchRelationship(
              currentUserId: currentUserId,
              otherUserId: profile.uid,
            ),
            initialData: const FriendRelationship.none(),
            builder: (context, snapshot) {
              return _RelationshipAction(
                currentUserId: currentUserId,
                profile: profile,
                relationship: snapshot.data ?? const FriendRelationship.none(),
                friendshipService: friendshipService,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final photoUrl = profile.photoUrl;
    final initial = profile.displayName.trim().isEmpty
        ? '?'
        : profile.displayName.trim().characters.first;
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      backgroundImage: photoUrl == null || photoUrl.isEmpty
          ? null
          : NetworkImage(photoUrl),
      child: photoUrl == null || photoUrl.isEmpty ? Text(initial) : null,
    );
  }
}

class _RelationshipAction extends StatefulWidget {
  const _RelationshipAction({
    required this.currentUserId,
    required this.profile,
    required this.relationship,
    required this.friendshipService,
  });

  final String currentUserId;
  final PublicProfile profile;
  final FriendRelationship relationship;
  final FriendshipService friendshipService;

  @override
  State<_RelationshipAction> createState() => _RelationshipActionState();
}

class _RelationshipActionState extends State<_RelationshipAction> {
  var _isBusy = false;

  Future<void> _sendRequest() async {
    setState(() => _isBusy = true);
    try {
      final result = await widget.friendshipService.sendRequest(
        senderId: widget.currentUserId,
        recipientId: widget.profile.uid,
      );
      if (!mounted) return;
      if (result == SendFriendRequestResult.sent) {
        AppToast.success(context, 'Friend request sent.');
      } else if (result == SendFriendRequestResult.incomingRequest) {
        AppToast.show(context, 'They already sent you a request.');
      } else if (result == SendFriendRequestResult.alreadyFriends) {
        AppToast.show(context, 'You are already friends.');
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not send friend request.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _acceptRequest() async {
    final requestId = widget.relationship.request?.id;
    if (requestId == null) return;
    setState(() => _isBusy = true);
    try {
      await widget.friendshipService.acceptRequest(
        requestId: requestId,
        currentUserId: widget.currentUserId,
      );
      if (mounted) AppToast.success(context, 'Friend request accepted.');
    } catch (_) {
      if (mounted) AppToast.error(context, 'Could not accept request.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _declineRequest() async {
    final requestId = widget.relationship.request?.id;
    if (requestId == null) return;
    setState(() => _isBusy = true);
    try {
      await widget.friendshipService.declineRequest(
        requestId: requestId,
        currentUserId: widget.currentUserId,
      );
      if (mounted) AppToast.success(context, 'Friend request declined.');
    } catch (_) {
      if (mounted) AppToast.error(context, 'Could not decline request.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBusy) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return switch (widget.relationship.status) {
      FriendRelationshipStatus.none => FilledButton(
        onPressed: _sendRequest,
        child: const Text('Add Friend'),
      ),
      FriendRelationshipStatus.requestSent => const Text('Request Sent'),
      FriendRelationshipStatus.incomingRequest => Wrap(
        spacing: 6,
        children: [
          FilledButton(onPressed: _acceptRequest, child: const Text('Accept')),
          TextButton(onPressed: _declineRequest, child: const Text('Decline')),
        ],
      ),
      FriendRelationshipStatus.friends => const Text('Friends'),
    };
  }
}
