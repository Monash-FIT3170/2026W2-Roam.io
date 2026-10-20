/*
 * Author: kpha0032
 * Last Updated: 15 October 2026
 * Description:
 *   Widget tests for shared Social button styles across light and dark themes.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_io/features/social/widgets/social_button_styles.dart';
import 'package:roam_io/theme/app_colours.dart';
import 'package:roam_io/theme/app_theme.dart';

void main() {
  Future<ButtonStyle> secondaryStyleIn(
    WidgetTester tester,
    ThemeData theme, {
    Color? backgroundColor,
  }) async {
    late ButtonStyle style;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            style = SocialButtonStyles.secondary(
              context,
              backgroundColor: backgroundColor,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return style;
  }

  testWidgets('secondary pill keeps the light-mode override fill', (
    tester,
  ) async {
    final style = await secondaryStyleIn(
      tester,
      AppTheme.lightTheme,
      backgroundColor: AppColors.cream,
    );

    expect(style.backgroundColor?.resolve(<WidgetState>{}), AppColors.cream);
  });

  testWidgets('secondary pill uses a dark fill in dark mode for contrast', (
    tester,
  ) async {
    final style = await secondaryStyleIn(
      tester,
      AppTheme.darkTheme,
      backgroundColor: AppColors.cream,
    );

    expect(
      style.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.darkElevated,
    );
    expect(
      style.foregroundColor?.resolve(<WidgetState>{}),
      AppTheme.darkTheme.colorScheme.onSurface,
    );
  });
}
