/*
 * Description:
 *   Shared frosted "liquid glass" surfaces used by map controls and sheets.
 *   Default tint is sage green so controls keep brand colour while staying
 *   translucent over the map.
 */

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colours.dart';
import '../../theme/app_surfaces.dart';

/// Frosted translucent panel with a soft border and blur.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding,
    this.blurSigma = 22,
    this.opacity,
    this.tint = AppColors.sage,
    this.borderColor,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;

  /// Override fill opacity. Defaults adapt to light/dark for [tint].
  final double? opacity;

  /// Glass fill tint. Pass null for a neutral frosted surface.
  final Color? tint;

  /// Optional border override.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = AppSurfaces.isDark(context);
    final tintColor = tint;
    final Color fill;
    final Color border;

    if (tintColor == null) {
      fill = Colors.white.withValues(alpha: opacity ?? (isDark ? 0.14 : 0.58));
      border =
          borderColor ?? Colors.white.withValues(alpha: isDark ? 0.28 : 0.72);
    } else {
      fill = tintColor.withValues(alpha: opacity ?? (isDark ? 0.72 : 0.82));
      border =
          borderColor ??
          Color.lerp(
            tintColor,
            Colors.white,
            isDark ? 0.35 : 0.45,
          )!.withValues(alpha: 0.85);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: Border.all(color: border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

/// Circular frosted map control (hazard, recenter, Roammate, heatmap, info).
class LiquidGlassIconButton extends StatelessWidget {
  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 48,
    this.iconSize = 22,
    this.iconColor = Colors.white,
    this.tint = AppColors.sage,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor ?? AppSurfaces.textPrimary(context),
            ),
          ),
        ),
      ),
    );

    return LiquidGlass(
      tint: tint,
      borderRadius: BorderRadius.circular(size / 2),
      child: tooltip == null
          ? button
          : Tooltip(message: tooltip!, child: button),
    );
  }
}

/// Bottom-sheet shell with a frosted glass body.
class LiquidGlassSheet extends StatelessWidget {
  const LiquidGlassSheet({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.9,
    this.tint,
  });

  final Widget child;
  final double maxHeightFactor;

  /// Sheet tint. Null keeps a lighter neutral glass better for long forms.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final radius = const BorderRadius.vertical(top: Radius.circular(24));
    final isDark = AppSurfaces.isDark(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
        ),
        child: LiquidGlass(
          tint: tint,
          borderRadius: radius,
          opacity: tint == null
              ? (isDark ? 0.18 : 0.78)
              : (isDark ? 0.78 : 0.88),
          child: child,
        ),
      ),
    );
  }
}
