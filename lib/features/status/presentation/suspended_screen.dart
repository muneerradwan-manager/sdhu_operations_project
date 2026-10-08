import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/l10n/l10n_extension.dart';
import 'widgets/status_scaffold.dart';

class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return StatusScaffold(
      icon: Iconsax.slash,
      iconColor: Theme.of(context).colorScheme.error,
      title: l.statusSuspendedTitle,
      message: l.statusSuspendedMessage,
    );
  }
}
