/*
 * Author: Amarprit Singh
 * Last Updated: 28 August 2026
 * Description:
 *   Storage identity for the map picture saved with a journey activity, and
 *   the once-per-activity guard used to backfill activities published before
 *   the picture was captured at save time.
 */

import 'package:flutter/foundation.dart';

import 'activity_mutation_service.dart';

/// Naming for the single map picture stored against an activity.
///
/// One fixed media id per activity keeps a re-capture overwriting the previous
/// picture instead of piling up orphaned Storage objects.
abstract final class ActivityMapImage {
  static const mediaId = 'map';
  static const filename = 'map_preview.png';
  static const mediaType = 'photo';

  /// Shape every capture is framed in, and the shape every surface shows it in
  /// — feed cards, the detail screen, and the share card all use this, so the
  /// picture fills each of them without letterboxing or cropping.
  ///
  /// Taller than a video frame on purpose: a wide slot frames the route into a
  /// letterbox strip, and the map is the point of the card.
  static const aspectRatio = 4 / 3;
}

/// Records a captured map picture on an activity that was saved without one.
///
/// Cards are rebuilt constantly while a feed scrolls, so the activity ids that
/// have already been handled are remembered for the life of the process. A
/// failed attempt releases its id so a later rebuild can try again.
abstract final class ActivityMapImageBackfill {
  static final Set<String> _handled = <String>{};

  /// Whether [activityId] still needs its map picture captured.
  static bool isPending(String activityId) => !_handled.contains(activityId);

  static Future<void> record({
    required String activityId,
    required String ownerId,
    required Uint8List bytes,
    required ActivityMutationService mutationService,
  }) async {
    if (activityId.isEmpty || ownerId.isEmpty || bytes.isEmpty) return;
    if (!_handled.add(activityId)) return;

    try {
      await mutationService.attachMapImage(
        activityId: activityId,
        ownerId: ownerId,
        bytes: bytes,
      );
    } catch (error) {
      _handled.remove(activityId);
      debugPrint(
        '[ActivityMapImageBackfill] capture upload failed '
        'activityId=$activityId error=$error',
      );
    }
  }

  @visibleForTesting
  static void resetForTesting() => _handled.clear();
}
