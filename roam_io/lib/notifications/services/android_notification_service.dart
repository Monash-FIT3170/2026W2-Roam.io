/*
 * Author: Sam Sutherland
 * Last Modified: 01/08/2026
 * Description:
 *   Manages Android device notifications, including initialisation and permission requests.
 */

// coverage:ignore-file

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_notification.dart';
import '../models/notification_action.dart';
import '../models/notification_type.dart';

/// Provides Android-specific notification delivery
class AndroidNotificationService {
  AndroidNotificationService._();

  static final AndroidNotificationService instance =
      AndroidNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Prevents the plugin from being initialised more than once.
  bool _isInitialised = false;

  bool get _isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Events produced when an Android notification or action is selected.
  final ValueNotifier<NotificationResponse?> responseNotifier =
      ValueNotifier<NotificationResponse?>(null);

  Future<void> initialise() async {
    if (!_isSupportedPlatform) return;
    if (_isInitialised) return;

    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );

    const initialisationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: initialisationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _createChannels();

    _isInitialised = true;
  }

  /// Requests permission to display notifications on Android devices
  ///
  /// Returns `true` when permission is granted.
  Future<bool> requestPermission() async {
    if (!_isSupportedPlatform) return false;

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final result = await androidPlugin?.requestNotificationsPermission();

    return result ?? false;
  }

  /// Displays the notification through the Android notification system.
  ///
  /// The appropriate channel and Android category are selected from the
  /// notification type.
  Future<void> show(AppNotification notification) async {
    if (!_isSupportedPlatform) return;

    if (!_isInitialised) {
      await initialise();
    }

    final channel = _channelFor(notification.type);

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: channel.priority,
      icon: '@drawable/ic_notification',
      category: _categoryFor(notification.type),
      actions: notification.actions.map(_convertAction).toList(growable: false),
    );

    final payload = jsonEncode({
      'id': notification.id,
      'type': notification.type.name,
      ...notification.data,
    });

    await _plugin.show(
      id: _createAndroidId(notification.id),
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  Future<void> cancel(AppNotification notification) async {
    if (!_isSupportedPlatform) return;

    await _plugin.cancel(id: _createAndroidId(notification.id));
  }

  /// Cancels the Android notification
  Future<void> cancelAll() async {
    if (!_isSupportedPlatform) return;

    await _plugin.cancelAll();
  }

  /// Handles notification taps and action selections
  void _handleNotificationResponse(NotificationResponse response) {
    debugPrint(
      '[Android notification] '
      'action=${response.actionId}, payload=${response.payload}',
    );

    responseNotifier.value = response;
  }

  AndroidNotificationAction _convertAction(NotificationAction action) {
    return AndroidNotificationAction(
      action.type.name,
      action.label,
      showsUserInterface: true,
      cancelNotification: true,
    );
  }

  Future<void> _createChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return;

    for (final channel in _channels) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          channel.id,
          channel.name,
          description: channel.description,
          importance: channel.importance,
        ),
      );
    }
  }

  _NotificationChannelConfiguration _channelFor(NotificationType type) {
    switch (type) {
      case NotificationType.error:
        return _importantChannel;

      case NotificationType.activity:
        return _activityChannel;

      case NotificationType.kudos:
      case NotificationType.comment:
      case NotificationType.commentReply:
      case NotificationType.commentLike:
      case NotificationType.friendRequest:
      case NotificationType.friendAccepted:
      case NotificationType.follow:
      case NotificationType.followRequest:
      case NotificationType.followRequestAccepted:
        return _socialChannel;
    }
  }

  AndroidNotificationCategory? _categoryFor(NotificationType type) {
    switch (type) {
      case NotificationType.comment:
      case NotificationType.commentReply:
        return AndroidNotificationCategory.message;

      case NotificationType.friendRequest:
      case NotificationType.friendAccepted:
      case NotificationType.follow:
      case NotificationType.followRequest:
      case NotificationType.followRequestAccepted:
        return AndroidNotificationCategory.social;

      case NotificationType.activity:
        return AndroidNotificationCategory.workout;

      case NotificationType.error:
        return AndroidNotificationCategory.error;

      case NotificationType.kudos:
      case NotificationType.commentLike:
        return AndroidNotificationCategory.social;
    }
  }

  int _createAndroidId(String notificationId) {
    return notificationId.hashCode & 0x7fffffff;
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint(
    '[Background notification action] '
    'action=${response.actionId}, payload=${response.payload}',
  );
}

/// Internal description of an Android notification channel.
class _NotificationChannelConfiguration {
  final String id;
  final String name;
  final String description;
  final Importance importance;
  final Priority priority;

  const _NotificationChannelConfiguration({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
    required this.priority,
  });
}

const _socialChannel = _NotificationChannelConfiguration(
  id: 'social_notifications',
  name: 'Social notifications',
  description: 'Friend requests, comments and Kudos',
  importance: Importance.high,
  priority: Priority.high,
);

const _activityChannel = _NotificationChannelConfiguration(
  id: 'activity_notifications',
  name: 'Activity notifications',
  description: 'Journey and activity updates',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
);

const _importantChannel = _NotificationChannelConfiguration(
  id: 'important_notifications',
  name: 'Important notifications',
  description: 'Errors and notifications requiring attention',
  importance: Importance.high,
  priority: Priority.high,
);

const _channels = [_socialChannel, _activityChannel, _importantChannel];
