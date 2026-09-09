import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/party_service.dart';
import '../domain/party.dart';

/// Entry point for Party Mode: create/join a party, or view party-home once
/// in one.
class PartyScreen extends StatefulWidget {
  const PartyScreen({super.key, required this.partyService});

  final PartyService partyService;

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> {
  Party? _party;
  bool _isJoining = false;
  String? _joinError;
  final _codeController = TextEditingController();

  Future<void> _createParty() async {
    final uid = context.read<AuthProvider>().currentUser!.uid;
    final created = await widget.partyService.createParty();
    final joined = await widget.partyService.joinParty(
      code: created.joinCode,
      uid: uid,
    );
    setState(() => _party = joined);
  }

  Future<void> _submitJoinCode() async {
    final uid = context.read<AuthProvider>().currentUser!.uid;
    try {
      final joined = await widget.partyService.joinParty(
        code: _codeController.text,
        uid: uid,
      );
      setState(() => _party = joined);
    } on PartyNotFoundException {
      setState(() => _joinError = 'No party found for that code.');
    } on PartyFullException {
      setState(() => _joinError = 'That party is full.');
    }
  }

  Future<void> _leaveParty() async {
    final uid = context.read<AuthProvider>().currentUser!.uid;
    await widget.partyService.leaveParty(partyId: _party!.id, uid: uid);
    setState(() {
      _party = null;
      _isJoining = false;
      _joinError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Party Mode')),
      body: _party == null ? _buildForm() : _buildPartyHome(_party!),
    );
  }

  Widget _buildForm() {
    if (_isJoining) {
      return Column(
        children: [
          TextField(controller: _codeController),
          ElevatedButton(
            onPressed: _submitJoinCode,
            child: const Text('Submit'),
          ),
          if (_joinError != null) Text(_joinError!),
        ],
      );
    }
    return Column(
      children: [
        ElevatedButton(
          onPressed: _createParty,
          child: const Text('Create Party'),
        ),
        ElevatedButton(
          onPressed: () => setState(() => _isJoining = true),
          child: const Text('Join Party'),
        ),
      ],
    );
  }

  Widget _buildPartyHome(Party party) {
    return Column(
      children: [
        Text(
          'Join code: ${party.joinCode}\n'
          'Team A: ${party.teamAMembers}\n'
          'Team B: ${party.teamBMembers}',
        ),
        ElevatedButton(onPressed: _leaveParty, child: const Text('Leave Party')),
      ],
    );
  }
}
