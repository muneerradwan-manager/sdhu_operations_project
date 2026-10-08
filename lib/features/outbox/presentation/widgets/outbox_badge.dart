import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/offline/outbox.dart';
import '../../../../core/offline/outbox_entry.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_icons.dart';

/// Shows what the app is still holding, and disappears when it is holding
/// nothing.
///
/// Absent rather than empty on purpose. A permanent icon saying "0 waiting"
/// teaches people to stop reading it, and this is the one indicator in the app
/// that has to be believed the day it finally says something. On a normal day
/// in Makkah it is never seen at all; in Mina it is the answer to the only
/// question the man has.
///
/// Red when something was REFUSED — that needs a person — and the ordinary
/// accent when things are merely waiting, which needs nothing from anyone.
class OutboxBadge extends StatelessWidget {
  const OutboxBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // A screen built in isolation by a widget test has no queue behind it.
    if (!Outbox.isInstalled) return const SizedBox.shrink();

    final outbox = Outbox.instance;
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<OutboxEntry>>(
      stream: outbox.changes,
      initialData: outbox.entries,
      builder: (context, snap) {
        final entries = snap.data ?? const <OutboxEntry>[];
        if (entries.isEmpty) return const SizedBox.shrink();

        final blocked = entries.where((entry) => entry.isBlocked).length;
        final count = entries.length;

        return IconButton(
          tooltip: context.l10n.outboxTitle,
          onPressed: () => context.push(Routes.outbox),
          icon: Badge(
            label: Text(count > 99 ? '99+' : '$count'),
            backgroundColor: blocked > 0 ? scheme.error : scheme.tertiary,
            child: const Icon(AppIcons.outbox),
          ),
        );
      },
    );
  }
}
