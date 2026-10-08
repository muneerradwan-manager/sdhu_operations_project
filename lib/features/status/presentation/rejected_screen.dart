import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_icons.dart';
import '../../auth/application/session_cubit.dart';
import 'widgets/status_scaffold.dart';

class RejectedScreen extends StatelessWidget {
  const RejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reason = context.select<SessionCubit, String?>(
      (c) => c.state.profile?.rejectionReason,
    );

    return StatusScaffold(
      icon: AppIcons.rejected,
      iconColor: Theme.of(context).colorScheme.error,
      title: l.statusRejectedTitle,
      message: l.statusRejectedMessage,
      detail: (reason != null && reason.isNotEmpty)
          ? l.statusRejectedReason(reason)
          : null,
      action: FilledButton.icon(
        onPressed: () => context.go(Routes.completeProfile),
        icon: const Icon(AppIcons.edit, size: 18),
        label: Text(l.statusEditAndResubmit),
      ),
    );
  }
}
