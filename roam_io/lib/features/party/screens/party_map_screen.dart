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
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../../map/data/map_controller.dart';
import '../../map/domain/exploration_mode.dart';
import '../../map/widgets/map_render.dart';
import '../data/party_dwell_ping_service.dart';
import '../data/party_service.dart';
import '../data/party_tile_ownership_service.dart';
import '../domain/party.dart';

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
          final userTeam = _party.teamForUser(_currentUid!);
          if (userTeam != null) {
            unawaited(_dwellPingService.flushNow(
              now: now,
              partyId: _party.id,
              uid: _currentUid!,
              team: userTeam,
              tileId: _activeTileId!,
            ));
          }
        }
        _activeTileId = currentTileId;
        _tileEnteredAt = currentTileId != null ? now : null;
        _dwellPingService.updateCurrentTile(currentTileId);
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
      _mapController.initialise(
        userId: _currentUid,
      );
    });
  }

  void _onMapControllerChanged() {
    if (!mounted) return;
    final currentTileId = _mapController.currentRegion?.id;
    if (currentTileId != _activeTileId) {
      final now = DateTime.now();
      if (_activeTileId != null && _currentUid != null) {
        final userTeam = _party.teamForUser(_currentUid!);
        if (userTeam != null) {
          unawaited(_dwellPingService.flushNow(
            now: now,
            partyId: _party.id,
            uid: _currentUid!,
            team: userTeam,
            tileId: _activeTileId!,
          ));
        }
      }
      _activeTileId = currentTileId;
      _tileEnteredAt = currentTileId != null ? now : null;
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
        final sessionSec = _sessionDwellDuration.inSeconds;
        final effectiveTeamA =
            (baseData?.teamADwellSeconds ?? 0) +
            (userTeam == 'A' ? sessionSec : 0);
        final effectiveTeamB =
            (baseData?.teamBDwellSeconds ?? 0) +
            (userTeam == 'B' ? sessionSec : 0);
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
    _partySubscription = widget.partyService.watchParty(_party.id).listen((live) {
      if (!mounted) return;
      if (live == null || (_currentUid != null && !live.isMember(_currentUid!))) {
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
    _ownershipSubscription = _ownershipService
        .watchOwnership(_party.id)
        .listen((ownership) {
          if (!mounted) return;
          _firestoreOwnership = ownership;
          _syncEffectiveOwnership();
        });
  }

  void _watchTileData() {
    _tileDataSubscription = _ownershipService
        .watchTileData(_party.id)
        .listen((data) {
          if (!mounted) return;
          _tilesData = data;
          _syncEffectiveOwnership();
        });
  }

  @override
  void dispose() {
    _secondTimer?.cancel();
    _partySubscription?.cancel();
    _ownershipSubscription?.cancel();
    _tileDataSubscription?.cancel();

    if (_activeTileId != null && _currentUid != null) {
      final userTeam = _party.teamForUser(_currentUid!);
      if (userTeam != null) {
        unawaited(_dwellPingService.flushNow(
          now: DateTime.now(),
          partyId: _party.id,
          uid: _currentUid!,
          team: userTeam,
          tileId: _activeTileId!,
        ));
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
    AppToast.success(context, 'Join code ${_party.joinCode} copied to clipboard!');
  }

  void _showPartyDetailsSheet() {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    final userTeam = uid != null ? _party.teamForUser(uid) : null;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  InkWell(
                    onTap: _copyJoinCode,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _party.joinCode,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (userTeam != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: userTeam == 'A'
                        ? const Color(0xFF0288D1).withValues(alpha: 0.12)
                        : const Color(0xFFE53935).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: userTeam == 'A'
                          ? const Color(0xFF0288D1).withValues(alpha: 0.3)
                          : const Color(0xFFE53935).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'You are on Team $userTeam (${userTeam == 'A' ? 'Blue' : 'Red'})',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: userTeam == 'A'
                          ? const Color(0xFF0288D1)
                          : const Color(0xFFE53935),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Team A (${_party.teamAMembers.length} members):',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _party.teamAMembers.isEmpty
                    ? 'No members yet'
                    : _party.teamAMembers.join(', '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppSurfaces.textMuted(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Team B (${_party.teamBMembers.length} members):',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _party.teamBMembers.isEmpty
                    ? 'No members yet'
                    : _party.teamBMembers.join(', '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppSurfaces.textMuted(context),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _leaveParty();
                  },
                  icon: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
                  label: const Text(
                    'Leave Party',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
    final currentTileData =
        currentTileId != null ? _tilesData[currentTileId] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Party: ${_party.joinCode}'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Copy join code',
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: _copyJoinCode,
          ),
          IconButton(
            tooltip: 'Party info',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showPartyDetailsSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          MapRender(
            initialCenter: _mapController.center,
            polygons: _mapController.polygons,
            markers: _mapController.markers,
            myLocationEnabled: _mapController.myLocationEnabled,
            onMapCreated: _mapController.onMapCreated,
            onCameraIdle: _mapController.onCameraIdle,
            onCameraMove: _mapController.onCameraMove,
            onCameraMoveStarted: _mapController.onCameraMoveStarted,
          ),
          // Top Scoreboard & Team Status Banner
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _PartyScoreboard(
              party: _party,
              teamATileCount: _teamATileCount,
              teamBTileCount: _teamBTileCount,
              userTeam: userTeam,
              onTapDetails: _showPartyDetailsSheet,
            ),
          ),
          // Bottom Tile Claim & Countdown Card
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _CurrentTileCountdownCard(
              userTeam: userTeam,
              currentRegionName: currentRegion?.name,
              currentTileId: currentTileId,
              tileData: currentTileData,
              sessionDwell: _sessionDwellDuration,
            ),
          ),
          // Recenter Button (positioned directly above the bottom card)
          if (_mapController.myLocationEnabled)
            Positioned(
              right: 16,
              bottom: 164,
              child: FloatingActionButton.small(
                heroTag: 'recenter_party_map',
                tooltip: 'Centre on my location',
                onPressed: _mapController.recenterOnUser,
                backgroundColor: AppSurfaces.card(context),
                foregroundColor: AppSurfaces.textPrimary(context),
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
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
    final theme = Theme.of(context);

    return Material(
      color: AppSurfaces.card(context),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTapDetails,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Team A Score
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0288D1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: userTeam == 'A'
                        ? Border.all(color: const Color(0xFF0288D1), width: 1.5)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0288D1),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            userTeam == 'A' ? 'Team A (You)' : 'Team A',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0288D1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$teamATileCount tiles',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0288D1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              // Team B Score
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: userTeam == 'B'
                        ? Border.all(color: const Color(0xFFE53935), width: 1.5)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            userTeam == 'B' ? 'Team B (You)' : 'Team B',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFE53935),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$teamBTileCount tiles',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating bottom card displaying live countdown to claim the tile and time spent.
class _CurrentTileCountdownCard extends StatelessWidget {
  const _CurrentTileCountdownCard({
    required this.userTeam,
    required this.currentRegionName,
    required this.currentTileId,
    required this.tileData,
    required this.sessionDwell,
  });

  final String? userTeam;
  final String? currentRegionName;
  final String? currentTileId;
  final PartyTileData? tileData;
  final Duration sessionDwell;

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

    if (currentTileId == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppSurfaces.card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppSurfaces.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
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
                      fontWeight: FontWeight.w800,
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

    final sessionSeconds = sessionDwell.inSeconds;
    final baseTeamA = tileData?.teamADwellSeconds ?? 0.0;
    final baseTeamB = tileData?.teamBDwellSeconds ?? 0.0;

    final effectiveTeamA = baseTeamA + (userTeam == 'A' ? sessionSeconds : 0);
    final effectiveTeamB = baseTeamB + (userTeam == 'B' ? sessionSeconds : 0);

    final myDwell = userTeam == 'A'
        ? effectiveTeamA
        : (userTeam == 'B' ? effectiveTeamB : sessionSeconds.toDouble());
    final opponentDwell = userTeam == 'A'
        ? effectiveTeamB
        : (userTeam == 'B' ? effectiveTeamA : 0.0);
    final opponentTeam = userTeam == 'A' ? 'B' : 'A';

    final isClaimedByMe = myDwell > claimGateSeconds && myDwell >= opponentDwell;
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
      statusColor = userTeam == 'A'
          ? const Color(0xFF0288D1)
          : const Color(0xFFE53935);
      badgeLabel = 'Claimed by You';
    } else if (isClaimedByOpponent) {
      final target = opponentDwell + 1;
      final remaining = max(0, (target - myDwell).ceil());
      progress = (myDwell / target).clamp(0.0, 1.0);
      countdownText = '${_formatSeconds(remaining)} to overtake';
      statusSubtitle = 'Enemy tile (Team $opponentTeam: ${_formatSeconds(opponentDwell)})';
      statusColor = userTeam == 'A'
          ? const Color(0xFFE53935)
          : const Color(0xFF0288D1);
      badgeLabel = 'Team $opponentTeam Territory';
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Tile name & badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 18,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Countdown Timer & Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isClaimedByMe
                        ? Icons.check_circle_rounded
                        : Icons.timer_outlined,
                    size: 16,
                    color: statusColor,
                  ),
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
              Text(
                statusSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: statusColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 10),
          // Time spent in tile summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppSurfaces.innerCard(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time in tile: ${_formatDuration(sessionDwell)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppSurfaces.textPrimary(context),
                  ),
                ),
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
      ),
    );
  }
}
