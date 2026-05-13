import 'package:flutter/material.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const items = [
    _NavItem(Icons.route_outlined, Icons.route, 'JOURNEYS'),
    _NavItem(Icons.explore_outlined, Icons.explore, 'QUESTS'),
    _NavItem(Icons.public_outlined, Icons.public, 'MAP'),
    _NavItem(Icons.query_stats_outlined, Icons.query_stats, 'ANALYTICS'),
    _NavItem(Icons.person_outline, Icons.person, 'PROFILE'),
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
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: SizedBox(
        height: 98,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // NAV BAR BACKGROUND
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

            // MAP BUTTON
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
