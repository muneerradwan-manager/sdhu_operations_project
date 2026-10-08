import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../profile/domain/profile.dart';
import '../../application/employee_manage_cubit.dart';

/// Bottom sheet for setting a new email address on an employee's account.
///
/// The address is the login itself, so this is the password reset's sibling:
/// the employee signs in with the new address from now on, and is told in
/// person — nothing is mailed to either address.
Future<void> showEmployeeEmailSheet(
  BuildContext context,
  EmployeeManageCubit cubit,
  Profile profile,
) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => _EmailForm(cubit: cubit, profile: profile),
  );
}

class _EmailForm extends StatefulWidget {
  const _EmailForm({required this.cubit, required this.profile});
  final EmployeeManageCubit cubit;
  final Profile profile;

  @override
  State<_EmailForm> createState() => _EmailFormState();
}

class _EmailFormState extends State<_EmailForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final done = context.l10n.employeeEmailChanged;
    final saved = await widget.cubit.changeEmail(_email.text);
    if (!mounted) return;
    setState(() => _saving = false);
    // The cubit already surfaced the reason on the screen behind this sheet, so
    // leave the sheet standing with the typed address still in it.
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
                l.employeeEmailTitle(widget.profile.fullName),
                style: text.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.employeeEmailHint,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (widget.profile.email != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.profile.email!,
                  textDirection: TextDirection.ltr,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                decoration: InputDecoration(labelText: l.employeeEmailNew),
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.email],
                validator: (v) =>
                    Validators.isEmail(v ?? '') ? null : l.authInvalidEmail,
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
