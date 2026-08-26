/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 21 August 2026
 * Description:
 *   Provides reusable app page transitions for flows that should feel like
 *   forward navigation rather than modal presentation.
 */

import 'package:flutter/cupertino.dart';

/// Creates an iOS-style horizontal page route for forward app flows.
CupertinoPageRoute<T> appHorizontalPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  return CupertinoPageRoute<T>(settings: settings, builder: builder);
}
