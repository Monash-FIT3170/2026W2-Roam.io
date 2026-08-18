/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Bottom comment composer with send enabled only for non-empty trimmed text.
 *   Continuous AppSurfaces.card fill extends through the bottom SafeArea so no
 *   page-background strip shows under the tray. Input uses softCard for
 *   contrast. Stays above the keyboard via Scaffold resizeToAvoidBottomInset.
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
    this.replyingToDisplayName,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final bool enabled;
  final String? replyingToDisplayName;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trayColor = AppSurfaces.card(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final canSend = enabled && !isSending && value.text.trim().isNotEmpty;

        return ColoredBox(
          color: trayColor,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (replyingToDisplayName != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Replying to $replyingToDisplayName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppSurfaces.textMuted(context),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cancel reply',
                          visualDensity: VisualDensity.compact,
                          onPressed: onCancelReply,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                            hintText: replyingToDisplayName == null
                                ? 'Write a comment...'
                                : 'Write a reply...',
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
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
