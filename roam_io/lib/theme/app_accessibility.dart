/*
 * Description:
 *   Shared accessibility helpers: the high-contrast theme marker, the
 *   Larger Text scaler, the Reduce Motion check, and the minimum tap target.
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colours.dart';

/// Present on a [ThemeData] only when a high-contrast theme is active.
class HighContrastExtension extends ThemeExtension<HighContrastExtension> {
  const HighContrastExtension();

  @override
  HighContrastExtension copyWith() => this;

  @override
  HighContrastExtension lerp(HighContrastExtension? other, double t) => this;
}

/// Accessibility constants and helpers used across the app.
class AppAccessibility {
  /// Extra scale applied on top of the system text scale by Larger Text.
  static const double largerTextFactor = 1.2;

  /// Upper bound on the effective scale so layouts stay usable.
  static const double maxTextScale = 2.0;

  /// Minimum interactive size (Material and iOS guideline).
  static const double minTapTarget = 48;

  /// Page transitions that swap routes instantly on every platform.
  static const PageTransitionsTheme noTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _NoTransitionsBuilder(),
      TargetPlatform.iOS: _NoTransitionsBuilder(),
      TargetPlatform.macOS: _NoTransitionsBuilder(),
      TargetPlatform.windows: _NoTransitionsBuilder(),
      TargetPlatform.linux: _NoTransitionsBuilder(),
      TargetPlatform.fuchsia: _NoTransitionsBuilder(),
    },
  );

  /// Applies Larger Text and Reduce Motion to the app's content. Call from
  /// `MaterialApp.builder`, where the theme and media query are available.
  static Widget wrap(
    BuildContext context,
    Widget? child, {
    required bool largerText,
    double textScale = largerTextFactor,
  }) {
    Widget content = child ?? const SizedBox.shrink();
    if (context.reduceMotion) {
      // Route changes cut instead of sliding or fading.
      content = Theme(
        data: Theme.of(context).copyWith(pageTransitionsTheme: noTransitions),
        child: content,
      );
    }
    if (largerText) {
      final mediaQuery = MediaQuery.of(context);
      content = MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: AppAccessibility.largerText(
            mediaQuery.textScaler,
            factor: textScale,
          ),
        ),
        child: content,
      );
    }
    return content;
  }

  /// Whether the platform asks for reduced motion (iOS or Android). Rebuilds
  /// the caller when the setting changes, via the [MediaQuery] dependency.
  static bool reduceMotionOf(BuildContext context) {
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disabled) return true;
    final view = View.maybeOf(context);
    return view?.platformDispatcher.accessibilityFeatures.reduceMotion ?? false;
  }

  /// Returns [base] boosted for Larger Text, still bounded by [maxTextScale].
  static TextScaler largerText(
    TextScaler base, {
    double factor = largerTextFactor,
  }) => _LargerTextScaler(base, factor);
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Multiplies a system [TextScaler] without discarding its behaviour.
class _LargerTextScaler extends TextScaler {
  const _LargerTextScaler(this._base, this._factor);

  final TextScaler _base;
  final double _factor;

  @override
  double scale(double fontSize) {
    final system = _base.scale(fontSize);
    final boosted = system * _factor;
    // The cap never pulls text below what the system scale already asked for.
    return math.max(
      system,
      math.min(boosted, fontSize * AppAccessibility.maxTextScale),
    );
  }

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is _LargerTextScaler &&
      other._base == _base &&
      other._factor == _factor;

  @override
  int get hashCode => Object.hash(_LargerTextScaler, _base, _factor);
}

extension AccessibilityContext on BuildContext {
  /// True when the device asks for non-essential motion to be minimised.
  ///
  /// iOS reports Reduce Motion through `reduceMotion`, not the
  /// `disableAnimations` flag behind [MediaQueryData.disableAnimations], which
  /// only Android's "Remove animations" sets. Both are checked.
  bool get reduceMotion => AppAccessibility.reduceMotionOf(this);

  /// [normal], or [Duration.zero] when Reduce Motion is on.
  Duration motionDuration(Duration normal) =>
      reduceMotion ? Duration.zero : normal;

  /// Sage for text and icons: unchanged normally, the AA primary in high
  /// contrast. Use for foreground colour only, never for fills.
  Color get sageForeground =>
      highContrast ? Theme.of(this).colorScheme.primary : AppColors.sage;

  /// Clay for text and icons: unchanged normally, the AA secondary in high
  /// contrast. Use for foreground colour only, never for fills.
  Color get clayForeground =>
      highContrast ? Theme.of(this).colorScheme.secondary : AppColors.clay;

  /// Light sage for text and icons on dark surfaces; same high-contrast rule.
  Color get lightSageForeground =>
      highContrast ? Theme.of(this).colorScheme.primary : AppColors.lightSage;

  /// True when a high-contrast theme is active.
  bool get highContrast =>
      Theme.of(this).extension<HighContrastExtension>() != null;
}

extension ReduceMotionController on AnimationController {
  /// Loops the animation, or parks it at [restAt] when [reduce] is true.
  /// Safe to call repeatedly from `didChangeDependencies`.
  void loopUnlessReduced({
    required bool reduce,
    bool reverse = true,
    double restAt = 1.0,
  }) {
    if (reduce) {
      if (isAnimating) stop();
      value = restAt;
    } else if (!isAnimating) {
      repeat(reverse: reverse);
    }
  }
}
