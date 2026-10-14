/*
 * Author: kpha0032
 * Last Updated: 15 October 2026
 * Description:
 *   Shared centred status message for empty, error, and signed-out states on
 *   Social screens so they share one text style.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';

/// Centred, muted status text used by Social screens.
class SocialMessage extends StatelessWidget {
  const SocialMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppSurfaces.textMuted(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
