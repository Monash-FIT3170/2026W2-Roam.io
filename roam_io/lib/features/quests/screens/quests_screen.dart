/*
 * Description:
 *   Displays available side quests, category filters and the current
 *   user's quest progress. Global quests remain browsable when signed out.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/quest_controller.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';

import '../../auth/providers/auth_provider.dart';
import 'quest_details_screen.dart';

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
    final userId =
        context.read<AuthProvider>().currentUser?.uid;

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
      child: const Scaffold(
        body: _QuestsContent(),
      ),
    );
  }
}

class _QuestsContent extends StatelessWidget {
  const _QuestsContent();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuestController>();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              6,
            ),
            child: Text(
              'Side Quests',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Text(
              'Explore somewhere new and earn XP.',
            ),
          ),
          const SizedBox(height: 16),
          _CategoryFilters(
            controller: controller,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildBody(
              context,
              controller,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    QuestController controller,
  ) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        20,
        4,
        20,
        100,
      ),
      itemCount: controller.quests.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: 12),
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
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
        ),
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected:
                controller.selectedCategory == null,
            onSelected: (_) {
              controller.selectCategory(null);
            },
          ),
          const SizedBox(width: 8),
          ...QuestCategory.values.map(
            (category) => Padding(
              padding: const EdgeInsets.only(
                right: 8,
              ),
              child: ChoiceChip(
                label: Text(
                  category.displayName,
                ),
                selected:
                    controller.selectedCategory ==
                    category,
                onSelected: (_) {
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
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary
                      .withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconForCategory(
                    quest.category,
                  ),
                  color:
                      theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${quest.category.displayName} • '
                      '${quest.difficulty.displayName}',
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '+${quest.rewardXp} XP',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                        color: theme
                            .colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                Icon(
                  Icons.check_circle_rounded,
                  color:
                      theme.colorScheme.primary,
                )
              else if (isStarted)
                const Icon(
                  Icons
                      .play_circle_outline_rounded,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                ),
            ],
          ),
        ),
      ),
    );
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

class _EmptyQuestState extends StatelessWidget {
  const _EmptyQuestState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_off_rounded,
            size: 44,
          ),
          SizedBox(height: 12),
          Text(
            'No quests available yet.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}