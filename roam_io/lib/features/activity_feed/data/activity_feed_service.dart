/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 7 August 2026
 * Description:
 *   Reads persisted public activity feed documents for external profiles.
 */

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity_feed_item.dart';

/// Firestore-backed reader for persisted activity feed items.
class ActivityFeedService {
  ActivityFeedService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _activities =>
      _firestore.collection('activities');

  /// Watches persisted public activities authored by [profileId], newest first.
  Stream<List<ActivityFeedItem>> watchPublicActivitiesForProfile(
    String profileId,
  ) {
    return _activities
        .where('profileId', isEqualTo: profileId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => _activityFromDoc(doc.id, doc.data()))
              .toList();
        });
  }

  ActivityFeedItem _activityFromDoc(String id, Map<String, dynamic> data) {
    final createdAt = _parseDate(data['createdAt']);
    return ActivityFeedItem(
      id: id,
      displayName: (data['displayName'] ?? '') as String,
      username: data['username'] as String?,
      photoUrl: data['photoUrl'] as String?,
      timestampLabel: _formatDate(createdAt),
      title: (data['title'] ?? 'Activity') as String,
      kind: ActivityFeedKindParsing.fromWireValue(
        (data['kind'] ?? 'exploration') as String,
      ),
      metrics: _metricsFromData(data['metrics']),
      showMapPreview: data['showMapPreview'] as bool? ?? true,
    );
  }

  List<ActivityFeedMetric> _metricsFromData(Object? value) {
    if (value is! List) return const <ActivityFeedMetric>[];
    return value
        .whereType<Map>()
        .map((metric) {
          return ActivityFeedMetric(
            label: (metric['label'] ?? '') as String,
            value: (metric['value'] ?? '') as String,
          );
        })
        .where((metric) {
          return metric.label.isNotEmpty && metric.value.isNotEmpty;
        })
        .toList();
  }

  DateTime _parseDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(DateTime value) {
    if (value.millisecondsSinceEpoch == 0) return 'Recently';
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} at ${local.hour}:$minute';
  }
}
