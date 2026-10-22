import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../theme/app_cartoon.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../social/domain/public_profile.dart';
import '../data/party_invite_service.dart';
import '../domain/party.dart';
import 'party_style.dart';

Future<void> showInviteFriendsSheet(
  BuildContext context, {
  required Party party,
  required String inviterId,
  required PartyInviteService inviteService,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppSurfaces.pageBackground(context),
    builder: (_) => _InviteFriendsSheet(
      party: party,
      inviterId: inviterId,
      inviteService: inviteService,
    ),
  );
}

class _InviteFriendsSheet extends StatefulWidget {
  const _InviteFriendsSheet({
    required this.party,
    required this.inviterId,
    required this.inviteService,
  });

  final Party party;
  final String inviterId;
  final PartyInviteService inviteService;

  @override
  State<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<_InviteFriendsSheet> {
  late final Future<List<PartyInviteCandidate>> _friends;
  final Set<String> _sent = {};
  final Set<String> _sending = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _friends = widget.inviteService.getCandidates(widget.inviterId);
  }

  Future<void> _invite(PublicProfile friend) async {
    setState(() {
      _sending.add(friend.uid);
      _error = null;
    });
    try {
      await widget.inviteService.invite(
        party: widget.party,
        senderId: widget.inviterId,
        recipientId: friend.uid,
      );
      if (mounted) setState(() => _sent.add(friend.uid));
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } catch (error) {
      debugPrint(
        '[PartyInvite] invite failed senderId=${widget.inviterId} '
        'recipientId=${friend.uid} partyId=${widget.party.id} '
        'code=${error is FirebaseException ? error.code : 'unknown'} '
        'error=$error',
      );
      if (mounted) {
        setState(
          () => _error = 'Could not invite ${friend.displayName}. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending.remove(friend.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invite friends',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Invite a friend to ${widget.party.displayName}. They can choose to join from Notifications.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppSurfaces.textMuted(context),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: FutureBuilder<List<PartyInviteCandidate>>(
                future: _friends,
                builder: (context, snapshot) {
                  if (!snapshot.hasData && !snapshot.hasError) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Text(
                      'Could not load friends. Please try again.',
                    );
                  }
                  final friends = snapshot.data!
                      .where(
                        (candidate) =>
                            !widget.party.isMember(candidate.profile.uid),
                      )
                      .toList();
                  if (friends.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No friends or people you follow available to invite yet.',
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final candidate = friends[index];
                      final friend = candidate.profile;
                      final unavailable = candidate.isInParty;
                      final muted = AppSurfaces.textSubtle(context);
                      final row = ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: unavailable
                            ? () => setState(
                                () => _error =
                                    'Cannot invite because this user is already a member of another party',
                              )
                            : null,
                        leading: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: unavailable
                                ? AppSurfaces.softCard(context)
                                : AppColors.sand,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: PartyStyle.outline(context),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            friend.displayName.isEmpty
                                ? '?'
                                : friend.displayName[0].toUpperCase(),
                            style: TextStyle(
                              color: unavailable ? muted : AppColors.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        title: Text(
                          friend.displayName,
                          style: TextStyle(
                            color: unavailable ? muted : null,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: unavailable
                            ? Text(
                                'Already in a party',
                                style: TextStyle(color: muted),
                              )
                            : friend.username.isEmpty
                            ? null
                            : Text('@${friend.username}'),
                        trailing: unavailable
                            ? Icon(Icons.block_rounded, color: muted)
                            : _sent.contains(friend.uid)
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.sage,
                              )
                            : CartoonPressable(
                                soft: true,
                                enabled: !_sending.contains(friend.uid),
                                offset: 3,
                                child: TextButton(
                                  onPressed: _sending.contains(friend.uid)
                                      ? null
                                      : () => _invite(friend),
                                  style: PartyStyle.button(
                                    context,
                                    background: AppColors.sage,
                                    foreground: Colors.white,
                                    height: 36,
                                  ),
                                  child: const Text('Invite'),
                                ),
                              ),
                      );
                      return row;
                    },
                  );
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 12),
            CartoonPressable(
              soft: true,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: PartyStyle.button(
                  context,
                  background: AppSurfaces.softCard(context),
                  foreground: AppSurfaces.textPrimary(context),
                  height: 50,
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
