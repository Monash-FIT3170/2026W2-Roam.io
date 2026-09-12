import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../social/data/friendship_service.dart';
import '../../social/domain/public_profile.dart';

/// Shows a party member's public name without exposing their account ID.
class PartyMemberName extends StatefulWidget {
  const PartyMemberName({
    super.key,
    required this.uid,
    required this.currentUserId,
    required this.firestore,
    this.style,
  });

  final String uid;
  final String? currentUserId;
  final FirebaseFirestore firestore;
  final TextStyle? style;

  @override
  State<PartyMemberName> createState() => _PartyMemberNameState();
}

class _PartyMemberNameState extends State<PartyMemberName> {
  late Stream<PublicProfile?> _profile;

  @override
  void initState() {
    super.initState();
    _watchProfile();
  }

  @override
  void didUpdateWidget(PartyMemberName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.firestore != widget.firestore) {
      _watchProfile();
    }
  }

  void _watchProfile() {
    _profile = FriendshipService(
      firestore: widget.firestore,
    ).watchPublicProfile(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid == widget.currentUserId) {
      final name = context
          .watch<AuthProvider>()
          .currentProfile
          ?.displayName
          .trim();
      return _nameText(name == null || name.isEmpty ? 'You' : name);
    }

    return StreamBuilder<PublicProfile?>(
      stream: _profile,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.displayName.trim() ?? '';
        final username = profile?.username.trim() ?? '';
        return _nameText(
          name.isNotEmpty
              ? name
              : username.isNotEmpty
              ? '@$username'
              : 'Member',
        );
      },
    );
  }

  Widget _nameText(String name) => Text(
    name,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: widget.style,
  );
}
