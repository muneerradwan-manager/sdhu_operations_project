import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import 'widgets/status_scaffold.dart';

class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return StatusScaffold(
      icon: AppIcons.pending,
      iconColor: Theme.of(context).colorScheme.secondary,
      title: l.statusPendingTitle,
      message: l.statusPendingMessage,
    );
  }
}
