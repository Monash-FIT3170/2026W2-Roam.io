/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Comments page for Home friend and You personal activities. Streams
 *   Firestore comments under activities/{activityId}/comments and posts via
 *   CommentService. Notifications for new comments are deferred.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/comment_service.dart';
import '../models/activity_comment.dart';
import '../widgets/comment_composer.dart';
import '../widgets/comment_list_item.dart';

/// Full-page comments list + composer for one activity.
class CommentsScreen extends StatefulWidget {
  const CommentsScreen({
    super.key,
    required this.activityId,
    this.commentService,
    this.title = 'Comments',
  });

  final String activityId;
  final CommentService? commentService;
  final String title;

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  late final CommentService _commentService;
  late final TextEditingController _controller;
  late final Stream<List<ActivityComment>> _commentsStream;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _commentService = widget.commentService ?? CommentService();
    _controller = TextEditingController();
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
      await _commentService.addComment(
        activityId: widget.activityId,
        authorId: user.uid,
        authorDisplayName: profile?.displayName ?? 'Traveller',
        authorUsername: profile?.username,
        authorPhotoUrl: profile?.photoUrl,
        text: text,
      );
      if (!mounted) return;
      _controller.clear();
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

                return ListView.separated(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  itemCount: comments.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: AppSurfaces.border(context)),
                  itemBuilder: (context, index) {
                    return CommentListItem(comment: comments[index]);
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
          ),
        ],
      ),
    );
  }
}
