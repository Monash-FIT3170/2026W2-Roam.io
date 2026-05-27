import 'package:flutter/material.dart';

import '../../theme/app_colours.dart';

class SplashLoadingScreen extends StatelessWidget {
  const SplashLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101216) : AppColors.cream,
      body: Center(
        child: Image.asset(
          'assets/logos/roam_io_logo_with_text.png',
          width: 220,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
