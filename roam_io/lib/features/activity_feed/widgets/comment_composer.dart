/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Bottom comment composer with send enabled only for non-empty trimmed text.
 *   Stays above the keyboard via parent Scaffold resizeToAvoidBottomInset.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';

/// Text field + Send for posting a comment.
class CommentComposer extends StatelessWidget {
  const CommentComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.isSending = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final canSend = enabled && !isSending && value.text.trim().isNotEmpty;

        return SafeArea(
          top: false,
          child: Material(
            color: AppSurfaces.card(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled && !isSending,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (canSend) onSend();
                      },
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        filled: true,
                        fillColor: AppSurfaces.softCard(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppSurfaces.border(context),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppSurfaces.border(context),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: canSend ? onSend : null,
                    child: isSending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          )
                        : const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
