import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
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

class _NotificationOverlayState
    extends State<NotificationOverlay> {

  StreamSubscription<AppNotification>? _subscription;

  AppNotification? _currentNotification;

  @override
  void initState() {
    super.initState();

    _subscription = NotificationService.instance.notifications.listen(
      (notification) {

        setState(() {
          _currentNotification = notification;
        });

        Future.delayed(const Duration(seconds: 3), () {

          if (!mounted) return;

          setState(() {
            _currentNotification = null;
          });

        });

      },
    );
  }

  @override
  void dispose() {

    _subscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Stack(

      children: [

        widget.child,

        if (_currentNotification != null)

          SafeArea(

            child: Padding(

              padding: const EdgeInsets.all(16),

              child: NotificationBanner(
                notification: _currentNotification!,
              ),

            ),

          ),

      ],

    );
  }
}