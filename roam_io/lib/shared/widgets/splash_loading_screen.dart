import 'package:flutter/material.dart';

class SplashLoadingScreen extends StatelessWidget {
  const SplashLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF4E1),
      body: Center(
        child: Image.asset(
          'assets/logos/roam_io_logo_with_text.png',
          width: 400,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
