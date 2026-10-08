import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_icons.dart';
import '../../data/notifications_repository.dart';
import '../../domain/app_notification.dart';

/// App-bar bell showing a live unread-count badge and opening the inbox.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _stream = NotificationsRepository().streamMine();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<AppNotification>>(
      stream: _stream,
      builder: (context, snap) {
        final unread = (snap.data ?? const <AppNotification>[])
            .where((n) => !n.isRead)
            .length;
        return IconButton(
          tooltip: context.l10n.navNotifications,
          onPressed: () => context.push(Routes.notifications),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            backgroundColor: scheme.error,
            child: const Icon(AppIcons.notifications),
          ),
        );
      },
    );
  }
}
