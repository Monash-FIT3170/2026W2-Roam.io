/*
 * Author: Sam Sutherland
 * Last Modified: 13/08/2026
 * Description:
 *   Manages Android and iOS system notifications, including initialisation,
 *   permission requests, notification actions, categories and channels.
 */

// coverage:ignore-file

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_notification.dart';
import '../models/notification_action.dart';
import '../models/notification_type.dart';

/// Provides system-level notification delivery for Android and iOS.
///
/// The class name is retained for compatibility with the existing codebase,
/// but the service now supports both Android and iOS notifications.
class AndroidNotificationService {
  AndroidNotificationService._();

  static final AndroidNotificationService instance =
      AndroidNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Prevents the plugin from being initialised more than once.
  bool _isInitialised = false;

  /// Whether the current platform is supported by this service.
  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Events produced when a system notification or action is selected.
  final ValueNotifier<NotificationResponse?> responseNotifier =
      ValueNotifier<NotificationResponse?>(null);

  /// Initialises local notification support for the current platform.
  ///
  /// Android uses the application's custom notification icon and notification
  /// channels. iOS registers notification categories and delays the permission
  /// prompt until [requestPermission] is called.
  Future<void> initialise() async {
    if (!_isSupportedPlatform) return;
    if (_isInitialised) return;

    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );

    final iosSettings = IOSInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: _iosNotificationCategories,
    );

    final initialisationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initialisationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Android notification channels do not exist on iOS.
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _createChannels();
    }

    _isInitialised = true;
  }

  /// Requests permission to display system notifications.
  ///
  /// Android requests the notification runtime permission where required.
  /// iOS requests alert, badge and sound permissions.
  ///
  /// Returns `true` when permission is granted.
  Future<bool> requestPermission() async {
    if (!_isSupportedPlatform) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final result = await androidPlugin?.requestNotificationsPermission();
      return result ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      final result = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      return result ?? false;
    }

    return false;
  }

  /// Displays a system notification on the current supported platform.
  ///
  /// Android uses notification channels, categories and per-notification
  /// actions. iOS uses registered notification categories to determine which
  /// actions are displayed.
  Future<void> show(AppNotification notification) async {
    if (!_isSupportedPlatform) return;

    if (!_isInitialised) {
      await initialise();
    }

    AndroidNotificationDetails? androidDetails;
    DarwinNotificationDetails? iosDetails;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final channel = _channelFor(notification.type);

      androidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: channel.priority,
        icon: '@drawable/ic_notification',
        category: _categoryFor(notification.type),
        actions: notification.actions
            .map(_convertAction)
            .toList(growable: false),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      iosDetails = DarwinNotificationDetails(
        categoryIdentifier: _iosCategoryFor(notification.type),
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
      );
    }

    final payload = jsonEncode({
      'id': notification.id,
      'type': notification.type.name,
      ...notification.data,
    });

    await _plugin.show(
      id: _createNotificationId(notification.id),
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  /// Cancels a previously displayed system notification.
  Future<void> cancel(AppNotification notification) async {
    if (!_isSupportedPlatform) return;

    await _plugin.cancel(
      id: _createNotificationId(notification.id),
    );
  }

  /// Cancels all system notifications created by the application.
  Future<void> cancelAll() async {
    if (!_isSupportedPlatform) return;

    await _plugin.cancelAll();
  }

  /// Handles notification taps and foreground action selections.
  void _handleNotificationResponse(NotificationResponse response) {
    debugPrint(
      '[System notification] '
      'action=${response.actionId}, payload=${response.payload}',
    );

    responseNotifier.value = response;
  }

  /// Converts an application notification action to its Android equivalent.
  AndroidNotificationAction _convertAction(NotificationAction action) {
    return AndroidNotificationAction(
      action.type.name,
      action.label,
      showsUserInterface: true,
      cancelNotification: true,
    );
  }

  /// Creates the Android notification channels used by the application.
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

  /// Returns the Android notification channel for [type].
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

  /// Returns the Android system category for [type].
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

  /// Returns the registered iOS category identifier for [type].
  ///
  /// Notification types without interactive system actions do not require
  /// an iOS category and therefore return `null`.
  String? _iosCategoryFor(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequest:
        return _iosFriendRequestCategory;

      case NotificationType.followRequest:
        return _iosFollowRequestCategory;

      case NotificationType.activity:
        return _iosActivityCategory;

      case NotificationType.error:
        return _iosErrorCategory;

      case NotificationType.kudos:
      case NotificationType.comment:
      case NotificationType.commentReply:
      case NotificationType.commentLike:
      case NotificationType.friendAccepted:
      case NotificationType.follow:
      case NotificationType.followRequestAccepted:
        return null;
    }
  }

  /// Converts the application's string identifier into the integer identifier
  /// required by flutter_local_notifications.
  int _createNotificationId(String notificationId) {
    return notificationId.hashCode & 0x7fffffff;
  }
}

/// Handles notification actions selected while the app is in the background.
///
/// iOS background action handling also requires the notification plugin
/// registrant callback to be configured in `ios/Runner/AppDelegate.swift`.
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

// Android notification channels.

const _socialChannel = _NotificationChannelConfiguration(
  id: 'social_notifications',
  name: 'Social notifications',
  description: 'Friend requests, follows, comments and Kudos',
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

const _channels = [
  _socialChannel,
  _activityChannel,
  _importantChannel,
];

// iOS notification category identifiers.

const _iosFriendRequestCategory = 'friend_request';
const _iosFollowRequestCategory = 'follow_request';
const _iosActivityCategory = 'activity';
const _iosErrorCategory = 'error';

/// iOS notification categories and their associated interactive actions.
///
/// Unlike Android, iOS actions are registered ahead of time as part of a
/// notification category rather than attached dynamically to each
/// notification.
final List<DarwinNotificationCategory> _iosNotificationCategories = [
  DarwinNotificationCategory(
    _iosFriendRequestCategory,
    actions: [
      DarwinNotificationAction.plain(
        NotificationActionType.accept.name,
        'Accept',
        options: {
          DarwinNotificationActionOption.foreground,
        },
      ),
      DarwinNotificationAction.plain(
        NotificationActionType.decline.name,
        'Decline',
        options: {
          DarwinNotificationActionOption.foreground,
        },
      ),
    ],
  ),
  DarwinNotificationCategory(
    _iosFollowRequestCategory,
    actions: [
      DarwinNotificationAction.plain(
        NotificationActionType.accept.name,
        'Accept',
        options: {
          DarwinNotificationActionOption.foreground,
        },
      ),
      DarwinNotificationAction.plain(
        NotificationActionType.decline.name,
        'Decline',
        options: {
          DarwinNotificationActionOption.foreground,
        },
      ),
    ],
  ),
  DarwinNotificationCategory(
    _iosActivityCategory,
    actions: [
      DarwinNotificationAction.plain(
        NotificationActionType.pause.name,
        'Pause',
        options: {
          DarwinNotificationActionOption.foreground,
        },
      ),
      DarwinNotificationAction.plain(
        NotificationActionType.resume.name,
        'Resume',
        options: {
          DarwinNotificationActionOption.foreground,
        },
      ),
      DarwinNotificationAction.plain(
        NotificationActionType.stop.name,
        'Stop',
        options: {
          DarwinNotificationActionOption.foreground,
          DarwinNotificationActionOption.destructive,
        },
      ),
    ],
  ),
  DarwinNotificationCategory(
    _iosErrorCategory,
    actions: [
      DarwinNotificationAction.plain(
        NotificationActionType.retry.name,
        'Retry',
        options: {
          DarwinNotificationActionOption.foreground,
        },
      ),
      DarwinNotificationAction.plain(
        NotificationActionType.dismiss.name,
        'Dismiss',
        options: {
          DarwinNotificationActionOption.foreground,
        },
      ),
    ],
  ),
];

