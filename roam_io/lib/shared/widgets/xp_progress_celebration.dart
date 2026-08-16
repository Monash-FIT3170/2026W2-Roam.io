/*
 * Author: Alvin Liong
 * Last Modified: 16/08/2026
 * Description:
 *   Full-screen XP celebration: dimmed backdrop, explorer badge + level, and
 *   an animated progress bar that fills across level-ups with a badge spin.
 */

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/profile/domain/pending_xp_celebration.dart';
import '../../features/profile/domain/profile_model.dart';
import '../../features/you/models/explorer_rank.dart';
import '../../theme/app_colours.dart';
import 'app_toast.dart';

/// Dimmed overlay that animates XP progress and explorer badge level-ups.
class XpProgressCelebration extends StatefulWidget {
  const XpProgressCelebration({
    super.key,
    required this.celebration,
    required this.onDismiss,
  });

  final PendingXpCelebration celebration;
  final VoidCallback onDismiss;

  @override
  State<XpProgressCelebration> createState() => _XpProgressCelebrationState();
}

class _XpProgressCelebrationState extends State<XpProgressCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _xpController;
  late final AnimationController _spinController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _xpAnimation;

  late int _displayLevel;
  late String _rankTitle;
  late String _badgeAsset;
  late String _spinFromAsset;
  late String _spinToAsset;
  var _canDismiss = false;
  var _dismissing = false;
  Timer? _autoDismissTimer;
  Timer? _startXpTimer;

  @override
  void initState() {
    super.initState();
    final start = widget.celebration;
    _displayLevel = start.previousLevel;
    final startRank = ExplorerRank.forLevel(_displayLevel);
    _badgeAsset = startRank.assetPath;
    _spinFromAsset = _badgeAsset;
    _spinToAsset = _badgeAsset;
    _rankTitle = startRank.title;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    final levelsCrossed = (start.newLevel - start.previousLevel).clamp(0, 20);
    final xpDuration = Duration(milliseconds: 1100 + (levelsCrossed * 550));
    _xpController = AnimationController(vsync: this, duration: xpDuration);
    _xpAnimation = CurvedAnimation(
      parent: _xpController,
      curve: Curves.easeInOutCubic,
    );

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    _xpController.addListener(_onXpTick);
    _xpController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _canDismiss = true);
        _autoDismissTimer?.cancel();
        _autoDismissTimer = Timer(const Duration(milliseconds: 1600), () {
          if (mounted && _canDismiss && !_dismissing) {
            _dismiss();
          }
        });
      }
    });

    _fadeController.forward();
    _startXpTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) _xpController.forward();
    });
  }

  void _onXpTick() {
    final level = ProfileModel.levelFromXp(_animatedXp.round());
    if (level > _displayLevel && !_spinController.isAnimating) {
      _promoteToLevel(level);
    }
    setState(() {});
  }

  void _promoteToLevel(int level) {
    final nextRank = ExplorerRank.forLevel(level);
    _spinFromAsset = _badgeAsset;
    _spinToAsset = nextRank.assetPath;
    _displayLevel = level;
    _rankTitle = nextRank.title;
    _spinController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _badgeAsset = _spinToAsset;
        _spinController.value = 0;
      });
    });
  }

  double get _animatedXp {
    final start = widget.celebration.previousXp.toDouble();
    final end = widget.celebration.newXp.toDouble();
    return start + (end - start) * _xpAnimation.value;
  }

  String get _visibleBadgeAsset {
    if (_spinController.isAnimating || _spinController.value > 0) {
      return _spinController.value >= 0.5 ? _spinToAsset : _spinFromAsset;
    }
    return _badgeAsset;
  }

  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _autoDismissTimer?.cancel();
    _fadeController.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _startXpTimer?.cancel();
    _xpController.removeListener(_onXpTick);
    _fadeController.dispose();
    _xpController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final xp = _animatedXp;
    final level = _displayLevel;
    final within = _progressWithinLevel(xp, level);
    final label = _progressLabel(xp, level);
    final leveledUp = widget.celebration.didLevelUp;
    final finishedLevelUp =
        leveledUp &&
        _xpController.isCompleted &&
        level >= widget.celebration.newLevel;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _fadeAnimation,
        _xpAnimation,
        _spinController,
      ]),
      builder: (context, _) {
        return Material(
          type: MaterialType.transparency,
          child: Container(
            color: Colors.black.withValues(alpha: 0.72 * _fadeAnimation.value),
            child: Stack(
              children: [
                Center(
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SpinningLevelBadge(
                            level: level,
                            assetPath: _visibleBadgeAsset,
                            spinTurns: _spinController.value,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _rankTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Level $level',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _CelebrationXpBar(progress: within, label: label),
                          if (leveledUp) ...[
                            const SizedBox(height: 18),
                            Text(
                              finishedLevelUp ? 'LEVEL UP!' : 'Leveling up…',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.sage,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          Opacity(
                            opacity: _canDismiss ? 1 : 0.35,
                            child: Text(
                              'Tap to continue',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.celebration.rewardToastMessage != null)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: AppToast.overlayBottom(context),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: AppToastBanner(
                        message: widget.celebration.rewardToastMessage!,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _canDismiss ? _dismiss : null,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static double _progressWithinLevel(double xp, int level) {
    if (level >= ProfileModel.maxLevel) return 1.0;
    final floor = ProfileModel.totalXpToReachLevel(level);
    final need = ProfileModel.xpForLevel(level);
    if (need <= 0) return 1.0;
    return ((xp - floor) / need).clamp(0.0, 1.0);
  }

  static String _progressLabel(double xp, int level) {
    if (level >= ProfileModel.maxLevel) return 'Max level';
    final floor = ProfileModel.totalXpToReachLevel(level);
    final need = ProfileModel.xpForLevel(level);
    final into = (xp - floor).round().clamp(0, need);
    return '$into / $need XP';
  }
}

class _SpinningLevelBadge extends StatelessWidget {
  const _SpinningLevelBadge({
    required this.level,
    required this.assetPath,
    required this.spinTurns,
  });

  final int level;
  final String assetPath;
  final double spinTurns;

  @override
  Widget build(BuildContext context) {
    // Full turn (0→2π) so the badge and level text finish upright.
    final angle = spinTurns * 2 * math.pi;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(angle),
      child: SizedBox(
        width: 168,
        height: 168,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
            ),
            Image.asset(
              assetPath,
              width: 168,
              height: 168,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.sage,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.shield_moon_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                );
              },
            ),
            Text(
              '$level',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                height: 1.0,
                fontSize: level >= 100 ? 36 : 44,
                shadows: const [Shadow(color: Colors.white70, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CelebrationXpBar extends StatelessWidget {
  const _CelebrationXpBar({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    const fill = Color.fromARGB(255, 73, 134, 87);
    const track = Color(0xFF2A2F38);

    return Container(
      height: 22,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: track),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: const ColoredBox(color: fill),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1.0,
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
