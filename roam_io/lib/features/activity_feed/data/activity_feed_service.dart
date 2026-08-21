/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 10 August 2026
 * Description:
 *   Reads persisted public activity feed documents for profile and Home feeds.
 */

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/activity_feed_item.dart';

/// Firestore-backed reader for persisted activity feed items.
class ActivityFeedService {
  ActivityFeedService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _activities =>
      _firestore.collection('activities');

  /// Watches one persisted activity by ID.
  Stream<ActivityFeedItem?> watchActivity(String activityId) {
    final path = 'activities/$activityId';
    debugPrint('[ActivityFeedService] watchActivity path=$path');
    return _activities
        .doc(activityId)
        .snapshots()
        .handleError((Object error) {
          _logQueryError(
            label: 'watchActivity',
            collection: 'activities',
            filter: 'documentId == $activityId',
            currentUserId: null,
            error: error,
          );
          throw error;
        })
        .map((doc) {
          final data = doc.data();
          debugPrint(
            '[ActivityFeedService] watchActivity snapshot path=$path '
            'exists=${doc.exists}',
          );
          if (data == null) return null;
          final item = _tryActivityFromDoc(doc.id, data);
          debugPrint(
            '[ActivityFeedService] watchActivity parsed path=$path '
            'itemId=${item?.id}',
          );
          return item;
        });
  }

  /// Watches persisted public activities owned by [profileId], newest first.
  Stream<List<ActivityFeedItem>> watchPublicActivitiesForProfile(
    String profileId,
  ) {
    debugPrint(
      '[ActivityFeedService] watchPublicActivitiesForProfile '
      'collection=activities filter=ownerId==$profileId '
      'orderBy=createdAt desc limit=20',
    );
    return _activities
        .where('ownerId', isEqualTo: profileId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .handleError((Object error) {
          _logQueryError(
            label: 'watchPublicActivitiesForProfile',
            collection: 'activities',
            filter: 'ownerId == $profileId',
            currentUserId: null,
            error: error,
          );
          throw error;
        })
        .map(
          (snapshot) => _itemsFromSnapshot(
            label: 'watchPublicActivitiesForProfile',
            snapshot: snapshot,
            currentUserId: null,
            filter: 'ownerId == $profileId',
          ),
        );
  }

  /// Watches persisted activities owned by [ownerId], newest first.
  Stream<List<ActivityFeedItem>> watchActivitiesOwnedBy(String ownerId) {
    if (ownerId.isEmpty) {
      return Stream<List<ActivityFeedItem>>.value(const <ActivityFeedItem>[]);
    }
    debugPrint(
      '[ActivityFeedService] watchActivitiesOwnedBy currentUserId=$ownerId '
      'collection=activities filter=ownerId==$ownerId '
      'orderBy=createdAt desc limit=20',
    );
    return _activities
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .handleError((Object error) {
          _logQueryError(
            label: 'watchActivitiesOwnedBy',
            collection: 'activities',
            filter: 'ownerId == $ownerId',
            currentUserId: ownerId,
            error: error,
          );
          throw error;
        })
        .map(
          (snapshot) => _itemsFromSnapshot(
            label: 'watchActivitiesOwnedBy',
            snapshot: snapshot,
            currentUserId: ownerId,
            filter: 'ownerId == $ownerId',
          ),
        );
  }

  /// Watches Home feed activities for [userId]: own activities plus activities
  /// from accepted followed users, deduped and sorted newest first.
  Stream<List<ActivityFeedItem>> watchHomeActivitiesForUser({
    required String userId,
    required Stream<List<String>> followedUserIds,
  }) {
    if (userId.isEmpty) {
      return Stream<List<ActivityFeedItem>>.value(const <ActivityFeedItem>[]);
    }

    late StreamController<List<ActivityFeedItem>> controller;
    StreamSubscription<List<String>>? followingSubscription;
    final activitySubscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final ownerActivities = <String, List<_DatedActivityFeedItem>>{};

    void cancelActivitySubscriptions() {
      for (final subscription in activitySubscriptions) {
        unawaited(subscription.cancel());
      }
      activitySubscriptions.clear();
      ownerActivities.clear();
    }

    void emit() {
      if (controller.isClosed) return;
      final byId = <String, _DatedActivityFeedItem>{};
      for (final activities in ownerActivities.values) {
        for (final activity in activities) {
          byId[activity.item.id] = activity;
        }
      }
      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(
        merged.map((activity) => activity.item).toList(growable: false),
      );
    }

    void watchOwners(List<String> followedIds) {
      cancelActivitySubscriptions();
      final ownerIds = <String>{userId};
      for (final id in followedIds) {
        if (id.isNotEmpty) ownerIds.add(id);
      }
      final owners = ownerIds.toList(growable: false);
      debugPrint(
        '[ActivityFeedService] watchHomeActivitiesForUser currentUserId=$userId '
        'ownerQueries=${owners.join(',')}',
      );
      for (final ownerId in owners) {
        debugPrint(
          '[ActivityFeedService] Home owner query currentUserId=$userId '
          'collection=activities filter=ownerId==$ownerId '
          'orderBy=createdAt desc limit=20',
        );
        final subscription = _activities
            .where('ownerId', isEqualTo: ownerId)
            .orderBy('createdAt', descending: true)
            .limit(20)
            .snapshots()
            .listen(
              (snapshot) {
                final items = _datedItemsFromSnapshot(
                  label: 'watchHomeActivitiesForUser',
                  snapshot: snapshot,
                  currentUserId: userId,
                  filter: 'ownerId == $ownerId',
                );
                ownerActivities[ownerId] = items;
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                _logHomeQueryError(
                  currentUserId: userId,
                  ownerId: ownerId,
                  error: error,
                );
                if (!controller.isClosed) {
                  controller.addError(error, stackTrace);
                }
              },
            );
        activitySubscriptions.add(subscription);
      }
    }

    controller = StreamController<List<ActivityFeedItem>>.broadcast(
      onListen: () {
        followingSubscription = followedUserIds.listen(
          watchOwners,
          onError: (Object error, StackTrace stackTrace) {
            _logFollowingIdsError(currentUserId: userId, error: error);
            watchOwners(const <String>[]);
          },
        );
      },
      onCancel: () async {
        await followingSubscription?.cancel();
        cancelActivitySubscriptions();
      },
    );
    return controller.stream;
  }

  void _logHomeQueryError({
    required String currentUserId,
    required String ownerId,
    required Object error,
  }) {
    if (error is FirebaseException) {
      debugPrint(
        '[ActivityFeedService] Home activity query failed '
        'collection=activities currentUserId=$currentUserId ownerId=$ownerId '
        'code=${error.code} message=${error.message} plugin=${error.plugin}',
      );
      return;
    }
    debugPrint(
      '[ActivityFeedService] Home activity query failed '
      'collection=activities currentUserId=$currentUserId ownerId=$ownerId '
      'error=$error',
    );
  }

  void _logQueryError({
    required String label,
    required String collection,
    required String filter,
    required String? currentUserId,
    required Object error,
  }) {
    if (error is FirebaseException) {
      debugPrint(
        '[ActivityFeedService] $label query failed collection=$collection '
        'currentUserId=$currentUserId filter="$filter" '
        'code=${error.code} message=${error.message} plugin=${error.plugin}',
      );
      return;
    }
    debugPrint(
      '[ActivityFeedService] $label query failed collection=$collection '
      'currentUserId=$currentUserId filter="$filter" error=$error',
    );
  }

  void _logFollowingIdsError({
    required String currentUserId,
    required Object error,
  }) {
    if (error is FirebaseException) {
      debugPrint(
        '[ActivityFeedService] Home following lookup failed '
        'collection=follows currentUserId=$currentUserId '
        'code=${error.code} message=${error.message} plugin=${error.plugin}',
      );
      return;
    }
    debugPrint(
      '[ActivityFeedService] Home following lookup failed '
      'collection=follows currentUserId=$currentUserId error=$error',
    );
  }

  List<ActivityFeedItem> _itemsFromSnapshot({
    required String label,
    required QuerySnapshot<Map<String, dynamic>> snapshot,
    required String? currentUserId,
    required String filter,
  }) {
    final parsed = <ActivityFeedItem>[];
    for (final doc in snapshot.docs) {
      final item = _tryActivityFromDoc(doc.id, doc.data());
      if (item != null) parsed.add(item);
    }
    debugPrint(
      '[ActivityFeedService] $label snapshot currentUserId=$currentUserId '
      'collection=activities filter="$filter" docCount=${snapshot.docs.length} '
      'docIds=${snapshot.docs.map((doc) => doc.id).join(',')} '
      'parsedCount=${parsed.length} titles=${parsed.map((item) => item.title).join('|')}',
    );
    return parsed;
  }

  List<_DatedActivityFeedItem> _datedItemsFromSnapshot({
    required String label,
    required QuerySnapshot<Map<String, dynamic>> snapshot,
    required String currentUserId,
    required String filter,
  }) {
    final parsed = <_DatedActivityFeedItem>[];
    for (final doc in snapshot.docs) {
      final item = _tryDatedActivityFromDoc(doc.id, doc.data());
      if (item != null) parsed.add(item);
    }
    debugPrint(
      '[ActivityFeedService] $label snapshot currentUserId=$currentUserId '
      'collection=activities filter="$filter" docCount=${snapshot.docs.length} '
      'docIds=${snapshot.docs.map((doc) => doc.id).join(',')} '
      'parsedCount=${parsed.length} '
      'titles=${parsed.map((item) => item.item.title).join('|')}',
    );
    return parsed;
  }

  _DatedActivityFeedItem? _tryDatedActivityFromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final createdAt = _parseDate(id, data['createdAt']);
    if (createdAt == null) return null;
    final item = _tryActivityFromDocWithDate(id, data, createdAt);
    if (item == null) return null;
    return _DatedActivityFeedItem(item: item, createdAt: createdAt);
  }

  ActivityFeedItem? _tryActivityFromDoc(String id, Map<String, dynamic> data) {
    final createdAt = _parseDate(id, data['createdAt']);
    if (createdAt == null) return null;
    return _tryActivityFromDocWithDate(id, data, createdAt);
  }

  ActivityFeedItem? _tryActivityFromDocWithDate(
    String id,
    Map<String, dynamic> data,
    DateTime createdAt,
  ) {
    try {
      _validateOptionalString(id, data, 'activityId');
      final ownerId = _requiredOwnerId(id, data);
      final displayName = _requiredString(id, data, 'displayName');
      final title = _requiredString(id, data, 'title');
      final kind = _requiredString(id, data, 'kind');
      final showMapPreview = _optionalBool(
        id,
        data,
        'showMapPreview',
        defaultValue: true,
      );
      final metrics = _metricsFromData(id, data['metrics']);
      if (metrics == null) return null;
      final media = _mediaFromData(id, data['media']);
      if (media == null) return null;
      return ActivityFeedItem(
        id: id,
        ownerId: ownerId,
        displayName: displayName,
        username: _optionalString(id, data, 'username'),
        photoUrl: _optionalString(id, data, 'photoUrl'),
        timestampLabel: _formatDate(createdAt),
        title: title,
        kind: ActivityFeedKindParsing.fromWireValue(kind),
        metrics: metrics,
        showMapPreview: showMapPreview,
        sourceJourneyId: _optionalString(id, data, 'sourceJourneyId'),
        encodedRoute: _optionalString(id, data, 'encodedRoute'),
        routeBounds: _routeBoundsFromData(id, data['routeBounds']),
        journeyStartTime: _optionalDate(id, data, 'journeyStartTime'),
        journeyEndTime: _optionalDate(id, data, 'journeyEndTime'),
        transportMode: _optionalString(id, data, 'transportMode'),
        media: media,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[ActivityFeedService] activity parse failed documentId=$id '
        'error=$error\n$stackTrace',
      );
      return null;
    }
  }

  String _requiredOwnerId(String docId, Map<String, dynamic> data) {
    final ownerId = data['ownerId'];
    if (ownerId is String && ownerId.isNotEmpty) return ownerId;
    final profileId = data['profileId'];
    if (profileId is String && profileId.isNotEmpty) return profileId;
    throw _ActivityFieldParseException(
      docId: docId,
      field: 'ownerId/profileId',
      value: ownerId ?? profileId,
      message: 'missing non-empty owner id',
    );
  }

  String _requiredString(
    String docId,
    Map<String, dynamic> data,
    String field,
  ) {
    final value = data[field];
    if (value is String) return value;
    throw _ActivityFieldParseException(
      docId: docId,
      field: field,
      value: value,
      message: 'expected string',
    );
  }

  String? _optionalString(
    String docId,
    Map<String, dynamic> data,
    String field,
  ) {
    final value = data[field];
    if (value == null) return null;
    if (value is String) return value;
    throw _ActivityFieldParseException(
      docId: docId,
      field: field,
      value: value,
      message: 'expected string or null',
    );
  }

  void _validateOptionalString(
    String docId,
    Map<String, dynamic> data,
    String field,
  ) {
    _optionalString(docId, data, field);
  }

  bool _optionalBool(
    String docId,
    Map<String, dynamic> data,
    String field, {
    required bool defaultValue,
  }) {
    final value = data[field];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    throw _ActivityFieldParseException(
      docId: docId,
      field: field,
      value: value,
      message: 'expected bool or null',
    );
  }

  List<ActivityFeedMetric>? _metricsFromData(String docId, Object? value) {
    if (value is! List) {
      debugPrint(
        '[ActivityFeedService] activity parse failed documentId=$docId '
        'field=metrics expected=list actualType=${_typeName(value)} value=$value',
      );
      return null;
    }
    final metrics = <ActivityFeedMetric>[];
    for (var index = 0; index < value.length; index += 1) {
      final metric = value[index];
      if (metric is! Map) {
        debugPrint(
          '[ActivityFeedService] activity parse failed documentId=$docId '
          'field=metrics[$index] expected=map actualType=${_typeName(metric)} '
          'value=$metric',
        );
        return null;
      }
      final label = metric['label'];
      final metricValue = metric['value'];
      if (label is! String || metricValue is! String) {
        debugPrint(
          '[ActivityFeedService] activity parse failed documentId=$docId '
          'field=metrics[$index] expected=label/value strings '
          'labelType=${_typeName(label)} valueType=${_typeName(metricValue)} '
          'value=$metric',
        );
        return null;
      }
      if (label.isNotEmpty && metricValue.isNotEmpty) {
        metrics.add(ActivityFeedMetric(label: label, value: metricValue));
      }
    }
    return metrics;
  }

  List<String>? _mediaFromData(String docId, Object? value) {
    if (value == null) return const <String>[];
    if (value is! List) {
      debugPrint(
        '[ActivityFeedService] activity parse failed documentId=$docId '
        'field=media expected=list actualType=${_typeName(value)} value=$value',
      );
      return null;
    }
    final media = <String>[];
    for (var index = 0; index < value.length; index += 1) {
      final item = value[index];
      if (item is! String) {
        debugPrint(
          '[ActivityFeedService] activity parse failed documentId=$docId '
          'field=media[$index] expected=string actualType=${_typeName(item)} '
          'value=$item',
        );
        return null;
      }
      if (item.isNotEmpty) media.add(item);
    }
    return media;
  }

  ActivityRouteBounds? _routeBoundsFromData(String docId, Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw _ActivityFieldParseException(
        docId: docId,
        field: 'routeBounds',
        value: value,
        message: 'expected map or null',
      );
    }
    final southwestLatitude = _optionalDouble(
      docId,
      value,
      'routeBounds.southwestLatitude',
      'southwestLatitude',
    );
    final southwestLongitude = _optionalDouble(
      docId,
      value,
      'routeBounds.southwestLongitude',
      'southwestLongitude',
    );
    final northeastLatitude = _optionalDouble(
      docId,
      value,
      'routeBounds.northeastLatitude',
      'northeastLatitude',
    );
    final northeastLongitude = _optionalDouble(
      docId,
      value,
      'routeBounds.northeastLongitude',
      'northeastLongitude',
    );
    if (southwestLatitude == null ||
        southwestLongitude == null ||
        northeastLatitude == null ||
        northeastLongitude == null) {
      return null;
    }
    return ActivityRouteBounds(
      southwestLatitude: southwestLatitude,
      southwestLongitude: southwestLongitude,
      northeastLatitude: northeastLatitude,
      northeastLongitude: northeastLongitude,
    );
  }

  double? _optionalDouble(
    String docId,
    Map<dynamic, dynamic> data,
    String fieldLabel,
    String key,
  ) {
    final value = data[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    throw _ActivityFieldParseException(
      docId: docId,
      field: fieldLabel,
      value: value,
      message: 'expected number or null',
    );
  }

  DateTime? _parseDate(String docId, Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    debugPrint(
      '[ActivityFeedService] activity parse failed documentId=$docId '
      'field=createdAt expected=Timestamp|ISO string '
      'actualType=${_typeName(value)} value=$value',
    );
    return null;
  }

  DateTime? _optionalDate(
    String docId,
    Map<String, dynamic> data,
    String field,
  ) {
    final value = data[field];
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw _ActivityFieldParseException(
      docId: docId,
      field: field,
      value: value,
      message: 'expected Timestamp, ISO string, or null',
    );
  }

  String _formatDate(DateTime value) {
    if (value.millisecondsSinceEpoch == 0) return 'Recently';
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} at ${local.hour}:$minute';
  }
}

String _typeName(Object? value) =>
    value == null ? 'null' : value.runtimeType.toString();

class _ActivityFieldParseException implements Exception {
  const _ActivityFieldParseException({
    required this.docId,
    required this.field,
    required this.value,
    required this.message,
  });

  final String docId;
  final String field;
  final Object? value;
  final String message;

  @override
  String toString() {
    return 'ActivityFieldParseException(documentId=$docId, field=$field, '
        'message=$message, actualType=${_typeName(value)}, value=$value)';
  }
}

class _DatedActivityFeedItem {
  const _DatedActivityFeedItem({required this.item, required this.createdAt});

  final ActivityFeedItem item;
  final DateTime createdAt;
}
