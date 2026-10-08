import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../profile/domain/profile.dart';
import '../../application/employee_manage_cubit.dart';

/// Bottom sheet for toggling an employee's external designation and naming the
/// body he comes from. Not his post there — الوصف الوظيفي on the profile is
/// already that, and always was; see 0138.
Future<void> showExternalEditSheet(
  BuildContext context,
  EmployeeManageCubit cubit,
  Profile profile,
) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) =>
        _ExternalEditForm(cubit: cubit, profile: profile),
  );
}

class _ExternalEditForm extends StatefulWidget {
  const _ExternalEditForm({required this.cubit, required this.profile});
  final EmployeeManageCubit cubit;
  final Profile profile;

  @override
  State<_ExternalEditForm> createState() => _ExternalEditFormState();
}

class _ExternalEditFormState extends State<_ExternalEditForm> {
  late bool _isExternal = widget.profile.isExternal;
  late final _org = TextEditingController(
    text: widget.profile.externalOrganization,
  );

  @override
  void dispose() {
    _org.dispose();
    super.dispose();
  }

  void _save() {
    widget.cubit.saveExternal(
      isExternal: _isExternal,
      organization: _org.text.trim().isEmpty ? null : _org.text.trim(),
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.employeeExternalSaved)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.employeeEditExternalTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(AppIcons.external),
            title: Text(l.employeeIsExternal),
            subtitle: Text(l.employeeIsExternalHint),
            value: _isExternal,
            onChanged: (v) => setState(() => _isExternal = v),
          ),
          if (_isExternal) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _org,
              decoration: InputDecoration(
                labelText: l.employeeOrganization,
                prefixIcon: const Icon(AppIcons.organization),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: Text(l.commonSave)),
        ],
      ),
    );
  }
}
