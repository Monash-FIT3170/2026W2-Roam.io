/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 21 August 2026
 * Description:
 *   Structured activity media model used by feed cards, details, Journey
 *   publishing, and profile media galleries while preserving legacy URL
 *   compatibility.
 */

import 'package:image_picker/image_picker.dart';

/// Supported persisted activity media types.
enum ActivityMediaType {
  photo,
  video;

  static ActivityMediaType fromWireValue(String? value) {
    return ActivityMediaType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ActivityMediaType.photo,
    );
  }

  static ActivityMediaType inferFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('video')) {
      return ActivityMediaType.video;
    }
    return ActivityMediaType.photo;
  }
}

/// Media attached to a persisted social activity.
class ActivityMediaItem {
  const ActivityMediaItem({
    required this.id,
    required this.type,
    required this.url,
    required this.storagePath,
    required this.order,
    required this.createdAt,
    this.thumbnailUrl,
  });

  factory ActivityMediaItem.legacyUrl(String url, int order) {
    return ActivityMediaItem(
      id: 'legacy_$order',
      type: ActivityMediaType.inferFromUrl(url),
      url: url,
      storagePath: '',
      order: order,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final ActivityMediaType type;
  final String url;
  final String storagePath;
  final int order;
  final DateTime createdAt;
  final String? thumbnailUrl;

  bool get isVideo => type == ActivityMediaType.video;

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'id': id,
      'type': type.name,
      'url': url,
      'storagePath': storagePath,
      'order': order,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
    final thumbnail = thumbnailUrl;
    if (thumbnail != null && thumbnail.isNotEmpty) {
      data['thumbnailUrl'] = thumbnail;
    }
    return data;
  }
}

/// Local media selected before an activity has been published.
class PendingActivityMedia {
  const PendingActivityMedia({required this.file, required this.type});

  final XFile file;
  final ActivityMediaType type;

  bool get isVideo => type == ActivityMediaType.video;
}
