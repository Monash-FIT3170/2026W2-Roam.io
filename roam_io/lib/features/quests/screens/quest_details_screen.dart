/*
 * Description:
 *   Displays side-quest details and manages starting, photo evidence,
 *   GPS/AI verification, proof storage and user feedback.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import 'data/quest.dart';
import 'quest_controller.dart';
import 'quest_enums.dart';
import 'quest_photo_service.dart';

class QuestDetailsScreen extends StatefulWidget {
  const QuestDetailsScreen({super.key, required this.quest, this.photoService});

  final Quest quest;
  final QuestPhotoService? photoService;

  @override
  State<QuestDetailsScreen> createState() => _QuestDetailsScreenState();
}

class _QuestDetailsScreenState extends State<QuestDetailsScreen> {
  late final QuestPhotoService _photoService;

  QuestPhotoSelection? _selectedPhoto;
  bool _isUploadingProof = false;

  Quest get quest => widget.quest;

  @override
  void initState() {
    super.initState();

    _photoService = widget.photoService ?? QuestPhotoService();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuestController>();

    final progress = controller.progressForQuest(quest.id);

    final busy =
        controller.isStartingQuest ||
        controller.isCompletingQuest ||
        _isUploadingProof;

    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(
        backgroundColor: AppSurfaces.pageBackground(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Side Quest',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _Hero(quest: quest),
            const SizedBox(height: 14),

            _Description(text: quest.description),

            const SizedBox(height: 14),

            _QuestInfo(quest: quest),

            const SizedBox(height: 18),

            if (progress == null)
              _StartButton(
                loading: controller.isStartingQuest,
                onPressed: _startQuest,
              )
            else ...[
              _StatusCard(status: progress.status),

              if (progress.status == QuestStatus.active) ...[
                const SizedBox(height: 12),

                _VerificationInfo(type: quest.verificationType),

                if (quest.requiresPhoto) ...[
                  const SizedBox(height: 12),

                  _PhotoTip(quest: quest),

                  const SizedBox(height: 10),

                  _PhotoCard(
                    photo: _selectedPhoto,
                    disabled: busy,
                    onChoose: _showPhotoOptions,
                    onRemove: () {
                      setState(() {
                        _selectedPhoto = null;
                      });

                      controller.clearMessages();
                    },
                  ),
                ],

                const SizedBox(height: 14),

                _VerifyButton(
                  loading: controller.isCompletingQuest,
                  missingPhoto: quest.requiresPhoto && _selectedPhoto == null,
                  onPressed: _completeQuest,
                ),
              ],
            ],

            if (controller.completionMessage != null) ...[
              const SizedBox(height: 14),
              _MessageCard(
                message: controller.completionMessage!,
                error: controller.lastVerificationPassed == false,
              ),
            ],

            if (controller.errorMessage != null) ...[
              const SizedBox(height: 14),
              _MessageCard(message: controller.errorMessage!, error: true),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startQuest() async {
    final userId = context.read<AuthProvider>().currentUser?.uid;

    if (userId == null) {
      _snack('Log in to start this quest.');
      return;
    }

    final success = await context.read<QuestController>().startQuest(
      userId: userId,
      quest: quest,
    );

    if (!mounted) return;

    if (success) {
      _snack('Quest started!');
    }
  }

  Future<void> _completeQuest() async {
    final userId = context.read<AuthProvider>().currentUser?.uid;

    if (userId == null) {
      _snack('Log in to complete this quest.');
      return;
    }

    if (quest.requiresPhoto && _selectedPhoto == null) {
      _snack('Add a proof photo first.');
      return;
    }

    final controller = context.read<QuestController>();

    final success = await controller.completeQuest(
      userId: userId,
      quest: quest,
      photoBytes: _selectedPhoto?.bytes,
      photoMimeType: _selectedPhoto?.mimeType ?? 'image/jpeg',
    );

    if (!mounted || !success) {
      return;
    }

    // AI/GPS passed. Keep successful proof.
    if (quest.requiresPhoto && _selectedPhoto != null) {
      setState(() {
        _isUploadingProof = true;
      });

      try {
        await _photoService.uploadQuestProof(
          userId: userId,
          questId: quest.id,
          photo: _selectedPhoto!,
        );
      } catch (error) {
        debugPrint(
          '[QuestDetailsScreen] '
          'Proof upload failed after successful verification: $error',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUploadingProof = false;
          });
        }
      }
    }

    if (!mounted) return;

    _snack(
      'Quest completed! '
      '+${quest.rewardXp} XP',
    );
  }

  Future<void> _showPhotoOptions() async {
    final source = await showModalBottomSheet<ImageSourceChoice>(
      context: context,
      backgroundColor: AppSurfaces.card(context),
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add quest proof',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a clear photo showing the quest location or activity.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppSurfaces.textMuted(context),
                  ),
                ),
                const SizedBox(height: 16),

                _SheetOption(
                  icon: Icons.photo_camera_rounded,
                  title: 'Take Photo',
                  onTap: () =>
                      Navigator.pop(sheetContext, ImageSourceChoice.camera),
                ),

                const SizedBox(height: 10),

                _SheetOption(
                  icon: Icons.photo_library_rounded,
                  title: 'Choose from Gallery',
                  onTap: () =>
                      Navigator.pop(sheetContext, ImageSourceChoice.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final photo = source == ImageSourceChoice.camera
          ? await _photoService.takePhoto()
          : await _photoService.chooseFromGallery();

      if (!mounted || photo == null) {
        return;
      }

      setState(() {
        _selectedPhoto = photo;
      });

      context.read<QuestController>().clearMessages();
    } catch (error) {
      debugPrint(
        '[QuestDetailsScreen] '
        'Photo selection failed: $error',
      );

      if (mounted) {
        _snack('Could not access that photo.');
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum ImageSourceChoice { camera, gallery }

class _Hero extends StatelessWidget {
  const _Hero({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppSurfaces.border(context)),
        boxShadow: AppSurfaces.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _categoryIcon(quest.category),
                color: AppColors.sage,
                size: 30,
              ),
              const Spacer(),
              Text(
                quest.difficulty.displayName,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            quest.category.displayName.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(letterSpacing: 1),
          ),

          const SizedBox(height: 6),

          Text(
            quest.title,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 14),

          Text(
            '+${quest.rewardXp} XP',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.sage,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppSurfaces.softCard(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
      ),
    );
  }
}

class _QuestInfo extends StatelessWidget {
  const _QuestInfo({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.stars_rounded,
            label: 'Reward',
            value: '${quest.rewardXp} XP',
          ),
          const Divider(),
          _InfoRow(
            icon: Icons.verified_user_outlined,
            label: 'Verification',
            value: quest.verificationType.displayName,
          ),
          if (quest.estimatedMinutes != null) ...[
            const Divider(),
            _InfoRow(
              icon: Icons.schedule_rounded,
              label: 'Time',
              value: '${quest.estimatedMinutes} min',
            ),
          ],
          if (quest.verificationRadiusMetres != null) ...[
            const Divider(),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Location radius',
              value: '${quest.verificationRadiusMetres!.round()} m',
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.sage),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppSurfaces.textMuted(context)),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _VerificationInfo extends StatelessWidget {
  const _VerificationInfo({required this.type});

  final QuestVerificationType type;

  @override
  Widget build(BuildContext context) {
    final text = switch (type) {
      QuestVerificationType.gps => 'Your current location will be checked.',

      QuestVerificationType.photo => 'Your proof photo will be checked by AI.',

      QuestVerificationType.gpsAndPhoto =>
        'Your location and proof photo must both pass verification.',

      _ => 'This quest uses a specialised verification method.',
    };

    return _SoftNotice(icon: Icons.verified_user_outlined, text: text);
  }
}

class _PhotoTip extends StatelessWidget {
  const _PhotoTip({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final text = switch (quest.category) {
      QuestCategory.fitness =>
        'Include the trail, steps, landmark or surrounding area clearly.',

      QuestCategory.photography =>
        'Keep the landmark or main subject clearly visible.',

      QuestCategory.culture || QuestCategory.history =>
        'Include a recognisable part of the venue or landmark.',

      QuestCategory.nature =>
        'Capture a clear view of the location and surrounding environment.',

      _ => 'Include the landmark or surroundings clearly in the frame.',
    };

    return _SoftNotice(
      icon: Icons.tips_and_updates_outlined,
      title: 'Photo tip',
      text: text,
    );
  }
}

class _SoftNotice extends StatelessWidget {
  const _SoftNotice({required this.icon, required this.text, this.title});

  final IconData icon;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppSurfaces.softCard(context),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.sage, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  text,
                  style: TextStyle(
                    color: AppSurfaces.textMuted(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.disabled,
    required this.onChoose,
    required this.onRemove,
  });

  final QuestPhotoSelection? photo;
  final bool disabled;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(18),
          alignment: Alignment.centerLeft,
        ),
        onPressed: disabled ? null : onChoose,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Add proof photo'),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.memory(
              photo!.bytes,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          ListTile(
            title: const Text('Proof photo ready'),
            subtitle: const Text('This photo will be checked when you verify.'),
            trailing: Wrap(
              children: [
                IconButton(
                  onPressed: disabled ? null : onChoose,
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  onPressed: disabled ? null : onRemove,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final QuestStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      QuestStatus.active => 'Quest in progress',
      QuestStatus.completed => 'Quest completed',
      QuestStatus.submitted => 'Waiting for verification',
      QuestStatus.rejected => 'Verification rejected',
      QuestStatus.expired => 'Quest expired',
      QuestStatus.available => 'Available',
    };

    return _SoftNotice(
      icon: status == QuestStatus.completed
          ? Icons.check_circle_rounded
          : Icons.flag_rounded,
      text: text,
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(backgroundColor: AppColors.sage),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(loading ? 'Starting...' : 'Start Quest'),
      ),
    );
  }
}

class _VerifyButton extends StatelessWidget {
  const _VerifyButton({
    required this.loading,
    required this.missingPhoto,
    required this.onPressed,
  });

  final bool loading;
  final bool missingPhoto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(backgroundColor: AppColors.clay),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                missingPhoto
                    ? Icons.add_a_photo_rounded
                    : Icons.verified_rounded,
              ),
        label: Text(
          loading
              ? 'Verifying...'
              : missingPhoto
              ? 'Add Photo to Verify'
              : 'Verify & Complete',
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.clay : AppColors.sage;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            error
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppSurfaces.softCard(context),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: AppColors.sage),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

IconData _categoryIcon(QuestCategory category) {
  return switch (category) {
    QuestCategory.adventure => Icons.explore_rounded,
    QuestCategory.fitness => Icons.directions_run_rounded,
    QuestCategory.nature => Icons.park_rounded,
    QuestCategory.culture => Icons.museum_rounded,
    QuestCategory.food => Icons.restaurant_rounded,
    QuestCategory.social => Icons.groups_rounded,
    QuestCategory.history => Icons.account_balance_rounded,
    QuestCategory.photography => Icons.photo_camera_rounded,
    QuestCategory.nightlife => Icons.nightlife_rounded,
    QuestCategory.seasonal => Icons.event_rounded,
    QuestCategory.hiddenGem => Icons.diamond_rounded,
  };
}
