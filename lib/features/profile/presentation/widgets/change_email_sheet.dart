import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/error_text.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../auth/application/session_cubit.dart';
import '../../../auth/data/auth_repository.dart';

/// Bottom sheet for changing one's own email address — the login itself.
///
/// No confirmation mail goes to either address (see AuthRepository.updateEmail
/// for why); the change is immediate, and the session stays signed in.
Future<void> showChangeEmailSheet(BuildContext context) {
  final repo = context.read<AuthRepository>();
  final session = context.read<SessionCubit>();
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => _ChangeEmailForm(repo: repo, session: session),
  );
}

class _ChangeEmailForm extends StatefulWidget {
  const _ChangeEmailForm({required this.repo, required this.session});
  final AuthRepository repo;
  final SessionCubit session;

  @override
  State<_ChangeEmailForm> createState() => _ChangeEmailFormState();
}

class _ChangeEmailFormState extends State<_ChangeEmailForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final l = context.l10n;
    try {
      await widget.repo.updateEmail(_email.text);
      // The profile screen shows the mirror; read it back so the new address
      // is on screen the moment the sheet closes.
      await widget.session.reload();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.myProfileEmailChanged)));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(friendlyErrorL(l, e.toString()))),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = widget.session.state.profile?.email;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.myProfileChangeEmail,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (current != null) ...[
              const SizedBox(height: 8),
              Text(
                current,
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              decoration: InputDecoration(labelText: l.myProfileNewEmail),
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              validator: (v) =>
                  Validators.isEmail(v ?? '') ? null : l.authInvalidEmail,
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
