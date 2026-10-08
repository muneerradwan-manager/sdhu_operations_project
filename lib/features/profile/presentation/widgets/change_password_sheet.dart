import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/password_field.dart';
import '../../../auth/data/auth_repository.dart';

Future<void> showChangePasswordSheet(BuildContext context) {
  final repo = context.read<AuthRepository>();
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => _ChangePasswordForm(repo: repo),
  );
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm({required this.repo});
  final AuthRepository repo;

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await widget.repo.updatePassword(_password.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.myProfilePasswordChanged)),
        );
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.myProfileChangePassword,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _password,
              label: l.myProfileNewPassword,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v ?? '').length < 8 ? l.authPasswordTooShort : null,
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _confirm,
              label: l.myProfileConfirmPassword,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  v == _password.text ? null : l.authPasswordMismatch,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        strokeCap: StrokeCap.round,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Text(l.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
