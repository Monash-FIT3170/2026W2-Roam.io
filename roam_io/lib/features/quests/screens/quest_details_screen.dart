/*
 * Description:
 *   Displays full quest information and allows the current user to
 *   start and complete quests using the configured verification method.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/quests/screens/data/quest.dart';
import 'package:roam_io/features/quests/screens/quest_controller.dart';
import 'package:roam_io/features/quests/screens/quest_enums.dart';

import '../../auth/providers/auth_provider.dart';


class QuestDetailsScreen extends StatelessWidget {
  const QuestDetailsScreen({
    super.key,
    required this.quest,
  });

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuestController>();
    final progress = controller.progressForQuest(quest.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Side Quest'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _QuestHeader(quest: quest),
            const SizedBox(height: 28),

            Text(
              quest.description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 28),

            _QuestInformationCard(quest: quest),

            const SizedBox(height: 28),

            if (progress == null)
              _StartQuestButton(
                isLoading: controller.isStartingQuest,
                onPressed: () => _startQuest(context),
              )
            else ...[
              _QuestStatusCard(status: progress.status),

              if (progress.status == QuestStatus.active) ...[
                const SizedBox(height: 18),

                _CompleteQuestButton(
                  isLoading: controller.isCompletingQuest,
                  onPressed: () => _completeQuest(context),
                ),
              ],
            ],

            if (controller.completionMessage != null) ...[
              const SizedBox(height: 16),
              _MessageCard(
                message: controller.completionMessage!,
                isError: false,
              ),
            ],

            if (controller.errorMessage != null) ...[
              const SizedBox(height: 16),
              _MessageCard(
                message: controller.errorMessage!,
                isError: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startQuest(BuildContext context) async {
    final userId = context.read<AuthProvider>().currentUser?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log in to start this quest.'),
        ),
      );
      return;
    }

    final controller = context.read<QuestController>();

    final success = await controller.startQuest(
      userId: userId,
      quest: quest,
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quest started!'),
        ),
      );
    }
  }

  Future<void> _completeQuest(BuildContext context) async {
    final userId = context.read<AuthProvider>().currentUser?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log in to complete this quest.'),
        ),
      );
      return;
    }

    final controller = context.read<QuestController>();

    final success = await controller.completeQuest(
      userId: userId,
      quest: quest,
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Quest completed! +${quest.rewardXp} XP',
          ),
        ),
      );
    }
  }
}

class _QuestHeader extends StatelessWidget {
  const _QuestHeader({
    required this.quest,
  });

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          quest.category.displayName.toUpperCase(),
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          quest.title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _SmallBadge(
              icon: Icons.bolt_rounded,
              label: quest.difficulty.displayName,
            ),
            const SizedBox(width: 8),
            _SmallBadge(
              icon: Icons.stars_rounded,
              label: '${quest.rewardXp} XP',
            ),
          ],
        ),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestInformationCard extends StatelessWidget {
  const _QuestInformationCard({
    required this.quest,
  });

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.stars_rounded,
            label: 'Reward',
            value: '${quest.rewardXp} XP',
          ),
          const Divider(),
          _DetailRow(
            icon: Icons.verified_user_outlined,
            label: 'Verification',
            value: quest.verificationType.displayName,
          ),
          if (quest.estimatedMinutes != null) ...[
            const Divider(),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Estimated time',
              value: '${quest.estimatedMinutes} min',
            ),
          ],
          if (quest.verificationRadiusMetres != null) ...[
            const Divider(),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Verification radius',
              value:
                  '${quest.verificationRadiusMetres!.round()} m',
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartQuestButton extends StatelessWidget {
  const _StartQuestButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.play_arrow_rounded),
      label: Text(
        isLoading ? 'Starting...' : 'Start Quest',
      ),
    );
  }
}

class _CompleteQuestButton extends StatelessWidget {
  const _CompleteQuestButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.flag_rounded),
      label: Text(
        isLoading ? 'Verifying...' : 'Verify & Complete',
      ),
    );
  }
}

class _QuestStatusCard extends StatelessWidget {
  const _QuestStatusCard({
    required this.status,
  });

  final QuestStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final label = switch (status) {
      QuestStatus.available => 'Available',
      QuestStatus.active => 'Quest in progress',
      QuestStatus.submitted => 'Waiting for verification',
      QuestStatus.completed => 'Quest completed',
      QuestStatus.rejected => 'Verification rejected',
      QuestStatus.expired => 'Quest expired',
    };

    final icon = switch (status) {
      QuestStatus.available => Icons.flag_outlined,
      QuestStatus.active => Icons.directions_run_rounded,
      QuestStatus.submitted => Icons.hourglass_top_rounded,
      QuestStatus.completed => Icons.check_circle_rounded,
      QuestStatus.rejected => Icons.cancel_rounded,
      QuestStatus.expired => Icons.schedule_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = isError
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;

    final foregroundColor = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}