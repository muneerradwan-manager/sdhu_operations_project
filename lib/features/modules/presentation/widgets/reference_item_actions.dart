import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../application/reference_data_cubit.dart';
import '../../domain/reference_item.dart';

/// Confirms, deletes, and reports the outcome. Shared by the list row and the
/// detail screen so an entry cannot be removed one way with a guard and another
/// way without one; the detail screen alone acts on the return value, since it
/// is the only caller left standing on a page for something that is now gone.
///
/// Returns true only when the row was actually removed.
Future<bool> confirmDeleteReferenceItem(
  BuildContext context,
  ReferenceItem item,
) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final cubit = context.read<ReferenceDataCubit>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l.commonDelete),
      content: Text(l.referenceDeleteConfirm(item.name.of(dialogContext))),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l.commonDelete),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  final result = await cubit.deleteItem(item.id);
  final message = switch (result.outcome) {
    ReferenceOutcome.ok => l.referenceItemDeleted,
    // The two an admin will actually hit: a hotel a module was built around,
    // and a name already on the list.
    ReferenceOutcome.inUse => l.referenceInUse,
    ReferenceOutcome.duplicate => l.referenceDuplicate,
    ReferenceOutcome.failed => result.message ?? '',
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  return result.isOk;
}
