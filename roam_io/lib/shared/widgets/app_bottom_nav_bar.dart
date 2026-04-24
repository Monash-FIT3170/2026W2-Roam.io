import 'package:flutter/material.dart';
import '../../theme/app_colours.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const items = [
    _NavItem(Icons.route_outlined, 'JOURNEYS'),
    _NavItem(Icons.explore_outlined, 'QUESTS'),
    _NavItem(Icons.map_outlined, 'MAP'),
    _NavItem(Icons.bar_chart_outlined, 'STATS'),
    _NavItem(Icons.person_outline, 'YOU'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = index == currentIndex;

          if (isSelected) {
            return Transform.translate(
              offset: const Offset(0, -24),
              child: GestureDetector(
                onTap: () => onTap(index),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.cream,
                      width: 4,
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            );
          }

          return GestureDetector(
            onTap: () => onTap(index),
            child: SizedBox(
              width: 58,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    color: AppColors.ink.withOpacity(0.65),
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.ink.withOpacity(0.7),
                        ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem(this.icon, this.label);
}