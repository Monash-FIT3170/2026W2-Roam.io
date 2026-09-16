/*
 * Description:
 *   Owner-only activity edit/delete flows, shared by any surface that shows
 *   an activity's three-dot overflow menu (feed cards, detail screen) so the
 *   dialog logic lives in one place instead of being re-implemented per
 *   screen.
 */

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../theme/app_surfaces.dart';
import '../data/activity_mutation_service.dart';
import '../models/activity_feed_item.dart';

/// Opens the "Edit Activity" dialog (title + up to 3 media items) and saves
/// changes via [mutationService].
Future<void> showEditActivityDialog({
  required BuildContext context,
  required ActivityFeedItem activity,
  ActivityMutationService? mutationService,
}) async {
  final service = mutationService ?? ActivityMutationService();
  final titleController = TextEditingController(text: activity.title);
  final editableMedia = List<ActivityMediaItem>.from(activity.media);
  final pendingMedia = <PendingActivityMedia>[];
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final mediaCount = editableMedia.length + pendingMedia.length;
        return AlertDialog(
          title: const Text('Edit Activity'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                if (editableMedia.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 90,
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      buildDefaultDragHandles: false,
                      itemCount: editableMedia.length,
                      // ignore: deprecated_member_use
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        setDialogState(() {
                          final item = editableMedia.removeAt(oldIndex);
                          editableMedia.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final media = editableMedia[index];
                        return ReorderableDragStartListener(
                          key: ValueKey<String>('existing-${media.id}'),
                          index: index,
                          child: _EditableMediaTile(
                            isVideo: media.isVideo,
                            url: media.url,
                            onRemove: () => setDialogState(
                              () => editableMedia.removeAt(index),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (pendingMedia.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      buildDefaultDragHandles: false,
                      itemCount: pendingMedia.length,
                      // ignore: deprecated_member_use
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        setDialogState(() {
                          final item = pendingMedia.removeAt(oldIndex);
                          pendingMedia.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final media = pendingMedia[index];
                        return ReorderableDragStartListener(
                          key: ValueKey<String>('pending-${media.file.path}'),
                          index: index,
                          child: _EditableMediaTile(
                            isVideo: media.isVideo,
                            file: File(media.file.path),
                            onRemove: () => setDialogState(
                              () => pendingMedia.removeAt(index),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: mediaCount >= 3
                            ? null
                            : () async {
                                final picked =
                                    await _pickEditMediaFromLibrary();
                                if (picked == null) return;
                                setDialogState(() => pendingMedia.add(picked));
                              },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Photo Library'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Take photo',
                      onPressed: mediaCount >= 3
                          ? null
                          : () async {
                              final picked = await _takeEditPhoto();
                              if (picked == null) return;
                              setDialogState(() => pendingMedia.add(picked));
                            },
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      tooltip: 'Record video',
                      onPressed: mediaCount >= 3
                          ? null
                          : () async {
                              final picked = await _takeEditVideo();
                              if (picked == null) return;
                              setDialogState(() => pendingMedia.add(picked));
                            },
                      icon: const Icon(Icons.videocam_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
  final editedTitle = titleController.text;
  titleController.dispose();
  if (result != true || !context.mounted) return;
  try {
    await service.updateActivityEditableFields(
      activity: activity,
      title: editedTitle,
      media: editableMedia,
      pendingMedia: pendingMedia,
    );
    if (context.mounted) {
      AppToast.success(context, 'Activity updated.');
    }
  } catch (error) {
    if (context.mounted) {
      AppToast.error(context, 'Could not update activity.');
    }
  }
}

Future<PendingActivityMedia?> _pickEditMediaFromLibrary() async {
  final picker = ImagePicker();
  final file = await picker.pickMedia(
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
  );
  if (file == null) return null;
  return PendingActivityMedia(file: file, type: _inferMediaType(file));
}

Future<PendingActivityMedia?> _takeEditPhoto() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
  );
  if (file == null) return null;
  return PendingActivityMedia(file: file, type: ActivityMediaType.photo);
}

Future<PendingActivityMedia?> _takeEditVideo() async {
  final file = await ImagePicker().pickVideo(
    source: ImageSource.camera,
    maxDuration: const Duration(minutes: 2),
  );
  if (file == null) return null;
  return PendingActivityMedia(file: file, type: ActivityMediaType.video);
}

ActivityMediaType _inferMediaType(XFile file) {
  final mime = file.mimeType?.toLowerCase();
  if (mime != null && mime.startsWith('video/')) {
    return ActivityMediaType.video;
  }
  final lowerName = file.name.toLowerCase();
  if (lowerName.endsWith('.mp4') ||
      lowerName.endsWith('.mov') ||
      lowerName.endsWith('.m4v')) {
    return ActivityMediaType.video;
  }
  return ActivityMediaType.photo;
}

/// Confirms and performs activity deletion via [mutationService]. Calls
/// [onDeleted] after a successful delete so callers can navigate/refresh as
/// needed; the activity's own feed/detail listeners already drop it once the
/// document is gone.
Future<void> confirmDeleteActivity({
  required BuildContext context,
  required ActivityFeedItem activity,
  ActivityMutationService? mutationService,
  VoidCallback? onDeleted,
}) async {
  final service = mutationService ?? ActivityMutationService();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Activity?'),
      content: const Text('This removes the activity post only.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await service.deleteActivity(activity);
    if (context.mounted) {
      onDeleted?.call();
    }
  } catch (error) {
    if (context.mounted) {
      AppToast.error(context, 'Could not delete activity.');
    }
  }
}

class _EditableMediaTile extends StatelessWidget {
  const _EditableMediaTile({
    required this.isVideo,
    required this.onRemove,
    this.url,
    this.file,
  });

  final bool isVideo;
  final String? url;
  final File? file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = this.file;
    final url = this.url;
    return Container(
      width: 84,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppSurfaces.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSurfaces.border(context)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isVideo
                  ? Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : file != null
                  ? Image.file(file, fit: BoxFit.cover)
                  : url != null && url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.cover)
                  : const Center(child: Icon(Icons.photo_outlined)),
            ),
          ),
          if (isVideo)
            const Positioned(
              left: 8,
              bottom: 8,
              child: Icon(Icons.videocam, color: Colors.white, size: 18),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filledTonal(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
