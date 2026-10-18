/*
 * Author: Sanjevan Rajasegar & Copilot
 * Description:
 *   Dedicated map screen for an active Party Mode party. Displays the Google
 *   Map with territory-claiming team-tile overlays, live score counters,
 *   active tile dwell countdown timer, time spent in current tile, team status,
 *   and party management actions.
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
import '../../map/data/map_controller.dart';
import '../../map/domain/exploration_mode.dart';
import '../../map/widgets/map_render.dart';
import '../data/party_dwell_ping_service.dart';
import '../data/party_service.dart';
import '../data/party_tile_ownership_service.dart';
import '../domain/party.dart';
import '../widgets/confirm_leave_party.dart';
import '../widgets/party_member_name.dart';
import '../widgets/party_style.dart';

/// Full-screen map view for a specific Party Mode party.
class PartyMapScreen extends StatefulWidget {
  const PartyMapScreen({
    super.key,
    required this.party,
    required this.partyService,
    this.partyTileOwnershipService,
    this.dwellPingService,
    this.mapController,
    this.onPartyChanged,
  });

  final Party party;
  final PartyService partyService;
  final PartyTileOwnershipService? partyTileOwnershipService;
  final PartyDwellPingService? dwellPingService;
  final MapController? mapController;
  final ValueChanged<Party?>? onPartyChanged;

  @override
  State<PartyMapScreen> createState() => _PartyMapScreenState();
}

class _PartyMapScreenState extends State<PartyMapScreen> {
  late Party _party;
  late final MapController _mapController;
  late final PartyTileOwnershipService _ownershipService;
  late final PartyDwellPingService _dwellPingService;
  late final bool _ownsController;
  StreamSubscription<Party?>? _partySubscription;
  StreamSubscription<Map<String, String?>>? _ownershipSubscription;
  StreamSubscription<Map<String, PartyTileData>>? _tileDataSubscription;
  Timer? _secondTimer;

  int _teamATileCount = 0;
  int _teamBTileCount = 0;
  Map<String, String?> _firestoreOwnership = <String, String?>{};
  Map<String, PartyTileData> _tilesData = <String, PartyTileData>{};

  DateTime? _tileEnteredAt;
  String? _activeTileId;
  String? _currentUid;
  int _flushedSecondsInCurrentTile = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentUid = context.read<AuthProvider>().currentUser?.uid;
  }

  @override
  void initState() {
    super.initState();
    _party = widget.party;
    _ownershipService =
        widget.partyTileOwnershipService ??
        PartyTileOwnershipService(firestore: widget.partyService.firestore);
    _dwellPingService =
        widget.dwellPingService ??
        PartyDwellPingService(
          pingInterval: const Duration(seconds: 10),
          firestore: widget.partyService.firestore,
        );

    if (widget.mapController != null) {
      _mapController = widget.mapController!;
      _ownsController = false;
    } else {
      _mapController = MapController(
        partyTileOwnershipService: _ownershipService,
      );
      _ownsController = true;
    }

    _mapController.addListener(_onMapControllerChanged);
    _mapController.setMode(ExplorationMode.party);

    _watchParty();
    _watchTileOwnership();
    _watchTileData();

    // Start 1-second ticker for live dwell stopwatch and countdown timer
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final currentTileId = _mapController.currentRegion?.id;
      final now = DateTime.now();

      if (currentTileId != _activeTileId) {
        if (_activeTileId != null && _currentUid != null) {
          final totalSessionSeconds = _sessionDwellDuration.inSeconds;
          final uncommitted =
              totalSessionSeconds - _flushedSecondsInCurrentTile;
          if (uncommitted > 0) {
            unawaited(
              _commitDwell(
                tileId: _activeTileId!,
                addedSeconds: uncommitted.toDouble(),
              ),
            );
          }
        }
        _flushedSecondsInCurrentTile = 0;
        _activeTileId = currentTileId;
        _tileEnteredAt = currentTileId != null ? now : null;
        _dwellPingService.updateCurrentTile(currentTileId);
      } else if (_activeTileId != null && _currentUid != null) {
        // Incrementally commit dwell every 5 seconds while remaining in tile
        final totalSessionSeconds = _sessionDwellDuration.inSeconds;
        final uncommitted = totalSessionSeconds - _flushedSecondsInCurrentTile;
        if (uncommitted >= 5) {
          final toFlush = uncommitted.toDouble();
          _flushedSecondsInCurrentTile += uncommitted;
          unawaited(
            _commitDwell(tileId: _activeTileId!, addedSeconds: toFlush),
          );
        }
      }

      if (currentTileId != null && _currentUid != null) {
        final userTeam = _party.teamForUser(_currentUid!);
        _dwellPingService.configure(
          partyId: _party.id,
          uid: _currentUid!,
          team: userTeam,
        );
        _dwellPingService.setEngaged(true);
        unawaited(_dwellPingService.tick(now));
      }

      _syncEffectiveOwnership();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _currentUid = context.read<AuthProvider>().currentUser?.uid;
      _mapController.initialise(userId: _currentUid);
    });
  }

  void _onMapControllerChanged() {
    if (!mounted) return;
    final currentTileId = _mapController.currentRegion?.id;
    if (currentTileId != _activeTileId) {
      if (_activeTileId != null && _currentUid != null) {
        final totalSessionSeconds = _sessionDwellDuration.inSeconds;
        final uncommitted = totalSessionSeconds - _flushedSecondsInCurrentTile;
        if (uncommitted > 0) {
          unawaited(
            _commitDwell(
              tileId: _activeTileId!,
              addedSeconds: uncommitted.toDouble(),
            ),
          );
        }
      }
      _flushedSecondsInCurrentTile = 0;
      _activeTileId = currentTileId;
      _tileEnteredAt = currentTileId != null ? DateTime.now() : null;
      _dwellPingService.updateCurrentTile(currentTileId);
      _syncEffectiveOwnership();
    } else {
      setState(() {});
    }
  }

  void _syncEffectiveOwnership() {
    final effective = <String, String?>{};
    for (final entry in _tilesData.entries) {
      effective[entry.key] = entry.value.owningTeam;
    }
    for (final entry in _firestoreOwnership.entries) {
      if (entry.value != null) {
        effective[entry.key] = entry.value;
      }
    }

    if (_activeTileId != null && _currentUid != null) {
      final userTeam = _party.teamForUser(_currentUid!);
      if (userTeam != null) {
        final baseData = _tilesData[_activeTileId!];
        final uncommittedSec = max(
          0,
          _sessionDwellDuration.inSeconds - _flushedSecondsInCurrentTile,
        );
        final effectiveTeamA =
            (baseData?.teamADwellSeconds ?? 0) +
            (userTeam == 'A' ? uncommittedSec : 0);
        final effectiveTeamB =
            (baseData?.teamBDwellSeconds ?? 0) +
            (userTeam == 'B' ? uncommittedSec : 0);
        final activeOwner = deriveOwnership({
          'teamADwellSeconds': effectiveTeamA,
          'teamBDwellSeconds': effectiveTeamB,
        });
        effective[_activeTileId!] = activeOwner;
      }
    }

    var teamA = 0;
    var teamB = 0;
    for (final team in effective.values) {
      if (team == 'A') teamA++;
      if (team == 'B') teamB++;
    }

    _mapController.setPartyTileOwnership(effective);

    if (mounted) {
      setState(() {
        _teamATileCount = teamA;
        _teamBTileCount = teamB;
      });
    }
  }

  void _watchParty() {
    _partySubscription = widget.partyService.watchParty(_party.id).listen((
      live,
    ) {
      if (!mounted) return;
      if (live == null ||
          (_currentUid != null && !live.isMember(_currentUid!))) {
        widget.onPartyChanged?.call(null);
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return;
      }
      setState(() => _party = live);
      widget.onPartyChanged?.call(live);
    });
  }

  void _watchTileOwnership() {
    _ownershipSubscription = _ownershipService.watchOwnership(_party.id).listen(
      (ownership) {
        if (!mounted) return;
        _firestoreOwnership = ownership;
        _syncEffectiveOwnership();
      },
    );
  }

  void _watchTileData() {
    _tileDataSubscription = _ownershipService.watchTileData(_party.id).listen((
      data,
    ) {
      if (!mounted) return;
      _tilesData = data;
      _syncEffectiveOwnership();
    });
  }

  Future<void> _commitDwell({
    required String tileId,
    required double addedSeconds,
    bool updateUi = true,
  }) async {
    if (addedSeconds <= 0) return;
    final uid = _currentUid;
    if (uid == null) return;
    final userTeam = _party.teamForUser(uid);
    if (userTeam == null) return;

    final now = DateTime.now();
    final prevData = _tilesData[tileId];
    final updatedA =
        (prevData?.teamADwellSeconds ?? 0) +
        (userTeam == 'A' ? addedSeconds : 0);
    final updatedB =
        (prevData?.teamBDwellSeconds ?? 0) +
        (userTeam == 'B' ? addedSeconds : 0);
    _tilesData[tileId] = PartyTileData(
      tileId: tileId,
      teamADwellSeconds: updatedA,
      teamBDwellSeconds: updatedB,
    );
    _firestoreOwnership[tileId] = deriveOwnership({
      'teamADwellSeconds': updatedA,
      'teamBDwellSeconds': updatedB,
    });
    if (updateUi) _syncEffectiveOwnership();

    await _dwellPingService.flushNow(
      now: now,
      partyId: _party.id,
      uid: uid,
      team: userTeam,
      tileId: tileId,
      addedDwellSeconds: addedSeconds,
    );
  }

  @override
  void dispose() {
    _secondTimer?.cancel();
    _partySubscription?.cancel();
    _ownershipSubscription?.cancel();
    _tileDataSubscription?.cancel();

    if (_activeTileId != null && _currentUid != null) {
      final totalSessionSeconds = _sessionDwellDuration.inSeconds;
      final uncommitted = totalSessionSeconds - _flushedSecondsInCurrentTile;
      if (uncommitted > 0) {
        unawaited(
          _commitDwell(
            tileId: _activeTileId!,
            addedSeconds: uncommitted.toDouble(),
            updateUi: false,
          ),
        );
      }
    }

    _dwellPingService.setEngaged(false);
    _mapController.removeListener(_onMapControllerChanged);
    if (_ownsController) {
      _mapController.dispose();
    }
    super.dispose();
  }

  Future<void> _leaveParty() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    try {
      unawaited(_partySubscription?.cancel());
      _partySubscription = null;
      await widget.partyService.leaveParty(partyId: _party.id, uid: uid);
      widget.onPartyChanged?.call(null);
      if (!mounted) return;
      AppToast.show(context, 'You left party ${_party.joinCode}');
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not leave party. Please try again.');
      }
    }
  }

  void _copyJoinCode() {
    Clipboard.setData(ClipboardData(text: _party.joinCode));
    AppToast.success(
      context,
      'Join code ${_party.joinCode} copied to clipboard!',
    );
  }

  Widget _memberRoster(List<String> members, String? currentUid) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppSurfaces.textMuted(context));
    if (members.isEmpty) return Text('No members yet', style: style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final member in members)
          PartyMemberName(
            uid: member,
            currentUserId: currentUid,
            firestore: widget.partyService.firestore,
            style: style,
          ),
      ],
    );
  }

  void _showPartyDetailsSheet() {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    final userTeam = uid != null ? _party.teamForUser(uid) : null;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppSurfaces.pageBackground(context),
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Party Details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  CartoonPressable(
                    soft: true,
                    offset: 3,
                    child: Material(
                      color: AppColors.sand,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: PartyStyle.outline(sheetContext),
                          width: PartyStyle.outlineWidth,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _copyJoinCode,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: AppColors.ink,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _party.joinCode,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (userTeam != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: PartyStyle.card(
                    sheetContext,
                    color: PartyStyle.team(userTeam),
                    radius: 18,
                    offset: 3,
                  ),
                  child: Text(
                    'You are on Team $userTeam '
                    '(${PartyStyle.teamColourName(userTeam)})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Team A (${_party.teamAMembers.length} members):',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.teamA,
                ),
              ),
              const SizedBox(height: 4),
              _memberRoster(_party.teamAMembers, uid),
              const SizedBox(height: 12),
              Text(
                'Team B (${_party.teamBMembers.length} members):',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.teamB,
                ),
              ),
              const SizedBox(height: 4),
              _memberRoster(_party.teamBMembers, uid),
              const SizedBox(height: 24),
              CartoonPressable(
                soft: true,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (!await confirmLeaveParty(sheetContext) ||
                        !sheetContext.mounted ||
                        !mounted) {
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                    await _leaveParty();
                  },
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: const Text('Leave Party'),
                  style:
                      PartyStyle.button(
                        sheetContext,
                        background: AppSurfaces.softCard(sheetContext),
                        foreground: theme.colorScheme.error,
                        height: 50,
                      ).copyWith(
                        minimumSize: const WidgetStatePropertyAll(
                          Size.fromHeight(50),
                        ),
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Duration get _sessionDwellDuration {
    if (_tileEnteredAt == null) return Duration.zero;
    final diff = DateTime.now().difference(_tileEnteredAt!);
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.uid;
    final userTeam = uid != null ? _party.teamForUser(uid) : null;
    final currentRegion = _mapController.currentRegion;
    final currentTileId = currentRegion?.id;
    final currentTileData = currentTileId != null
        ? _tilesData[currentTileId]
        : null;

    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CartoonPageHeader(
              soft: true,
              outlineWidth: PartyStyle.outlineWidth,
              title: _party.displayName,
              actions: [
                CartoonIconButton(
                  soft: true,
                  outlineWidth: PartyStyle.outlineWidth,
                  tooltip: 'Copy join code',
                  icon: Icons.copy_rounded,
                  onPressed: _copyJoinCode,
                ),
                CartoonIconButton(
                  soft: true,
                  outlineWidth: PartyStyle.outlineWidth,
                  tooltip: 'Party info',
                  icon: Icons.info_outline_rounded,
                  onPressed: _showPartyDetailsSheet,
                ),
              ],
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: PartyStyle.card(context, radius: 28),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    28 - PartyStyle.outlineWidth,
                  ),
                  child: Stack(
                    children: [
                      MapRender(
                        initialCenter: _mapController.center,
                        polygons: _mapController.polygons,
                        markers: const {},
                        polylines: const {},
                        myLocationEnabled: _mapController.myLocationEnabled,
                        onMapCreated: _mapController.onMapCreated,
                        onCameraIdle: _mapController.onCameraIdle,
                        onCameraMove: _mapController.onCameraMove,
                        onCameraMoveStarted: _mapController.onCameraMoveStarted,
                      ),
                      // Top Scoreboard & Team Status Banner
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: _PartyScoreboard(
                          party: _party,
                          teamATileCount: _teamATileCount,
                          teamBTileCount: _teamBTileCount,
                          userTeam: userTeam,
                          onTapDetails: _showPartyDetailsSheet,
                        ),
                      ),
                      // Bottom tile summary, expandable details, and recenter
                      // control.
                      Positioned(
                        bottom: 16,
                        left: 12,
                        right: 12,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_mapController.myLocationEnabled) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: CartoonIconButton(
                                  soft: true,
                                  outlineWidth: PartyStyle.outlineWidth,
                                  tooltip: 'Centre on my location',
                                  icon: Icons.my_location,
                                  onPressed: _mapController.recenterOnUser,
                                  background: AppSurfaces.softCard(context),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _CurrentTileCountdownCard(
                              userTeam: userTeam,
                              currentRegionName: currentRegion?.name,
                              currentTileId: currentTileId,
                              tileData: currentTileData,
                              sessionDwell: _sessionDwellDuration,
                              flushedSeconds: _flushedSecondsInCurrentTile,
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _PartyScoreboard extends StatelessWidget {
  const _PartyScoreboard({
    required this.party,
    required this.teamATileCount,
    required this.teamBTileCount,
    required this.userTeam,
    required this.onTapDetails,
  });

  final Party party;
  final int teamATileCount;
  final int teamBTileCount;
  final String? userTeam;
  final VoidCallback onTapDetails;

  @override
  Widget build(BuildContext context) {
    return CartoonPressable(
      soft: true,
      borderRadius: BorderRadius.circular(20),
      offset: 4,
      child: Material(
        color: AppSurfaces.softCard(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: PartyStyle.outline(context),
            width: PartyStyle.outlineWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTapDetails,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: _teamScore(context, 'A', teamATileCount)),
                const PartyVsBadge(),
                Expanded(child: _teamScore(context, 'B', teamBTileCount)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamScore(BuildContext context, String team, int tiles) {
    final theme = Theme.of(context);
    final isMine = userTeam == team;
    final color = PartyStyle.team(team);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMine ? color : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMine
              ? PartyStyle.outline(context)
              : color.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            isMine ? 'Team $team (You)' : 'Team $team',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isMine ? Colors.white : color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '$tiles tiles',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isMine ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact tile summary with expandable claim and dwell details.
class _CurrentTileCountdownCard extends StatefulWidget {
  const _CurrentTileCountdownCard({
    required this.userTeam,
    required this.currentRegionName,
    required this.currentTileId,
    required this.tileData,
    required this.sessionDwell,
    this.flushedSeconds = 0,
  });

  final String? userTeam;
  final String? currentRegionName;
  final String? currentTileId;
  final PartyTileData? tileData;
  final Duration sessionDwell;
  final int flushedSeconds;

  @override
  State<_CurrentTileCountdownCard> createState() =>
      _CurrentTileCountdownCardState();
}

class _CurrentTileCountdownCardState extends State<_CurrentTileCountdownCard> {
  bool _showDetails = false;

  @override
  void didUpdateWidget(_CurrentTileCountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTileId != widget.currentTileId) {
      _showDetails = false;
    }
  }

  static String _formatDuration(Duration duration) {
    final totalSec = max(0, duration.inSeconds);
    final minutes = totalSec ~/ 60;
    final seconds = totalSec % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String _formatSeconds(num seconds) {
    return _formatDuration(Duration(seconds: seconds.toInt()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userTeam = widget.userTeam;
    final currentRegionName = widget.currentRegionName;
    final currentTileId = widget.currentTileId;
    final tileData = widget.tileData;
    final sessionDwell = widget.sessionDwell;
    final flushedSeconds = widget.flushedSeconds;

    if (currentTileId == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: PartyStyle.card(context, radius: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: PartyStyle.outline(context),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.radar_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Locating Tile...',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Move into an exploration zone to claim territory',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppSurfaces.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final uncommittedSec = max(0, sessionDwell.inSeconds - flushedSeconds);
    final baseTeamA = tileData?.teamADwellSeconds ?? 0.0;
    final baseTeamB = tileData?.teamBDwellSeconds ?? 0.0;

    final effectiveTeamA = baseTeamA + (userTeam == 'A' ? uncommittedSec : 0);
    final effectiveTeamB = baseTeamB + (userTeam == 'B' ? uncommittedSec : 0);

    final myDwell = userTeam == 'A'
        ? effectiveTeamA
        : (userTeam == 'B'
              ? effectiveTeamB
              : sessionDwell.inSeconds.toDouble());
    final opponentDwell = userTeam == 'A'
        ? effectiveTeamB
        : (userTeam == 'B' ? effectiveTeamA : 0.0);
    final opponentTeam = userTeam == 'A' ? 'B' : 'A';

    final isClaimedByMe =
        myDwell > claimGateSeconds && myDwell >= opponentDwell;
    final isClaimedByOpponent =
        opponentDwell > claimGateSeconds && opponentDwell > myDwell;

    // Determine countdown and progress
    final double progress;
    final String countdownText;
    final String statusSubtitle;
    final Color statusColor;
    final String badgeLabel;

    if (isClaimedByMe) {
      progress = 1.0;
      final leadSec = (myDwell - opponentDwell).toInt();
      countdownText = 'Tile Claimed!';
      statusSubtitle = 'Lead: +${_formatSeconds(leadSec)} · Defending tile';
      statusColor = PartyStyle.team(userTeam);
      badgeLabel = 'Claimed by You';
    } else if (isClaimedByOpponent) {
      final target = opponentDwell + 1;
      final remaining = max(0, (target - myDwell).ceil());
      progress = (myDwell / target).clamp(0.0, 1.0);
      countdownText = '${_formatSeconds(remaining)} to overtake';
      statusSubtitle =
          'Enemy tile (Team $opponentTeam: ${_formatSeconds(opponentDwell)})';
      statusColor = PartyStyle.team(opponentTeam);
      badgeLabel = 'Claimed by Team $opponentTeam';
    } else {
      final target = max(claimGateSeconds.toDouble(), opponentDwell);
      final remaining = max(0, (target - myDwell).ceil());
      progress = (myDwell / target).clamp(0.0, 1.0);
      countdownText = '${_formatSeconds(remaining)} to claim';
      statusSubtitle =
          'Stay in tile to reach ${_formatSeconds(claimGateSeconds)} claim gate';
      statusColor = theme.colorScheme.primary;
      badgeLabel = 'Unclaimed Tile';
    }

    final displayName = currentRegionName?.isNotEmpty == true
        ? currentRegionName!
        : 'Tile #$currentTileId';

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: PartyStyle.card(context, radius: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Let the full tile name wrap before showing claim details.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.flag_rounded, size: 18, color: statusColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: PartyStyle.outline(context),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    badgeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!isClaimedByMe)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        countdownText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (_showDetails) ...[
              const SizedBox(height: 12),
              if (isClaimedByMe)
                Text(
                  countdownText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              Text(
                statusSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppSurfaces.textMuted(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: PartyStyle.outline(context),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: statusColor.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppSurfaces.innerCard(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppSurfaces.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time in tile: ${_formatDuration(sessionDwell)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppSurfaces.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Team A: ${_formatSeconds(effectiveTeamA)} · Team B: ${_formatSeconds(effectiveTeamB)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppSurfaces.textMuted(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => setState(() => _showDetails = !_showDetails),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_showDetails ? 'Show less' : 'Show more'),
                    const SizedBox(width: 4),
                    Icon(
                      _showDetails
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
