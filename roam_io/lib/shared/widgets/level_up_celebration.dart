import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';

/// A full-screen level-up celebration overlay that appears when a user levels up.
/// This widget handles its own animation and dismissal.
class LevelUpCelebration extends StatefulWidget {
  const LevelUpCelebration({
    super.key,
    required this.newLevel,
    required this.onDismiss,
  });

  final int newLevel;
  final VoidCallback onDismiss;

  @override
  State<LevelUpCelebration> createState() => _LevelUpCelebrationState();
}

class _LevelUpCelebrationState extends State<LevelUpCelebration>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _confettiAnimation;

  @override
  void initState() {
    super.initState();

    // Main fade in/out animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Scale animation for the level number
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Confetti animation
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _confettiAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    _confettiController.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _fadeController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            color: Colors.black.withValues(alpha: 0.7 * _fadeAnimation.value),
            child: SafeArea(
              child: Stack(
                children: [
                  // Confetti background
                  ..._buildConfetti(),

                  // Main content
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Level up icon
                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.sage,
                                      AppColors.sage.withValues(alpha: 0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.sage.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // Level up text
                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Column(
                                children: [
                                  const Text(
                                    'LEVEL UP!',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 4,
                                          offset: Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.sage,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      'Level ${widget.newLevel}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.sage,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 32),

                        AnimatedOpacity(
                          opacity: _fadeAnimation.value,
                          duration: const Duration(milliseconds: 300),
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

                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _dismiss,
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildConfetti() {
    final confetti = <Widget>[];

    // Generate some confetti particles
    for (int i = 0; i < 50; i++) {
      final delay = i * 50; // Stagger the animations
      final startX = (i % 10) * 0.1; // Distribute across width
      final startY = -0.1; // Start above screen

      confetti.add(
        AnimatedBuilder(
          animation: _confettiAnimation,
          builder: (context, child) {
            final progress = (_confettiAnimation.value - delay / 2000).clamp(0.0, 1.0);
            if (progress <= 0) return const SizedBox.shrink();

            final x = startX + progress * 0.8; // Move right
            final y = startY + progress * 1.2; // Fall down
            final rotation = progress * 4 * 3.14159; // Spin

            return Positioned(
              left: x * MediaQuery.of(context).size.width,
              top: y * MediaQuery.of(context).size.height,
              child: Transform.rotate(
                angle: rotation,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: [
                      AppColors.sage,
                      AppColors.sand,
                      AppColors.clay,
                      Colors.white,
                    ][i % 4],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return confetti;
  }
}