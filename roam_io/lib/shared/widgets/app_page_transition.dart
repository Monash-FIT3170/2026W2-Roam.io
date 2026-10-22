/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 21 August 2026
 * Description:
 *   Provides reusable app page transitions for flows that should feel like
 *   forward navigation rather than modal presentation. Routes cut instead of
 *   sliding when Reduce Motion is on.
 */

import 'package:flutter/cupertino.dart';

import '../../theme/app_accessibility.dart';

/// Creates an iOS-style horizontal page route for forward app flows.
CupertinoPageRoute<T> appHorizontalPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  return _ReducibleCupertinoPageRoute<T>(settings: settings, builder: builder);
}

/// [CupertinoPageRoute] ignores `PageTransitionsTheme`, so it has to honour
/// Reduce Motion itself.
class _ReducibleCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  _ReducibleCupertinoPageRoute({required super.builder, super.settings});

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppAccessibility.reduceMotionOf(context)) return child;
    return super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
