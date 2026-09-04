/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Comments page for Home friend and You personal activities. Streams
 *   Firestore comments/replies under activities/{activityId}/comments and
 *   posts via CommentService.
 */

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/comment_service.dart';
import '../data/comment_like_service.dart';
import '../models/activity_comment.dart';
import '../widgets/comment_composer.dart';
import '../widgets/comment_list_item.dart';
import '../../social/screens/other_user_profile_screen.dart';

/// Full-page comments list + composer for one activity.
class CommentsScreen extends StatefulWidget {
  const CommentsScreen({
    super.key,
    required this.activityId,
    required this.activityOwnerId,
    this.commentService,
    this.commentLikeService,
    this.title = 'Comments',
  });

  final String activityId;
  final String activityOwnerId;
  final CommentService? commentService;
  final CommentLikeService? commentLikeService;
  final String title;

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  late final CommentService _commentService;
  late final CommentLikeService? _commentLikeService;
  late final TextEditingController _controller;
  late final Stream<List<ActivityComment>> _commentsStream;
  bool _isSending = false;
  String? _errorMessage;
  ActivityComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _commentService = widget.commentService ?? CommentService();
    _commentLikeService =
        widget.commentLikeService ??
        (Firebase.apps.isNotEmpty ? CommentLikeService() : null);
    _controller = TextEditingController();
    debugPrint(
      '[CommentsScreen] init activityId=${widget.activityId} '
      'activityOwnerId=${widget.activityOwnerId}',
    );
    _commentsStream = _commentService.watchComments(widget.activityId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final profile = auth.currentProfile;
    if (user == null) {
      setState(() => _errorMessage = 'Sign in to leave a comment.');
      AppToast.error(context, 'Sign in to leave a comment.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final replyingTo = _replyingTo;
      if (replyingTo == null) {
        await _commentService.addComment(
          activityId: widget.activityId,
          activityOwnerId: widget.activityOwnerId,
          authorId: user.uid,
          authorDisplayName: profile?.displayName ?? 'Traveller',
          authorUsername: profile?.username,
          authorPhotoUrl: profile?.photoUrl,
          text: text,
        );
      } else {
        await _commentService.replyToComment(
          activityId: widget.activityId,
          activityOwnerId: widget.activityOwnerId,
          parentComment: replyingTo,
          authorId: user.uid,
          authorDisplayName: profile?.displayName ?? 'Traveller',
          authorUsername: profile?.username,
          authorPhotoUrl: profile?.photoUrl,
          text: text,
        );
      }
      if (!mounted) return;
      _controller.clear();
      setState(() => _replyingTo = null);
    } catch (error, stackTrace) {
      debugPrint('Comment submit failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not post comment. Try again.';
      });
      AppToast.error(context, 'Could not post comment. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = context.watch<AuthProvider>().currentUser?.uid;

    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppSurfaces.pageBackground(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(),
        title: Text(
          widget.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: AppSurfaces.textPrimary(context),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ActivityComment>>(
              stream: _commentsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint(
                    '[CommentsScreen] load failed '
                    'activityId=${widget.activityId} error=${snapshot.error}',
                  );
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load comments.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppSurfaces.textMuted(context),
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                final comments = snapshot.data ?? const <ActivityComment>[];
                if (comments.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No comments yet',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppSurfaces.textMuted(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }

                final topLevel = comments
                    .where((comment) => !comment.isReply)
                    .toList(growable: false);
                final repliesByParent = <String, List<ActivityComment>>{};
                for (final reply in comments.where(
                  (comment) => comment.isReply,
                )) {
                  repliesByParent
                      .putIfAbsent(
                        reply.parentCommentId!,
                        () => <ActivityComment>[],
                      )
                      .add(reply);
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  itemCount: topLevel.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: AppSurfaces.border(context)),
                  itemBuilder: (context, index) {
                    final comment = topLevel[index];
                    final replies =
                        repliesByParent[comment.id] ??
                        const <ActivityComment>[];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CommentListItem(
                          comment: comment,
                          currentUserId: currentUserId,
                          likeService: _commentLikeService,
                          onReply: () => setState(() => _replyingTo = comment),
                          onAuthorTap: () => _openProfile(comment.authorId),
                        ),
                        for (final reply in replies)
                          CommentListItem(
                            comment: reply,
                            currentUserId: currentUserId,
                            likeService: _commentLikeService,
                            isReply: true,
                            onReply: () =>
                                setState(() => _replyingTo = comment),
                            onAuthorTap: () => _openProfile(reply.authorId),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_errorMessage != null)
            ColoredBox(
              color: AppSurfaces.card(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          CommentComposer(
            controller: _controller,
            onSend: _submit,
            isSending: _isSending,
            replyingToDisplayName: _replyingTo?.authorDisplayName,
            onCancelReply: _replyingTo == null
                ? null
                : () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  void _openProfile(String uid) {
    if (uid.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OtherUserProfileScreen(selectedUserId: uid),
      ),
    );
  }
}
