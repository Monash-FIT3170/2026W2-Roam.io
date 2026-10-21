/*
 * Author: Sanjevan Rajasegar & Copilot
 * Description:
 *   Entry point for Party Mode: create/join a party, view the active party,
 *   or view party home with team rosters and map navigation.
 */

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_cartoon.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/party_invite_service.dart';
import '../data/party_service.dart';
import '../data/party_tile_ownership_service.dart';
import '../domain/party.dart';
import '../widgets/confirm_leave_party.dart';
import '../widgets/invite_friends_sheet.dart';
import '../widgets/party_landing.dart';
import '../widgets/party_member_name.dart';
import '../widgets/party_name_dialog.dart';
import '../widgets/party_style.dart';
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
  Map<String, String?> _subcollectionTileOwnership = const {};
  bool _hasLoadedParty = false;
  bool _isSubmitting = false;
  bool _partyLoadFailed = false;

  void _setParty(Party? party) {
    if (_party?.id == party?.id) {
      setState(() {
        _party = party;
        _tileOwnership = _combinedTileOwnership(party);
      });
      widget.onPartyChanged?.call(party);
      return;
    }
    setState(() {
      _party = party;
      _subcollectionTileOwnership = const {};
      _tileOwnership = party?.tileOwnership;
    });
    widget.onPartyChanged?.call(party);
    _watchParty(party);
    _watchTileOwnership(party);
  }

  Map<String, String?> _combinedTileOwnership(Party? party) {
    return <String, String?>{
      ...?party?.tileOwnership,
      ..._subcollectionTileOwnership,
    };
  }

  void _watchTileOwnership(Party? party) {
    unawaited(_tileOwnershipSubscription?.cancel());
    _tileOwnershipSubscription = null;
    _subcollectionTileOwnership = const {};
    _tileOwnership = party?.tileOwnership;
    if (party == null) return;
    _tileOwnershipSubscription =
        PartyTileOwnershipService(firestore: widget.partyService.firestore)
            .watchOwnership(party.id)
            .listen(
              (ownership) {
                if (mounted && _party?.id == party.id) {
                  setState(() {
                    _subcollectionTileOwnership = ownership;
                    _tileOwnership = _combinedTileOwnership(_party);
                  });
                }
              },
              onError: (Object error, StackTrace stackTrace) {
                debugPrint(
                  '[PartyScreen] Could not watch tile subcollection for '
                  '${party.id}: $error\n$stackTrace',
                );
                if (mounted && _party?.id == party.id) {
                  setState(() {
                    _subcollectionTileOwnership = const {};
                    _tileOwnership = _party?.tileOwnership ?? const {};
                  });
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
    _tileOwnership = _party?.tileOwnership;
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
      await _showInviteFriends(joined);
      if (!mounted) return;
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

  Future<void> _showInviteFriends(Party party) async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || !party.isMember(uid)) return;
    await showInviteFriendsSheet(
      context,
      party: party,
      inviterId: uid,
      inviteService: PartyInviteService(
        firestore: widget.partyService.firestore,
      ),
    );
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
    } catch (error, stackTrace) {
      debugPrint(
        '[PartyScreen] Could not leave party $targetId: '
        '$error\n$stackTrace',
      );
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
      backgroundColor: AppSurfaces.pageBackground(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CartoonPageHeader(
              title: 'Party Mode',
              showBrand: true,
              soft: true,
              outlineWidth: PartyStyle.outlineWidth,
            ),
            Expanded(
              child: showLanding
                  ? PartyLanding(
                      onCreate: _isSubmitting ? null : _promptToCreateParty,
                      onJoin: _isSubmitting
                          ? null
                          : () => setState(() => _isJoining = true),
                      error: _createError,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_hasLoadedParty && _party == null)
                            const Center(child: CircularProgressIndicator())
                          else if (_partyLoadFailed && _party == null)
                            Text(
                              'Could not load your party. Please reopen Party Mode.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppSurfaces.textMuted(context),
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else if (_party == null)
                            _buildForm()
                          else
                            _buildActiveParty(_party!),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    final outline = PartyStyle.outline(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: PartyStyle.outlineWidth),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
      decoration: PartyStyle.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Join a party',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pop in the join code a friend shared with you.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _isSubmitting ? null : _submitJoinCode(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
            decoration: InputDecoration(
              hintText: 'JOIN CODE',
              hintStyle: TextStyle(
                color: AppSurfaces.textSubtle(context),
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
              ),
              filled: true,
              fillColor: AppSurfaces.softCard(context),
              prefixIcon: const Icon(Icons.vpn_key_rounded),
              border: border(outline),
              enabledBorder: border(outline),
              focusedBorder: border(AppColors.sage),
            ),
          ),
          if (_joinError != null) ...[
            const SizedBox(height: 10),
            Text(
              _joinError!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          CartoonPressable(
            soft: true,
            enabled: !_isSubmitting,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitJoinCode,
              style: PartyStyle.button(
                context,
                background: AppColors.sage,
                foreground: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _isJoining = false;
                _joinError = null;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: AppSurfaces.textMuted(context),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
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
        _PartyPass(
          party: party,
          onEditName: _isSubmitting ? null : () => _renameParty(party),
          onCopyCode: () => _copyJoinCode(party.joinCode),
          onInvite: _isSubmitting ? null : () => _showInviteFriends(party),
          onViewMap: () => _openPartyMap(party),
        ),
        const SizedBox(height: 22),
        _sectionLabel('Scoreboard'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _tileCount('A', teamATiles)),
                  const PartyVsBadge(),
                  Expanded(child: _tileCount('B', teamBTiles)),
                ],
              ),
              const SizedBox(height: 14),
              _scoreBar(teamATiles ?? 0, teamBTiles ?? 0),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _sectionLabel('Teams'),
        _teamMembersCard('A', party.teamAMembers, uid),
        const SizedBox(height: 12),
        _teamMembersCard('B', party.teamBMembers, uid),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: _isSubmitting
                ? null
                : () => _leaveParty(partyId: party.id),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
            child: const Text('Leave Party'),
          ),
        ),
      ],
    );
  }

  /// Cream Social-style card with a hairline border and soft shadow.
  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppSurfaces.softCard(context),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppSurfaces.border(context)),
    boxShadow: AppSurfaces.cardShadow(context),
  );

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppSurfaces.isDark(context)
              ? AppColors.lightSage
              : AppColors.sage,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Round tinted icon, matching the Social destination cards.
  Widget _iconCircle(IconData icon, Color colour, {double size = 46}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: colour, size: size * 0.5),
    );
  }

  Widget _tileCount(String team, int? count) {
    final theme = Theme.of(context);
    final teamColor = PartyStyle.team(team);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [teamColor, teamColor.withValues(alpha: 0.82)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: teamColor.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Team $team',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count == null ? '—' : '$count ${count == 1 ? 'tile' : 'tiles'}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// Tug-of-war bar showing each team's share of claimed tiles.
  Widget _scoreBar(int teamA, int teamB) {
    final total = teamA + teamB;
    final share = total == 0 ? 0.5 : teamA / total;
    return Semantics(
      label: total == 0
          ? 'No tiles claimed yet'
          : 'Team A holds ${(share * 100).round()} percent of claimed tiles',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: (share * 1000).round().clamp(1, 999),
                  child: ColoredBox(
                    color: total == 0
                        ? AppSurfaces.progressTrack(context)
                        : AppColors.teamA,
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  flex: ((1 - share) * 1000).round().clamp(1, 999),
                  child: ColoredBox(
                    color: total == 0
                        ? AppSurfaces.progressTrack(context)
                        : AppColors.teamB,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamMembersCard(String team, List<String> members, String? uid) {
    final theme = Theme.of(context);
    final teamColor = PartyStyle.team(team);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _iconCircle(Icons.flag_rounded, teamColor, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Team $team Members',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: teamColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${members.length} ${members.length == 1 ? 'member' : 'members'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: teamColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 50, top: 2, bottom: 2),
              child: Text(
                'No members yet',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppSurfaces.textSubtle(context),
                ),
              ),
            )
          else
            for (final member in members)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const SizedBox(width: 6),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: teamColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 15,
                        color: teamColor,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
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
              ),
        ],
      ),
    );
  }
}

/// The party's "pass": the party name with member dots,
/// a tear-off ticket stub holding the join code as letter tiles, and the
/// invite / map actions.
class _PartyPass extends StatelessWidget {
  const _PartyPass({
    required this.party,
    required this.onEditName,
    required this.onCopyCode,
    required this.onInvite,
    required this.onViewMap,
  });

  final Party party;
  final VoidCallback? onEditName;
  final VoidCallback onCopyCode;
  final VoidCallback? onInvite;
  final VoidCallback onViewMap;

  static const double _radius = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memberCount = party.teamAMembers.length + party.teamBMembers.length;

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.softCard(context),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppSurfaces.border(context)),
        boxShadow: AppSurfaces.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        party.displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppSurfaces.textPrimary(context),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CartoonIconButton(
                      soft: true,
                      outlineWidth: 0,
                      icon: Icons.edit_rounded,
                      tooltip: 'Edit party name',
                      onPressed: onEditName,
                      foreground: AppColors.sage,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MemberDots(
                      teamA: party.teamAMembers.length,
                      teamB: party.teamBMembers.length,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$memberCount ${memberCount == 1 ? 'explorer' : 'explorers'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppSurfaces.textMuted(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const _TicketPerforation(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'JOIN CODE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppSurfaces.textMuted(context),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                _JoinCodeTiles(code: party.joinCode, onTap: onCopyCode),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: OutlinedButton.icon(
                        onPressed: onInvite,
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 18,
                        ),
                        label: const FittedBox(child: Text('Invite Friends')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.clay,
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: const StadiumBorder(),
                          side: BorderSide(
                            color: AppColors.clay.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: CartoonPressable(
                        soft: true,
                        child: ElevatedButton.icon(
                          onPressed: onViewMap,
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: const FittedBox(child: Text('View Map')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sage,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(0, 50),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlapping team-coloured dots, one per member (capped).
class _MemberDots extends StatelessWidget {
  const _MemberDots({required this.teamA, required this.teamB});

  final int teamA;
  final int teamB;

  static const int _maxDots = 6;
  static const double _size = 18;
  static const double _step = 12;

  @override
  Widget build(BuildContext context) {
    final colours = [
      for (var i = 0; i < teamA; i++) AppColors.teamA,
      for (var i = 0; i < teamB; i++) AppColors.teamB,
    ].take(_maxDots).toList();
    if (colours.isEmpty) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: SizedBox(
        width: _size + _step * (colours.length - 1),
        height: _size,
        child: Stack(
          children: [
            for (var i = 0; i < colours.length; i++)
              Positioned(
                left: _step * i,
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    color: colours[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppSurfaces.softCard(context),
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dashed tear line with half-circle notches cut into both card edges.
class _TicketPerforation extends StatelessWidget {
  const _TicketPerforation();

  static const double _notch = 11;

  @override
  Widget build(BuildContext context) {
    final page = AppSurfaces.pageBackground(context);
    return SizedBox(
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _notch + 8),
            child: CustomPaint(
              size: const Size(double.infinity, 2),
              painter: _DashPainter(AppSurfaces.border(context)),
            ),
          ),
          for (final left in [true, false])
            Positioned(
              left: left ? -_notch - 1 : null,
              right: left ? null : -_notch - 1,
              child: Container(
                width: _notch * 2,
                height: _notch * 2,
                decoration: BoxDecoration(
                  color: page,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppSurfaces.border(context)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 6.0;
    const gap = 6.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(min(x + dash, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => colour != oldDelegate.colour;
}

/// The join code spelled out as letter tiles; tapping copies it.
class _JoinCodeTiles extends StatelessWidget {
  const _JoinCodeTiles({required this.code, required this.onTap});

  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppSurfaces.isDark(context);
    final tile = isDark
        ? AppColors.darkElevated
        : Colors.white.withValues(alpha: 0.75);
    return Tooltip(
      message: 'Copy join code',
      child: Semantics(
        button: true,
        label: 'Join code ${code.split('').join(' ')}. Copy',
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('party-join-code-$code'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (final char in code.split('')) ...[
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 38),
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tile,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppSurfaces.border(context)),
                        boxShadow: [
                          BoxShadow(
                            color: AppSurfaces.shadow(context),
                            offset: const Offset(0, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(
                        char,
                        style: TextStyle(
                          color: AppSurfaces.textPrimary(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.copy_rounded,
                  size: 20,
                  color: isDark ? AppColors.lightSage : AppColors.sage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
