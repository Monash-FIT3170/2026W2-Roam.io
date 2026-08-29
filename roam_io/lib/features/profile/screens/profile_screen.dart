/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 5 August 2026
 * Description:
 *   Transitional compatibility wrapper for the Profile screen, now surfaced
 *   as the Settings destination in the main navigation.
 */

import 'package:roam_io/features/settings/screens/settings_screen.dart';

/// Backwards-compatible alias for code that still imports the old Profile page.
class ProfileScreen extends SettingsScreen {
  const ProfileScreen({super.key});
}
