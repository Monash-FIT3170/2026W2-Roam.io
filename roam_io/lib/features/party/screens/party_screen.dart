/*
 * Author: Sanjevan Rajasegar & Copilot
 * Description:
 *   Entry point for Party Mode: create/join a party, view the active party,
 *   or view party home with team rosters and map navigation.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/party_service.dart';
import '../data/party_tile_ownership_service.dart';
import '../domain/party.dart';
import '../widgets/confirm_leave_party.dart';
import '../widgets/party_landing.dart';
import '../widgets/party_member_name.dart';
import '../widgets/party_name_dialog.dart';
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
  StreamSubscription<Map<String, String?>>? _tileOwnershipSubscription;
  Map<String, String?>? _tileOwnership;
  bool _hasLoadedParty = false;
  bool _isSubmitting = false;
  bool _partyLoadFailed = false;

  void _setParty(Party? party) {
    if (_party?.id == party?.id) {
      setState(() => _party = party);
      widget.onPartyChanged?.call(party);
      return;
    }
    setState(() => _party = party);
    widget.onPartyChanged?.call(party);
    _watchParty(party);
    _watchTileOwnership(party);
  }

  void _watchTileOwnership(Party? party) {
    unawaited(_tileOwnershipSubscription?.cancel());
    _tileOwnershipSubscription = null;
    _tileOwnership = null;
    if (party == null) return;
    _tileOwnershipSubscription =
        PartyTileOwnershipService(firestore: widget.partyService.firestore)
            .watchOwnership(party.id)
            .listen(
              (ownership) {
                if (mounted && _party?.id == party.id) {
                  setState(() => _tileOwnership = ownership);
                }
              },
              onError: (Object _, StackTrace _) {
                if (mounted && _party?.id == party.id) {
                  setState(() => _tileOwnership = null);
                }
              },
            );
  }

  void _watchParty(Party? party) {
    unawaited(_partySubscription?.cancel());
    _partySubscription = party == null
        ? null
        : widget.partyService.watchParty(party.id).listen((live) {
            if (!mounted) return;
            final uid = context.read<AuthProvider>().currentUser?.uid;
            _setParty(uid != null && live?.isMember(uid) == true ? live : null);
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
        .listen(
          (parties) {
            if (!mounted) return;
            setState(() {
              _hasLoadedParty = true;
              _partyLoadFailed = false;
            });
            if (parties.isNotEmpty) {
              _setParty(parties.first);
              setState(() => _isJoining = false);
            } else if (_party != null && !_isSubmitting) {
              _setParty(null);
            }
          },
          onError: (Object _) {
            if (mounted) {
              setState(() {
                _hasLoadedParty = true;
                _partyLoadFailed = true;
              });
            }
          },
        );
  }

  @override
  void initState() {
    super.initState();
    _party = widget.initialParty;
    _watchParty(_party);
    _watchTileOwnership(_party);

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
    _tileOwnershipSubscription?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _promptToCreateParty() async {
    if (_party != null || _isSubmitting) return;
    final name = await showPartyNameDialog(context, creating: true);
    if (!mounted || name == null || _party != null || _isSubmitting) return;
    await _createParty(name);
  }

  Future<void> _createParty(String name) async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) {
      setState(() => _createError = 'Must be signed in to create a party.');
      return;
    }
    if (_party != null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final joined = await widget.partyService.createParty(
        uid: uid,
        name: name,
      );
      if (!mounted) return;
      setState(() => _createError = null);
      _setParty(joined);
      _openPartyMap(joined);
    } on AlreadyInPartyException {
      if (mounted) {
        setState(
          () => _createError =
              'You are already in a party. Leave it before creating another.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _createError = 'Could not create a party. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
    if (_party != null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final joined = await widget.partyService.joinParty(code: code, uid: uid);
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
    } on AlreadyInPartyException {
      if (mounted) {
        setState(
          () => _joinError =
              'You are already in a party. Leave it before joining another.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _joinError = 'Could not join party. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _leaveParty({String? partyId}) async {
    final targetId = partyId ?? _party?.id;
    if (targetId == null) return;
    if (_isSubmitting || !await confirmLeaveParty(context)) return;
    if (!mounted || _party?.id != targetId) return;
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.partyService.leaveParty(partyId: targetId, uid: uid);
      if (!mounted) return;
      if (_party?.id == targetId) {
        _setParty(null);
      }
      setState(() {
        _isJoining = false;
        _joinError = null;
      });
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not leave party.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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

  Future<void> _copyJoinCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      AppToast.success(context, 'Join code $code copied to clipboard!');
    }
  }

  Future<void> _renameParty(Party party) async {
    if (_isSubmitting) return;
    final name = await showPartyNameDialog(
      context,
      initialName: party.name,
      creating: false,
    );
    if (!mounted ||
        name == null ||
        name == party.name ||
        _party?.id != party.id ||
        _isSubmitting) {
      return;
    }
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    setState(() => _isSubmitting = true);
    try {
      final updated = await widget.partyService.renameParty(
        partyId: party.id,
        uid: uid,
        name: name,
      );
      if (!mounted || _party?.id != party.id) return;
      _setParty(updated);
      AppToast.success(context, 'Party name updated.');
    } catch (_) {
      if (mounted) AppToast.error(context, 'Could not update party name.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLanding =
        _hasLoadedParty && !_partyLoadFailed && _party == null && !_isJoining;
    return Scaffold(
      appBar: AppBar(title: const Text('Party Mode')),
      body: showLanding
          ? PartyLanding(
              onCreate: _isSubmitting ? null : _promptToCreateParty,
              onJoin: _isSubmitting
                  ? null
                  : () => setState(() => _isJoining = true),
              error: _createError,
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_hasLoadedParty && _party == null)
                    const Center(child: CircularProgressIndicator())
                  else if (_partyLoadFailed && _party == null)
                    const Text(
                      'Could not load your party. Please reopen Party Mode.',
                    )
                  else if (_party == null)
                    _buildForm()
                  else
                    _buildActiveParty(_party!),
                ],
              ),
            ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        TextField(controller: _codeController),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitJoinCode,
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

  Widget _buildActiveParty(Party party) {
    final theme = Theme.of(context);
    final uid = context.watch<AuthProvider>().currentUser?.uid;
    final teamATiles = _tileOwnership?.values
        .where((team) => team == 'A')
        .length;
    final teamBTiles = _tileOwnership?.values
        .where((team) => team == 'B')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _sectionDecoration(AppSurfaces.card(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      party.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit party name',
                    onPressed: _isSubmitting ? null : () => _renameParty(party),
                    icon: const Icon(Icons.edit_rounded, size: 19),
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: 'Copy join code',
                  child: TextButton(
                    onPressed: () => _copyJoinCode(party.joinCode),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Join code: ${party.joinCode}'),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _openPartyMap(party),
                icon: const Icon(Icons.map_rounded, size: 19),
                label: const Text('View Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppSurfaces.softCard(context),
                  foregroundColor: theme.colorScheme.primary,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(child: _tileCount('Team A', teamATiles)),
                  const SizedBox(width: 10),
                  Expanded(child: _tileCount('Team B', teamBTiles)),
                ],
              ),
              const SizedBox(height: 22),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _teamMembersCard('A', party.teamAMembers, uid),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _teamMembersCard('B', party.teamBMembers, uid),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _leaveParty(partyId: party.id),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  child: const Text('Leave Party'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration _sectionDecoration(Color color) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppSurfaces.border(context)),
  );

  Widget _tileCount(String team, int? count) {
    final theme = Theme.of(context);
    final teamColor = team == 'Team A'
        ? const Color(0xFF0288D1)
        : const Color(0xFFE53935);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppSurfaces.innerCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: teamColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Text(
            team,
            style: theme.textTheme.labelMedium?.copyWith(
              color: teamColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count == null ? '—' : '$count ${count == 1 ? 'tile' : 'tiles'}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamMembersCard(String team, List<String> members, String? uid) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppSurfaces.innerCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team $team Members',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${members.length} ${members.length == 1 ? 'member' : 'members'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppSurfaces.textMuted(context),
            ),
          ),
          const SizedBox(height: 14),
          if (members.isEmpty)
            Text('No members yet', style: theme.textTheme.bodySmall)
          else
            for (final member in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PartyMemberName(
                  uid: member,
                  currentUserId: uid,
                  firestore: widget.partyService.firestore,
                  style: member == uid
                      ? theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )
                      : theme.textTheme.bodyMedium,
                ),
              ),
        ],
      ),
    );
  }
}
