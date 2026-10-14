/*
 * Author: kpha0032
 * Last Updated: 15 October 2026
 * Description:
 *   Shared spacing values for Social screens so page gutters and gaps between
 *   rows line up with AppPageHeader.
 */

/// Spacing tokens shared by Social screens.
class SocialLayout {
  const SocialLayout._();

  /// Horizontal page gutter; matches AppPageHeader's 20px inset.
  static const double gutter = 20;

  /// Vertical gap between stacked rows and cards.
  static const double rowGap = 12;

  /// Inner padding for list-row cards.
  static const double cardPadding = 14;
}
