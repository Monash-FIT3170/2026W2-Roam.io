/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Transitional compatibility wrapper for the Analytics screen, now surfaced
 *   as the You destination in the main navigation.
 */

import 'package:roam_io/features/you/screens/you_screen.dart';

/// Backwards-compatible alias for code that still imports the old Analytics page.
class AnalyticsScreen extends YouScreen {
  const AnalyticsScreen({
    super.key,
    super.visitService,
    super.visitedRegionService,
  });
}
