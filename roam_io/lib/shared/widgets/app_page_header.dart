/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Provides a reusable page title with optional subtitle and trailing action
 *   header for app screens.
 */

import 'package:flutter/material.dart';
import '../../theme/app_accessibility.dart';
import '../../theme/app_cartoon.dart';
import '../../theme/app_surfaces.dart';

/// Displays consistent screen heading text with an optional trailing widget.
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Padding(
      padding: EdgeInsets.fromLTRB(canPop ? 16 : 20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (canPop) ...[
                // Matches CartoonPageHeader / Leaderboards soft back control.
                CartoonPressable(
                  soft: true,
                  offset: 3,
                  child: Material(
                    color: AppSurfaces.softCard(context),
                    shape: CircleBorder(
                      side: BorderSide(
                        color: AppSurfaces.border(context),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox.square(
                      dimension: AppAccessibility.minTapTarget,
                      child: BackButton(
                        color: AppSurfaces.textPrimary(context),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size.square(
                            AppAccessibility.minTapTarget,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: canPop ? 28 : 30,
                    height: 1.1,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.only(left: canPop ? 12 : 0),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: AppSurfaces.textMuted(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
