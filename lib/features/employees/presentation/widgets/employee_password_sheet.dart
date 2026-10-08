import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/password_field.dart';
import '../../../profile/domain/profile.dart';
import '../../application/employee_manage_cubit.dart';

/// Bottom sheet for setting a new password on an employee's account.
///
/// A reset, not a change: the administration is not asked for the old password
/// because it does not have it — that is the situation this exists for. The
/// employee is told the new one in person; nothing is mailed to them.
Future<void> showEmployeePasswordSheet(
  BuildContext context,
  EmployeeManageCubit cubit,
  Profile profile,
) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => _PasswordForm(cubit: cubit, profile: profile),
  );
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm({required this.cubit, required this.profile});
  final EmployeeManageCubit cubit;
  final Profile profile;

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final done = context.l10n.employeePasswordChanged;
    final saved = await widget.cubit.changePassword(_password.text);
    if (!mounted) return;
    setState(() => _saving = false);
    // The cubit already surfaced the reason on the screen behind this sheet, so
    // leave the sheet standing with the typed password still in it.
    if (!saved) return;

    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(done)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.employeePasswordTitle(widget.profile.fullName),
                style: text.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.employeePasswordHint,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _password,
                label: l.employeePasswordNew,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v ?? '').length < 8 ? l.authPasswordTooShort : null,
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: _confirm,
                label: l.employeePasswordConfirm,
                validator: (v) =>
                    v == _password.text ? null : l.authPasswordMismatch,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
