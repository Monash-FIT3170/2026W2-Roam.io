/*
 * Author: kpha0032
 * Last Updated: 15 October 2026
 * Description:
 *   Shared spacing values for Social screens so page gutters and gaps between
 *   rows line up with AppPageHeader, plus a max-width wrapper that keeps
 *   Social content readable on tablets and wide windows.
 */

import 'package:flutter/widgets.dart';

/// Spacing tokens shared by Social screens.
class SocialLayout {
  const SocialLayout._();

  /// Horizontal page gutter; matches AppPageHeader's 20px inset.
  static const double gutter = 20;

  /// Vertical gap between stacked rows and cards.
  static const double rowGap = 12;

  /// Inner padding for list-row cards.
  static const double cardPadding = 14;

  /// Widest a Social column grows before centring on large screens.
  static const double maxContentWidth = 640;
}

/// Centres [child] and caps its width at [SocialLayout.maxContentWidth].
///
/// Phones are narrower than the cap, so their layout is unchanged.
class SocialContentWidth extends StatelessWidget {
  const SocialContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: SocialLayout.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}
