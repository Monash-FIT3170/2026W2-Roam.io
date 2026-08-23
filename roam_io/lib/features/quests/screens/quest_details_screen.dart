/*
 * Description:
 *   Displays full side-quest information and allows the current user to
 *   start and complete quests using their configured verification method.
 *
 *   Photo-based quests support camera/gallery proof selection, local preview,
 *   Firebase Storage upload and clean integration with quest verification.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/quests/screens/quest_photo_service.dart';

import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../../auth/providers/auth_provider.dart';
import 'data/quest.dart';
import 'quest_controller.dart';
import 'quest_enums.dart';

class QuestDetailsScreen extends StatefulWidget {
  const QuestDetailsScreen({
    super.key,
    required this.quest,
    this.photoService,
  });

  final Quest quest;
  final QuestPhotoService? photoService;

  @override
  State<QuestDetailsScreen> createState() =>
      _QuestDetailsScreenState();
}

class _QuestDetailsScreenState
    extends State<QuestDetailsScreen> {
  late final QuestPhotoService _photoService;

  QuestPhotoSelection? _selectedPhoto;

  bool _isUploadingPhoto = false;

  Quest get quest => widget.quest;

  bool get _requiresPhoto =>
      quest.verificationType ==
          QuestVerificationType.photo ||
      quest.verificationType ==
          QuestVerificationType.gpsAndPhoto;

  @override
  void initState() {
    super.initState();

    _photoService =
        widget.photoService ?? QuestPhotoService();
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        context.watch<QuestController>();

    final progress =
        controller.progressForQuest(quest.id);

    final isBusy =
        controller.isCompletingQuest ||
        _isUploadingPhoto;

    return Scaffold(
      backgroundColor:
          AppSurfaces.pageBackground(context),
      appBar: AppBar(
        backgroundColor:
            AppSurfaces.pageBackground(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Side Quest',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            40,
          ),
          children: [
            _QuestHero(
              quest: quest,
            ),

            const SizedBox(height: 16),

            _QuestDescriptionCard(
              description: quest.description,
            ),

            const SizedBox(height: 14),

            _QuestInformationCard(
              quest: quest,
            ),

            const SizedBox(height: 18),

            if (progress == null)
              _StartQuestButton(
                isLoading:
                    controller.isStartingQuest,
                onPressed: () =>
                    _startQuest(context),
              )
            else ...[
              _QuestStatusCard(
                status: progress.status,
              ),

              if (progress.status ==
                  QuestStatus.active) ...[
                const SizedBox(height: 12),

                _VerificationHint(
                  type:
                      quest.verificationType,
                ),

                if (_requiresPhoto) ...[
                  const SizedBox(height: 14),

                  _QuestPhotoProofCard(
                    photo: _selectedPhoto,
                    isBusy: isBusy,
                    onAddPhoto:
                        _showPhotoSourceSheet,
                    onRemovePhoto: () {
                      setState(() {
                        _selectedPhoto = null;
                      });
                    },
                  ),
                ],

                const SizedBox(height: 14),

                _CompleteQuestButton(
                  isLoading: isBusy,
                  requiresPhoto:
                      _requiresPhoto,
                  hasPhoto:
                      _selectedPhoto != null,
                  onPressed: () =>
                      _completeQuest(context),
                ),
              ],
            ],

            if (controller.completionMessage !=
                null) ...[
              const SizedBox(height: 14),

              _MessageCard(
                message:
                    controller.completionMessage!,
                isError: false,
              ),
            ],

            if (controller.errorMessage !=
                null) ...[
              const SizedBox(height: 14),

              _MessageCard(
                message:
                    controller.errorMessage!,
                isError: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startQuest(
    BuildContext context,
  ) async {
    final userId =
        context.read<AuthProvider>().currentUser?.uid;

    if (userId == null) {
      _showMessage(
        'Log in to start this quest.',
      );
      return;
    }

    final controller =
        context.read<QuestController>();

    final success =
        await controller.startQuest(
          userId: userId,
          quest: quest,
        );

    if (!mounted) return;

    if (success) {
      _showMessage('Quest started!');
    }
  }

  Future<void> _completeQuest(
    BuildContext context,
  ) async {
    final userId =
        context.read<AuthProvider>().currentUser?.uid;

    if (userId == null) {
      _showMessage(
        'Log in to complete this quest.',
      );
      return;
    }

    if (_requiresPhoto &&
        _selectedPhoto == null) {
      _showMessage(
        'Add a proof photo before completing this quest.',
      );
      return;
    }

    final controller =
        context.read<QuestController>();

    String? photoUrl;

    try {
      if (_requiresPhoto) {
        setState(() {
          _isUploadingPhoto = true;
        });

        photoUrl =
            await _photoService.uploadQuestProof(
          userId: userId,
          questId: quest.id,
          photo: _selectedPhoto!,
        );
      }

      if (!mounted) return;

      final success =
          await controller.completeQuest(
        userId: userId,
        quest: quest,
        photoUrl: photoUrl,
      );

      if (!mounted) return;

      if (success) {
        _showMessage(
          'Quest completed! +${quest.rewardXp} XP',
        );
      }
    } catch (error) {
      debugPrint(
        '[QuestDetailsScreen] '
        'Photo upload/completion failed: $error',
      );

      if (!mounted) return;

      _showMessage(
        'Could not upload your quest photo. Try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    final source =
        await showModalBottomSheet<_QuestPhotoSource>(
      context: context,
      backgroundColor:
          AppSurfaces.card(context),
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              4,
              18,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Add quest proof',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Choose how you want to add your verification photo.',
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

                const SizedBox(height: 18),

                _PhotoSourceOption(
                  icon:
                      Icons.photo_camera_rounded,
                  title: 'Take Photo',
                  subtitle:
                      'Use your camera now',
                  onTap: () {
                    Navigator.of(sheetContext).pop(
                      _QuestPhotoSource.camera,
                    );
                  },
                ),

                const SizedBox(height: 10),

                _PhotoSourceOption(
                  icon:
                      Icons.photo_library_rounded,
                  title: 'Choose from Gallery',
                  subtitle:
                      'Use an existing photo',
                  onTap: () {
                    Navigator.of(sheetContext).pop(
                      _QuestPhotoSource.gallery,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      final photo =
          source == _QuestPhotoSource.camera
          ? await _photoService.takePhoto()
          : await _photoService
                .chooseFromGallery();

      if (!mounted || photo == null) {
        return;
      }

      setState(() {
        _selectedPhoto = photo;
      });
    } catch (error) {
      debugPrint(
        '[QuestDetailsScreen] '
        'Photo selection failed: $error',
      );

      if (!mounted) return;

      _showMessage(
        'Could not access that photo.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}

enum _QuestPhotoSource {
  camera,
  gallery,
}

class _QuestPhotoProofCard
    extends StatelessWidget {
  const _QuestPhotoProofCard({
    required this.photo,
    required this.isBusy,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final QuestPhotoSelection? photo;
  final bool isBusy;

  final VoidCallback onAddPhoto;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(18),
          onTap:
              isBusy ? null : onAddPhoto,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color:
                  AppSurfaces.softCard(context),
              borderRadius:
                  BorderRadius.circular(18),
              border: Border.all(
                color:
                    AppSurfaces.border(context),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.sage
                        .withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons
                        .add_a_photo_rounded,
                    color: AppColors.sage,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add proof photo',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Take a photo or choose one from your gallery.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color:
                                  AppSurfaces
                                      .textMuted(
                                        context,
                                      ),
                            ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                      AppSurfaces.textSubtle(
                        context,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.memory(
              photo!.bytes,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              12,
              10,
              12,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.sage,
                  size: 21,
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proof photo ready',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                      ),
                      Text(
                        'This will be uploaded when you verify the quest.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color:
                                  AppSurfaces
                                      .textMuted(
                                        context,
                                      ),
                            ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip: 'Replace photo',
                  onPressed:
                      isBusy ? null : onAddPhoto,
                  icon: const Icon(
                    Icons.edit_rounded,
                  ),
                ),

                IconButton(
                  tooltip: 'Remove photo',
                  onPressed:
                      isBusy
                      ? null
                      : onRemovePhoto,
                  icon: const Icon(
                    Icons.close_rounded,
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

class _PhotoSourceOption
    extends StatelessWidget {
  const _PhotoSourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color:
                AppSurfaces.softCard(context),
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color:
                  AppSurfaces.border(context),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.sage
                      .withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppColors.sage,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w800,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color:
                                AppSurfaces
                                    .textMuted(
                                      context,
                                    ),
                          ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color:
                    AppSurfaces.textSubtle(
                      context,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestHero extends StatelessWidget {
  const _QuestHero({
    required this.quest,
  });

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final accent =
        _categoryAccent(quest.category);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppSurfaces.border(context),
        ),
        boxShadow:
            AppSurfaces.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha:
                        AppSurfaces.isDark(context)
                        ? 0.20
                        : 0.16,
                  ),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  _categoryIcon(
                    quest.category,
                  ),
                  color: accent,
                ),
              ),
              const Spacer(),
              _DifficultyBadge(
                difficulty:
                    quest.difficulty,
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            quest.category.displayName
                .toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(
                  color: accent,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: 1,
                ),
          ),

          const SizedBox(height: 6),

          Text(
            quest.title,
            style: Theme.of(context)
                .textTheme
                .headlineLarge
                ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                  height: 1.08,
                ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              const Icon(
                Icons.stars_rounded,
                color: AppColors.sage,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                '+${quest.rewardXp} XP',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      color:
                          AppColors.sage,
                      fontWeight:
                          FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestDescriptionCard
    extends StatelessWidget {
  const _QuestDescriptionCard({
    required this.description,
  });

  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppSurfaces.softCard(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppSurfaces.border(context),
        ),
      ),
      child: Text(
        description,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(
              height: 1.5,
              color:
                  AppSurfaces.textPrimary(context),
            ),
      ),
    );
  }
}

class _QuestInformationCard
    extends StatelessWidget {
  const _QuestInformationCard({
    required this.quest,
  });

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppSurfaces.border(context),
        ),
        boxShadow:
            AppSurfaces.cardShadow(context),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.stars_rounded,
            label: 'Reward',
            value: '${quest.rewardXp} XP',
          ),

          const _DetailDivider(),

          _DetailRow(
            icon:
                Icons.verified_user_outlined,
            label: 'Verification',
            value:
                quest.verificationType.displayName,
          ),

          if (quest.estimatedMinutes !=
              null) ...[
            const _DetailDivider(),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Estimated time',
              value:
                  '${quest.estimatedMinutes} min',
            ),
          ],

          if (quest
                  .verificationRadiusMetres !=
              null) ...[
            const _DetailDivider(),
            _DetailRow(
              icon:
                  Icons.location_on_outlined,
              label: 'Location radius',
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
      padding: const EdgeInsets.symmetric(
        vertical: 13,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color:
                Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
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
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDivider
    extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: AppSurfaces.border(context),
    );
  }
}

class _DifficultyBadge
    extends StatelessWidget {
  const _DifficultyBadge({
    required this.difficulty,
  });

  final QuestDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final color =
        _difficultyColor(difficulty);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Text(
        difficulty.displayName,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _StartQuestButton
    extends StatelessWidget {
  const _StartQuestButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.sage,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
        ),
        onPressed:
            isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
              )
            : const Icon(
                Icons.play_arrow_rounded,
              ),
        label: Text(
          isLoading
              ? 'Starting...'
              : 'Start Quest',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CompleteQuestButton
    extends StatelessWidget {
  const _CompleteQuestButton({
    required this.isLoading,
    required this.requiresPhoto,
    required this.hasPhoto,
    required this.onPressed,
  });

  final bool isLoading;
  final bool requiresPhoto;
  final bool hasPhoto;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final missingPhoto =
        requiresPhoto && !hasPhoto;

    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.clay,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
        ),
        onPressed:
            isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
              )
            : Icon(
                missingPhoto
                    ? Icons
                          .add_a_photo_rounded
                    : Icons.flag_rounded,
              ),
        label: Text(
          isLoading
              ? 'Verifying...'
              : missingPhoto
              ? 'Add Photo to Verify'
              : 'Verify & Complete',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _VerificationHint
    extends StatelessWidget {
  const _VerificationHint({
    required this.type,
  });

  final QuestVerificationType type;

  @override
  Widget build(BuildContext context) {
    final description = switch (type) {
      QuestVerificationType.gps =>
        'Your current location will be checked before completing this quest.',

      QuestVerificationType.photo =>
        'Add a photo showing that you completed this quest.',

      QuestVerificationType.gpsAndPhoto =>
        'Your current location and proof photo will both be checked.',

      QuestVerificationType.distanceWalked =>
        'Your travelled distance will be used to verify this quest.',

      QuestVerificationType.stepCount =>
        'Your step count will be used to verify this quest.',

      QuestVerificationType.timeAtLocation =>
        'Time spent at the quest location will be used for verification.',

      QuestVerificationType.manual =>
        'This quest requires manual verification.',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppSurfaces.softCard(context),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppSurfaces.border(context),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 20,
            color: AppColors.sage,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color:
                        AppSurfaces.textMuted(
                          context,
                        ),
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestStatusCard
    extends StatelessWidget {
  const _QuestStatusCard({
    required this.status,
  });

  final QuestStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      QuestStatus.available => 'Available',
      QuestStatus.active =>
        'Quest in progress',
      QuestStatus.submitted =>
        'Waiting for verification',
      QuestStatus.completed =>
        'Quest completed',
      QuestStatus.rejected =>
        'Verification rejected',
      QuestStatus.expired =>
        'Quest expired',
    };

    final icon = switch (status) {
      QuestStatus.available =>
        Icons.flag_outlined,
      QuestStatus.active =>
        Icons.directions_run_rounded,
      QuestStatus.submitted =>
        Icons.hourglass_top_rounded,
      QuestStatus.completed =>
        Icons.check_circle_rounded,
      QuestStatus.rejected =>
        Icons.cancel_rounded,
      QuestStatus.expired =>
        Icons.schedule_rounded,
    };

    final color = switch (status) {
      QuestStatus.completed =>
        AppColors.sage,
      QuestStatus.rejected =>
        AppColors.clay,
      QuestStatus.expired =>
        AppSurfaces.textMuted(context),
      _ => AppColors.sage,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              color.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w800,
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
    final color =
        isError ? AppColors.clay : AppColors.sage;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              color.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons
                    .check_circle_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color:
                        AppSurfaces.textPrimary(
                          context,
                        ),
                    fontWeight:
                        FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _categoryAccent(
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

IconData _categoryIcon(
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

Color _difficultyColor(
  QuestDifficulty difficulty,
) {
  return switch (difficulty) {
    QuestDifficulty.easy =>
      AppColors.sage,
    QuestDifficulty.medium =>
      const Color(0xFF98752B),
    QuestDifficulty.hard =>
      AppColors.clay,
    QuestDifficulty.epic =>
      const Color(0xFF765296),
  };
}