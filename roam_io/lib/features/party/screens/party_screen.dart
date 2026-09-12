/*
 * Author: Sanjevan Rajasegar & Copilot
 * Description:
 *   Entry point for Party Mode: create/join a party, view active user parties,
 *   or view party home with team rosters and map navigation.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/party_service.dart';
import '../domain/party.dart';
import 'party_map_screen.dart';

/// Entry point for Party Mode: create/join a party, or view party-home once
/// in one.
class PartyScreen extends StatefulWidget {
  const PartyScreen({
    super.key,
    required this.partyService,
    this.initialParty,
    this.onPartyChanged,
  });

  final PartyService partyService;

  /// The party the user is already in, so reopening this screen shows the
  /// party home instead of the create/join form.
  final Party? initialParty;

  /// Notified whenever the active party changes (created, joined, or left),
  /// so callers can keep a shared "current party" context up to date.
  final ValueChanged<Party?>? onPartyChanged;

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> {
  Party? _party;
  bool _isJoining = false;
  String? _joinError;
  String? _createError;
  final _codeController = TextEditingController();
  StreamSubscription<Party?>? _partySubscription;
  StreamSubscription<List<Party>>? _userPartiesSubscription;
  List<Party> _userParties = [];

  void _setParty(Party? party) {
    setState(() => _party = party);
    widget.onPartyChanged?.call(party);
    _watchParty(party);
  }

  void _watchParty(Party? party) {
    unawaited(_partySubscription?.cancel());
    _partySubscription = party == null
        ? null
        : widget.partyService.watchParty(party.id).listen((live) {
            if (!mounted) return;
            setState(() => _party = live);
            widget.onPartyChanged?.call(live);
          });
  }

  void _watchUserParties(String? uid) {
    unawaited(_userPartiesSubscription?.cancel());
    if (uid == null) {
      _userPartiesSubscription = null;
      return;
    }
    _userPartiesSubscription = widget.partyService
        .watchUserParties(uid)
        .listen((parties) {
          if (!mounted) return;
          setState(() => _userParties = parties);
        });
  }

  @override
  void initState() {
    super.initState();
    _party = widget.initialParty;
    _watchParty(_party);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().currentUser?.uid;
      _watchUserParties(uid);
    });
  }

  @override
  void dispose() {
    _partySubscription?.cancel();
    _userPartiesSubscription?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createParty() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) {
      setState(() => _createError = 'Must be signed in to create a party.');
      return;
    }
    try {
      final created = await widget.partyService.createParty();
      final joined = await widget.partyService.joinParty(
        code: created.joinCode,
        uid: uid,
      );
      if (!mounted) return;
      setState(() => _createError = null);
      _setParty(joined);
      _openPartyMap(joined);
    } catch (_) {
      if (mounted) {
        setState(
          () => _createError = 'Could not create a party. Please try again.',
        );
      }
    }
  }

  Future<void> _submitJoinCode() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) {
      setState(() => _joinError = 'Must be signed in to join a party.');
      return;
    }
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _joinError = 'Please enter a join code.');
      return;
    }
    try {
      final joined = await widget.partyService.joinParty(
        code: code,
        uid: uid,
      );
      if (!mounted) return;
      setState(() {
        _joinError = null;
        _isJoining = false;
      });
      _codeController.clear();
      _setParty(joined);
      _openPartyMap(joined);
    } on PartyNotFoundException {
      if (mounted) {
        setState(() => _joinError = 'No party found for that code.');
      }
    } on PartyFullException {
      if (mounted) {
        setState(() => _joinError = 'That party is full.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _joinError = 'Could not join party. Please try again.');
      }
    }
  }

  Future<void> _leaveParty({String? partyId}) async {
    final targetId = partyId ?? _party?.id;
    if (targetId == null) return;
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    try {
      await widget.partyService.leaveParty(partyId: targetId, uid: uid);
      if (_party?.id == targetId) {
        _setParty(null);
      }
      if (!mounted) return;
      setState(() {
        _isJoining = false;
        _joinError = null;
      });
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not leave party.');
      }
    }
  }

  void _openPartyMap(Party party) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartyMapScreen(
          party: party,
          partyService: widget.partyService,
          onPartyChanged: (updated) {
            if (updated == null) {
              if (_party?.id == party.id) {
                _setParty(null);
              }
            } else {
              _setParty(updated);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Party Mode'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildForm(),
            if (_userParties.isNotEmpty) ...[
              const SizedBox(height: 28),
              _buildUserPartiesList(),
            ],
          ],
        ),
      ),
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
          TextButton(
            onPressed: () {
              setState(() {
                _isJoining = false;
                _joinError = null;
              });
            },
            child: const Text('Cancel'),
          ),
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
        if (_createError != null) Text(_createError!),
      ],
    );
  }

  Widget _buildUserPartiesList() {
    final theme = Theme.of(context);
    final uid = context.watch<AuthProvider>().currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Parties',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ..._userParties.map((party) {
          final userTeam = uid != null ? party.teamForUser(uid) : null;
          final isSelected = _party?.id == party.id;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppSurfaces.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : AppSurfaces.border(context),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Party #${party.joinCode}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (userTeam != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: userTeam == 'A'
                              ? const Color(0xFF0288D1).withValues(alpha: 0.12)
                              : const Color(0xFFE53935).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Team $userTeam',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: userTeam == 'A'
                                ? const Color(0xFF0288D1)
                                : const Color(0xFFE53935),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Team A: ${party.teamAMembers.length} members · Team B: ${party.teamBMembers.length} members',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppSurfaces.textMuted(context),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.map_rounded, size: 18),
                        onPressed: () => _openPartyMap(party),
                        label: const Text('View Map'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _leaveParty(partyId: party.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Leave'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
