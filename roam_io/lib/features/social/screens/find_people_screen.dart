/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 8 August 2026
 * Description:
 *   Provides live user search with public-profile Follow / Following actions
 *   for the Social tab. Queries public_profiles by usernameSearch /
 *   displayNameSearch (requires deployed rules: signed-in read on
 *   public_profiles). Search is independent of Follow; Follow state loads
 *   per row after results. Search failures are shown explicitly (not blank).
 *   Friend-request UI is intentionally not shown during the public Follow
 *   phase.
 */

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/follow_service.dart';
import '../data/friendship_service.dart';
import '../domain/public_profile.dart';
import '../widgets/follow_relationship_button.dart';
import 'other_user_profile_screen.dart';

/// Dedicated user-search screen for finding registered users.
class FindPeopleScreen extends StatefulWidget {
  const FindPeopleScreen({
    super.key,
    FriendshipService? friendshipService,
    FollowService? followService,
  }) : _friendshipService = friendshipService,
       _followService = followService;

  final FriendshipService? _friendshipService;
  final FollowService? _followService;

  @override
  State<FindPeopleScreen> createState() => _FindPeopleScreenState();
}

class _FindPeopleScreenState extends State<FindPeopleScreen> {
  late final FriendshipService _friendshipService;
  late final FollowService _followService;
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
    _followService = widget._followService ?? FollowService();
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

    // Show spinner during debounce so the list is never silently blank.
    setState(() {
      _isSearching = true;
      _searchFailed = false;
    });

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    if (currentUserId == null) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _hasCompletedSearch = false;
        _searchFailed = false;
        _results = const <PublicProfile>[];
      });
      return;
    }

    final generation = ++_searchGeneration;
    if (!_isSearching) {
      setState(() {
        _isSearching = true;
        _searchFailed = false;
      });
    }

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
        _results = const <PublicProfile>[];
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
                followService: _followService,
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
    required this.followService,
  });

  final String? currentUserId;
  final String query;
  final bool isSearching;
  final bool hasCompletedSearch;
  final bool searchFailed;
  final List<PublicProfile> results;
  final FriendshipService friendshipService;
  final FollowService followService;

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Center(child: Text('Sign in to find people.'));
    }

    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    if (searchFailed) {
      return Center(
        child: Text(
          'Could not search people right now.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppSurfaces.textMuted(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
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
          followService: followService,
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
    required this.followService,
  });

  final PublicProfile profile;
  final String currentUserId;
  final FriendshipService friendshipService;
  final FollowService followService;

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
                      followService: followService,
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
          FollowRelationshipButton(
            followerId: currentUserId,
            followeeId: profile.uid,
            followService: followService,
            followeeProfile: profile,
            compact: true,
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
    final url = profile.photoUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final initial = profile.displayName.trim().isEmpty
        ? '?'
        : profile.displayName.trim().characters.first;
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      backgroundImage: hasPhoto ? NetworkImage(url) : null,
      child: hasPhoto ? null : Text(initial),
    );
  }
}
