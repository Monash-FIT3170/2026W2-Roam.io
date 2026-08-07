/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Provides the reusable Home, Social, Map, You, and Settings bottom
 *   navigation bar used by the main app shell.
 */

import 'package:flutter/material.dart';

/// Renders the app's five-tab bottom navigation with a raised center map tab.
class AppBottomNavBar extends StatelessWidget {
  /// Height of the bar content inside the shell nav [SafeArea].
  static const double barHeight = 98;

  /// Bottom inset applied by the shell nav [SafeArea] (see [build]).
  static const double outerBottomMinimum = 8;

  /// Distance from the physical screen bottom to the top of the nav chrome.
  static double clearanceFromScreenBottom(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).bottom +
        outerBottomMinimum +
        barHeight;
  }

  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const items = [
    _NavItem(Icons.home_outlined, Icons.home, 'HOME'),
    _NavItem(Icons.groups_2_outlined, Icons.groups_2, 'SOCIAL'),
    _NavItem(Icons.public_outlined, Icons.public, 'MAP'),
    _NavItem(Icons.person_outline, Icons.person, 'YOU'),
    _NavItem(Icons.settings_outlined, Icons.settings, 'SETTINGS'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final navTheme = theme.bottomNavigationBarTheme;
    final backgroundColor = navTheme.backgroundColor ?? colorScheme.surface;
    final selectedColor = navTheme.selectedItemColor ?? colorScheme.primary;
    final unselectedColor =
        navTheme.unselectedItemColor ??
        colorScheme.onSurface.withValues(alpha: 0.62);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, outerBottomMinimum),
      child: SizedBox(
        height: barHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // The center map tab is rendered separately so it can float above.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 74,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isMap = index == 2;
                    final isSelected = index == currentIndex;

                    if (isMap) {
                      return const Expanded(child: SizedBox());
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(index),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: isSelected ? 1.14 : 1.0,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              child: Icon(
                                isSelected
                                    ? item.filledIcon
                                    : item.outlinedIcon,
                                size: 25,
                                color: isSelected
                                    ? selectedColor
                                    : unselectedColor,
                              ),
                            ),
                            const SizedBox(height: 5),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                letterSpacing: 0.45,
                                color: isSelected
                                    ? selectedColor
                                    : unselectedColor,
                              ),
                              child: Text(item.label),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // The map button is visually emphasized as the primary navigation action.
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: () => onTap(2),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      width: 66,
                      height: 66.5,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: currentIndex == 2
                              ? selectedColor
                              : backgroundColor,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        currentIndex == 2
                            ? Icons.public
                            : Icons.public_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MAP',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 9,
                        fontWeight: currentIndex == 2
                            ? FontWeight.w800
                            : FontWeight.w700,
                        letterSpacing: 0.5,
                        color: currentIndex == 2
                            ? selectedColor
                            : unselectedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData outlinedIcon;
  final IconData filledIcon;
  final String label;

  const _NavItem(this.outlinedIcon, this.filledIcon, this.label);
}
