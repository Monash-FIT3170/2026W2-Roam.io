/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Single comment/reply row for the Comments screen with Like and Reply
 *   controls.
 */

import 'package:flutter/material.dart';

import '../../../theme/app_surfaces.dart';
import '../data/comment_like_service.dart';
import '../models/activity_comment.dart';

/// Renders one [ActivityComment] in the comments list.
class CommentListItem extends StatelessWidget {
  const CommentListItem({
    super.key,
    required this.comment,
    this.currentUserId,
    this.likeService,
    this.onReply,
    this.onAuthorTap,
    this.isReply = false,
  });

  final ActivityComment comment;
  final String? currentUserId;
  final CommentLikeService? likeService;
  final VoidCallback? onReply;
  final VoidCallback? onAuthorTap;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final photoUrl = comment.authorPhotoUrl;

    return Padding(
      padding: EdgeInsets.fromLTRB(isReply ? 58 : 20, 10, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onAuthorTap,
            child: Container(
              width: isReply ? 34 : 40,
              height: isReply ? 34 : 40,
              decoration: BoxDecoration(
                color: AppSurfaces.softCard(context),
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary, width: 1.2),
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      )
                    : Icon(
                        Icons.person_rounded,
                        color: colorScheme.primary,
                        size: 22,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onAuthorTap,
                        borderRadius: BorderRadius.circular(6),
                        child: Text(
                          comment.authorDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppSurfaces.textPrimary(context),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimestamp(comment.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppSurfaces.textMuted(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.replyToDisplayName == null
                      ? comment.text
                      : '@${comment.replyToDisplayName} ${comment.text}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppSurfaces.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _CommentLikeButton(
                      comment: comment,
                      currentUserId: currentUserId,
                      likeService: likeService,
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      onTap: onReply,
                      borderRadius: BorderRadius.circular(6),
                      child: Text(
                        'Reply',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppSurfaces.textMuted(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentLikeButton extends StatelessWidget {
  const _CommentLikeButton({
    required this.comment,
    required this.currentUserId,
    required this.likeService,
  });

  final ActivityComment comment;
  final String? currentUserId;
  final CommentLikeService? likeService;

  @override
  Widget build(BuildContext context) {
    final service = likeService;
    final uid = currentUserId;
    if (service == null || uid == null) {
      return Text(
        'Like',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppSurfaces.textMuted(context),
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return StreamBuilder<int>(
      stream: service.watchLikeCount(
        activityId: comment.activityId,
        commentId: comment.id,
      ),
      builder: (context, countSnapshot) {
        final count = countSnapshot.data ?? 0;
        return StreamBuilder<bool>(
          stream: service.watchIsLiked(
            activityId: comment.activityId,
            commentId: comment.id,
            userId: uid,
          ),
          builder: (context, likedSnapshot) {
            final liked = likedSnapshot.data ?? false;
            final label = liked ? 'Liked' : 'Like';
            final text = count > 0 ? '$label · $count' : label;
            final activeColor = Theme.of(context).colorScheme.primary;
            final inactiveColor = AppSurfaces.textMuted(context);
            return InkWell(
              onTap: () {
                service.toggleLike(
                  activityId: comment.activityId,
                  commentId: comment.id,
                  commentAuthorId: comment.authorId,
                  userId: uid,
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (liked) ...[
                    Icon(
                      Icons.thumb_up_alt_rounded,
                      size: 14,
                      color: activeColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    text,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: liked ? activeColor : inactiveColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '$hour:${two(local.minute)} $period';
}
