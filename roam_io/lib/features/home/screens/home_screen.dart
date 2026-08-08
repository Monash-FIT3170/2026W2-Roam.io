/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 6 August 2026
 * Description:
 *   Home destination showing a stub friend activity feed. Friend cards expose
 *   Kudos + live comment count only (Share omitted for privacy). Comment opens
 *   the shared Comments page; stubs are temporary and not a production feed.
 */

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../theme/app_surfaces.dart';
import '../../activity_feed/data/comment_service.dart';
import '../../activity_feed/data/stub_activity_feed_data.dart';
import '../../activity_feed/screens/activity_detail_screen.dart';
import '../../activity_feed/screens/comments_screen.dart';
import '../../activity_feed/widgets/activity_feed_card.dart';

/// Top-level Home tab for the friend activity feed foundation.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.commentService});

  /// Injected for tests; production receives a shared instance from [MainShellScreen].
  final CommentService? commentService;

  @override
  Widget build(BuildContext context) {
    final bottomClearance =
        AppBottomNavBar.clearanceFromScreenBottom(context) + 12;
    final activities = StubActivityFeedData.friendActivities;
    final comments = commentService;

    return Container(
      color: AppSurfaces.pageBackground(context),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(title: 'Home'),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(20, 4, 20, bottomClearance),
                itemCount: activities.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return ActivityFeedCard.fromItem(
                    activity,
                    commentService: comments,
                    showShare: false,
                    onOverflowTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ActivityDetailScreen(activity: activity),
                        ),
                      );
                    },
                    onKudosTap: () {},
                    onCommentTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CommentsScreen(
                            activityId: activity.id,
                            commentService: comments,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
