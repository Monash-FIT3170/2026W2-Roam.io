/*
 * Description:
 *   Displays full quest information and lets the current user
 *   start an available quest.
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
        title: const Text('Quest'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            quest.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${quest.category.displayName} • '
            '${quest.difficulty.displayName}',
          ),
          const SizedBox(height: 24),
          Text(
            quest.description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          _DetailRow(
            icon: Icons.stars_rounded,
            label: 'Reward',
            value: '${quest.rewardXp} XP',
          ),
          _DetailRow(
            icon: Icons.verified_user_outlined,
            label: 'Verification',
            value: quest.verificationType.displayName,
          ),
          if (quest.estimatedMinutes != null)
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Estimated time',
              value: '${quest.estimatedMinutes} min',
            ),
          const SizedBox(height: 30),
          if (progress == null)
            FilledButton(
              onPressed: controller.isStartingQuest
                  ? null
                  : () => _startQuest(context),
              child: controller.isStartingQuest
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Start Quest'),
            )
          else
            _QuestStatusCard(
              status: progress.status,
            ),
        ],
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

    final success = await context.read<QuestController>().startQuest(
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 22),
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    final text = switch (status) {
      QuestStatus.available => 'Available',
      QuestStatus.active => 'Quest in progress',
      QuestStatus.submitted => 'Waiting for verification',
      QuestStatus.completed => 'Quest completed',
      QuestStatus.rejected => 'Verification rejected',
      QuestStatus.expired => 'Quest expired',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}