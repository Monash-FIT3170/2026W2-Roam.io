/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 20 August 2026
 * Description:
 *   Shows a short activity-published celebration after a completed Journey has
 *   been persisted and its social activity has been created successfully.
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colours.dart';

/// Full-screen success confirmation for a published Journey activity.
class ActivitySavedCelebration extends StatefulWidget {
  const ActivitySavedCelebration({
    super.key,
    required this.onDismiss,
    this.xpEarned,
  });

  final VoidCallback onDismiss;
  final int? xpEarned;

  @override
  State<ActivitySavedCelebration> createState() =>
      _ActivitySavedCelebrationState();
}

class _ActivitySavedCelebrationState extends State<ActivitySavedCelebration>
    with TickerProviderStateMixin {
  static const int _particleCount = 18;

  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final AnimationController _particleController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final List<_SavedParticle> _particles;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _particles = List<_SavedParticle>.generate(_particleCount, (index) {
      return _SavedParticle(
        angle: index * (2 * math.pi / _particleCount),
        radiusFactor: 0.22 + (index % 4) * 0.025,
        color: [
          AppColors.sage,
          AppColors.sand,
          AppColors.cream,
          Colors.white,
        ][index % 4],
      );
    });

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 620),
      vsync: this,
    );
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _scaleAnimation = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();
    _particleController.forward();

    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _fadeController.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _particleController]),
      builder: (context, child) {
        return Material(
          type: MaterialType.transparency,
          child: Container(
            color: Colors.black.withValues(alpha: 0.58 * _fadeAnimation.value),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SavedParticlePainter(
                      progress: _particleController.value,
                      particles: _particles,
                    ),
                  ),
                ),
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.sage,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.sage.withValues(alpha: 0.34),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.route_rounded,
                                  size: 56,
                                  color: Colors.white,
                                ),
                                Positioned(
                                  right: 22,
                                  bottom: 24,
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 30,
                                    color: AppColors.cream,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Activity Saved',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (widget.xpEarned != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cream.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                '+${widget.xpEarned} XP',
                                style: const TextStyle(
                                  color: AppColors.sage,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _dismiss,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SavedParticle {
  const _SavedParticle({
    required this.angle,
    required this.radiusFactor,
    required this.color,
  });

  final double angle;
  final double radiusFactor;
  final Color color;
}

class _SavedParticlePainter extends CustomPainter {
  const _SavedParticlePainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<_SavedParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    final center = size.center(Offset.zero);
    final shortestSide = size.shortestSide;

    for (final particle in particles) {
      final offset = Offset(
        math.cos(particle.angle) * shortestSide * particle.radiusFactor * eased,
        math.sin(particle.angle) * shortestSide * particle.radiusFactor * eased,
      );
      final paint = Paint()
        ..color = particle.color.withValues(
          alpha: (1 - progress).clamp(0, 1) * 0.9,
        );
      canvas.drawCircle(center + offset, 4 + (progress * 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SavedParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
