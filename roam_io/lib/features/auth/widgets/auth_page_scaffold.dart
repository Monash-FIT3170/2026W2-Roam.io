import 'package:flutter/material.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';

/// A shared scaffold for authentication pages with a custom animated background.
class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footerText,
    this.footerLabel,
    this.onFooterTap,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? footerText;
  final String? footerLabel;
  final VoidCallback? onFooterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedAuthBackground()),
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppSurfaces.softCard(context).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppSurfaces.border(context),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.explore, size: 22, color: AppColors.sage),
                            const SizedBox(width: 10),
                            Text(
                              'Roam.io',
                              style: textTheme.titleMedium?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      title,
                      style: textTheme.headlineLarge?.copyWith(height: 1.1),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppSurfaces.textMuted(context),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      decoration: BoxDecoration(
                        color: AppSurfaces.card(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppSurfaces.border(context)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: child,
                    ),
                    if (footerText != null && footerLabel != null && onFooterTap != null) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          children: [
                            Text(
                              footerText!, 
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppSurfaces.textMuted(context),
                              ),
                            ),
                            GestureDetector(
                              onTap: onFooterTap,
                              child: Text(
                                footerLabel!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.sage,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Background with subtle looping motion and blended color blobs.
class AnimatedAuthBackground extends StatefulWidget {
  const AnimatedAuthBackground({super.key});

  @override
  State<AnimatedAuthBackground> createState() => _AnimatedAuthBackgroundState();
}

class _AnimatedAuthBackgroundState extends State<AnimatedAuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final beginAlignment = Alignment(-0.9 + 1.8 * progress, -1);
        final endAlignment = Alignment(1 - 1.8 * progress, 1);

        return Container(
            decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: beginAlignment,
              end: endAlignment,
              colors: [
                AppColors.sage.withOpacity(0.98),
                AppColors.sand.withOpacity(0.18),
                AppColors.cream.withOpacity(0.92),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80 + 40 * progress,
                left: -80,
                child: _AnimatedBlob(
                  size: 220,
                  color: AppColors.sage.withOpacity(0.18),
                ),
              ),
              Positioned(
                bottom: -70,
                right: -90 + 40 * progress,
                child: _AnimatedBlob(
                  size: 260,
                  color: AppColors.sage.withOpacity(0.14),
                ),
              ),
              Positioned(
                top: 120,
                right: -40 - 30 * progress,
                child: _AnimatedBlob(
                  size: 140,
                  color: AppColors.sand.withOpacity(0.18),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.3, -0.5),
                      radius: 1.1,
                      colors: [
                        AppColors.cream.withOpacity(0.08),
                        AppColors.cream.withOpacity(0.0),
                      ],
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
}

class _AnimatedBlob extends StatelessWidget {
  const _AnimatedBlob({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 70,
            spreadRadius: 14,
          ),
        ],
      ),
    );
  }
}
