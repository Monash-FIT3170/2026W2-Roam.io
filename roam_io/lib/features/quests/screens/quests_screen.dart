/*
 * Description:
 *   Displays available side quests, category filters, quest rewards and
 *   the current user's quest progress using the shared Roam.io visual style.
 *
 *   Global quests remain browsable while signed out. Starting and completing
 *   quests still requires an authenticated user.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import 'data/quest.dart';
import 'quest_controller.dart';
import 'quest_details_screen.dart';
import 'quest_enums.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  late final QuestController _questController;

  @override
  void initState() {
    super.initState();

    _questController = QuestController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuests();
    });
  }

  Future<void> _loadQuests() async {
    final userId = context.read<AuthProvider>().currentUser?.uid;

    debugPrint(
      '[QuestsScreen] Loading quests '
      'userId=${userId ?? 'not signed in'}',
    );

    await _questController.initialise(
      userId: userId,
    );
  }

  @override
  void dispose() {
    _questController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<QuestController>.value(
      value: _questController,
      child: const _QuestsContent(),
    );
  }
}

class _QuestsContent extends StatelessWidget {
  const _QuestsContent();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuestController>();

    final bottomClearance =
        AppBottomNavBar.clearanceFromScreenBottom(context) + 16;

    return Container(
      color: AppSurfaces.pageBackground(context),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(
              title: 'Side Quests',
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Discover new experiences, complete challenges and earn XP.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppSurfaces.textMuted(context),
                  height: 1.35,
                ),
              ),
            ),

            _QuestSummary(
              controller: controller,
            ),

            const SizedBox(height: 18),

            _CategoryFilters(
              controller: controller,
            ),

            const SizedBox(height: 14),

            Expanded(
              child: _buildBody(
                context,
                controller,
                bottomClearance,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    QuestController controller,
    double bottomClearance,
  ) {
    if (controller.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (controller.errorMessage != null) {
      return _QuestErrorState(
        message: controller.errorMessage!,
      );
    }

    if (controller.quests.isEmpty) {
      return const _EmptyQuestState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        final userId =
            context.read<AuthProvider>().currentUser?.uid;

        await controller.loadQuests(
          userId: userId,
        );
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          2,
          20,
          bottomClearance,
        ),
        itemCount: controller.quests.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final quest = controller.quests[index];

          return _QuestCard(
            quest: quest,
            isStarted:
                controller.isQuestStarted(quest.id),
            isCompleted:
                controller.isQuestCompleted(quest.id),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ChangeNotifierProvider<
                        QuestController
                      >.value(
                        value: controller,
                        child: QuestDetailsScreen(
                          quest: quest,
                        ),
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _QuestSummary extends StatelessWidget {
  const _QuestSummary({
    required this.controller,
  });

  final QuestController controller;

  @override
  Widget build(BuildContext context) {
    final activeCount = controller.activeQuests.length;
    final completedCount =
        controller.completedQuests.length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              icon: Icons.explore_rounded,
              value: '${controller.quests.length}',
              label: 'Available',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              icon: Icons.flag_rounded,
              value: '$activeCount',
              label: 'Active',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              icon: Icons.check_circle_rounded,
              value: '$completedCount',
              label: 'Completed',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppSurfaces.softCard(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppSurfaces.border(context),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 19,
            color: primary,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color:
                      AppSurfaces.textMuted(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({
    required this.controller,
  });

  final QuestController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
        ),
        children: [
          _CategoryChip(
            label: 'All',
            selected:
                controller.selectedCategory == null,
            onTap: () {
              controller.selectCategory(null);
            },
          ),
          const SizedBox(width: 8),
          ...QuestCategory.values.map(
            (category) => Padding(
              padding:
                  const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                label: category.displayName,
                selected:
                    controller.selectedCategory ==
                    category,
                onTap: () {
                  controller.selectCategory(
                    category,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? primary
                : AppSurfaces.softCard(context),
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? primary
                  : AppSurfaces.border(context),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(
                  color: selected
                      ? Colors.white
                      : AppSurfaces.textPrimary(
                          context,
                        ),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.isStarted,
    required this.isCompleted,
    required this.onTap,
  });

  final Quest quest;
  final bool isStarted;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent =
        _accentForCategory(quest.category);

    return Container(
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppSurfaces.border(context),
        ),
        boxShadow:
            AppSurfaces.cardShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(
                      alpha: AppSurfaces.isDark(
                        context,
                      )
                          ? 0.20
                          : 0.16,
                    ),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _iconForCategory(
                      quest.category,
                    ),
                    color: accent,
                    size: 25,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              quest.title,
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        '${quest.category.displayName} • '
                        '${quest.difficulty.displayName}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color:
                                  AppSurfaces.textMuted(
                                    context,
                                  ),
                              fontWeight:
                                  FontWeight.w600,
                            ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          _QuestMetaBadge(
                            icon: Icons
                                .stars_rounded,
                            label:
                                '+${quest.rewardXp} XP',
                            color:
                                Theme.of(context)
                                    .colorScheme
                                    .primary,
                          ),

                          if (quest
                                  .estimatedMinutes !=
                              null) ...[
                            const SizedBox(width: 8),
                            _QuestMetaBadge(
                              icon: Icons
                                  .schedule_rounded,
                              label:
                                  '${quest.estimatedMinutes} min',
                              color:
                                  AppSurfaces
                                      .textMuted(
                                        context,
                                      ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                _QuestStateIcon(
                  isStarted: isStarted,
                  isCompleted: isCompleted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _accentForCategory(
    QuestCategory category,
  ) {
    return switch (category) {
      QuestCategory.adventure =>
        AppColors.clay,
      QuestCategory.fitness =>
        AppColors.clay,
      QuestCategory.nature =>
        AppColors.sage,
      QuestCategory.culture =>
        AppColors.sage,
      QuestCategory.food =>
        AppColors.clay,
      QuestCategory.social =>
        AppColors.sage,
      QuestCategory.history =>
        AppColors.sage,
      QuestCategory.photography =>
        AppColors.clay,
      QuestCategory.nightlife =>
        AppColors.clay,
      QuestCategory.seasonal =>
        AppColors.sage,
      QuestCategory.hiddenGem =>
        AppColors.clay,
    };
  }

  static IconData _iconForCategory(
    QuestCategory category,
  ) {
    return switch (category) {
      QuestCategory.adventure =>
        Icons.explore_rounded,
      QuestCategory.fitness =>
        Icons.directions_run_rounded,
      QuestCategory.nature =>
        Icons.park_rounded,
      QuestCategory.culture =>
        Icons.museum_rounded,
      QuestCategory.food =>
        Icons.restaurant_rounded,
      QuestCategory.social =>
        Icons.groups_rounded,
      QuestCategory.history =>
        Icons.account_balance_rounded,
      QuestCategory.photography =>
        Icons.photo_camera_rounded,
      QuestCategory.nightlife =>
        Icons.nightlife_rounded,
      QuestCategory.seasonal =>
        Icons.event_rounded,
      QuestCategory.hiddenGem =>
        Icons.diamond_rounded,
    };
  }
}

class _QuestMetaBadge extends StatelessWidget {
  const _QuestMetaBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _QuestStateIcon extends StatelessWidget {
  const _QuestStateIcon({
    required this.isStarted,
    required this.isCompleted,
  });

  final bool isStarted;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return const Icon(
        Icons.check_circle_rounded,
        color: AppColors.sage,
        size: 25,
      );
    }

    if (isStarted) {
      return const Icon(
        Icons.flag_circle_rounded,
        color: AppColors.clay,
        size: 25,
      );
    }

    return Icon(
      Icons.chevron_right_rounded,
      color: AppSurfaces.textSubtle(context),
    );
  }
}

class _EmptyQuestState extends StatelessWidget {
  const _EmptyQuestState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color:
                    AppSurfaces.softCard(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.explore_off_rounded,
                color: AppColors.sage,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No quests available yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'New adventures will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color:
                        AppSurfaces.textMuted(
                          context,
                        ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestErrorState extends StatelessWidget {
  const _QuestErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.clay,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color:
                        AppSurfaces.textMuted(
                          context,
                        ),
                    fontWeight:
                        FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}