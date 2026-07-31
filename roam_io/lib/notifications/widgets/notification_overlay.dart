import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/notification_action.dart';
import '../services/notification_service.dart';
import 'notification_banner.dart';

class NotificationOverlay extends StatefulWidget {
  final Widget child;

  const NotificationOverlay({
    super.key,
    required this.child,
  });

  @override
  State<NotificationOverlay> createState() =>
      _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  StreamSubscription<AppNotification>? _notificationSubscription;
  AppNotification? _currentNotification;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _notificationSubscription =
        NotificationService.instance.notifications.listen(
      _showNotification,
    );
  }

  void _showNotification(AppNotification notification) {
    _dismissTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _currentNotification = notification;
    });

    _dismissTimer = Timer(
      notification.displayDuration,
      () => _dismissNotification(notification.id),
    );
  }

  void _dismissNotification([String? expectedId]) {
    if (!mounted) return;

    // Prevent an old timer from dismissing a newer notification.
    if (expectedId != null &&
        _currentNotification?.id != expectedId) {
      return;
    }

    _dismissTimer?.cancel();
    _dismissTimer = null;

    setState(() {
      _currentNotification = null;
    });
  }

  void _handleAction(
    AppNotification notification,
    NotificationAction action,
  ) {
    NotificationService.instance.handleAction(
      notification: notification,
      action: action,
    );

    _dismissNotification(notification.id);
  }

  void _handleNotificationTap(AppNotification notification) {
    debugPrint(
      '[Notification selected] ${notification.id}',
    );

    // Future behaviour:
    // Navigate using notification.data.
    //
    // Example:
    // final senderId = notification.data['senderId'];
    // context.push('/profile/$senderId');

    _dismissNotification(notification.id);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: IgnorePointer(
              ignoring: _currentNotification == null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    reverseDuration:
                        const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slideAnimation = Tween<Offset>(
                        begin: const Offset(0, -0.35),
                        end: Offset.zero,
                      ).animate(animation);

                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: slideAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: _currentNotification == null
                        ? const SizedBox.shrink(
                            key: ValueKey('empty-notification'),
                          )
                        : NotificationBanner(
                            key: ValueKey(
                              _currentNotification!.id,
                            ),
                            notification: _currentNotification!,
                            onTap: () => _handleNotificationTap(
                              _currentNotification!,
                            ),
                            onDismiss: _dismissNotification,
                            onActionSelected: (action) {
                              _handleAction(
                                _currentNotification!,
                                action,
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}