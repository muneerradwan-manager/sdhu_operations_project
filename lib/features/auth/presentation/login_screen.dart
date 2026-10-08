import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/brand_header.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/password_field.dart';
import '../application/auth_cubit.dart';
import '../application/session_cubit.dart';
import '../data/auth_repository.dart';
import '../domain/saved_account.dart';
import 'widgets/google_button.dart';
import 'widgets/saved_accounts_list.dart';
import 'widgets/settings_menu_button.dart';
import 'widgets/verify_code_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.addingForUserId});

  /// The id of the account that opened this screen to add a second one, if
  /// that is why it is open.
  ///
  /// It changes what the screen is: with a session already running there are no
  /// saved accounts to offer — the person came here past them — and there is a
  /// way back, because cancelling leaves them where they were rather than
  /// signed out.
  final String? addingForUserId;

  bool get isAddingAccount => addingForUserId != null;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// The account a tap is currently opening. Locks the picker while the swap
  /// is in flight.
  String? _switching;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      context.read<AuthCubit>().signIn(_email.text, _password.text);
    }
  }

  /// Opens a saved account. The router takes it from there — the session
  /// changing is what moves the app off this screen.
  Future<void> _open(SavedAccount account) async {
    final l = context.l10n;
    final auth = context.read<AuthRepository>();

    setState(() => _switching = account.userId);
    try {
      await auth.switchTo(account);
    } on AuthFailure {
      if (!mounted) return;
      // Named rather than relayed: what Supabase says about a refresh token is
      // written for whoever wrote the call, and the account has already been
      // dropped from the list by the time this is read.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.accountsExpired)));
    } finally {
      if (mounted) setState(() => _switching = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return BlocListener<SessionCubit, SessionState>(
      // Leaving is done here rather than left to the router's redirect, because
      // this screen was pushed onto a live session and go_router does not
      // re-decide an imperatively pushed route when the session changes under
      // it: the second account would sign in and the sign-in form would stay
      // exactly where it was, looking like the button had done nothing.
      //
      // `go` and not `pop`: the stack behind this belongs to the account that
      // has just been left, and the new one starts at the top.
      listener: (context, _) {
        if (!widget.isAddingAccount) return;
        final arrived = context.read<SessionCubit>().userId;
        if (arrived != null && arrived != widget.addingForUserId) {
          context.go(Routes.home);
        }
      },
      child: _scaffold(context, l),
    );
  }

  Widget _scaffold(BuildContext context, AppLocalizations l) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        actions: widget.isAddingAccount ? null : const [SettingsMenuButton()],
      ),
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthUiState>(
          listener: (context, state) {
            if (state.status == AuthStatus.error && state.error != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(friendlyError(context, state.error))),
                );
            } else if (state.codeResent) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l.authVerifyResent)));
            } else if (state.status == AuthStatus.awaitingCode) {
              // The password was right and the account was never confirmed:
              // somebody who signed up, closed the app before typing the code,
              // and has come back. Said out loud, because otherwise the form
              // they filled in correctly appears to have been swapped for a
              // different question with no explanation.
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(l.authVerifyUnconfirmed)),
                );
            }
          },
          builder: (context, state) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  // Keeps the submit button reachable above the keyboard.
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 36,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: staggered([
                                const SizedBox(height: AppSpacing.lg),
                                BrandHeader(
                                  title: widget.isAddingAccount
                                      ? l.accountsAddTitle
                                      : l.authLoginTitle,
                                  subtitle: widget.isAddingAccount
                                      ? l.accountsAddSubtitle
                                      : l.authLoginSubtitle,
                                ),
                                const SizedBox(height: AppSpacing.xxl),
                                // Above the form, because for anyone who has
                                // been here before this IS the way in, and a
                                // shortcut under the thing it replaces is a
                                // shortcut found after the long way round.
                                if (!widget.isAddingAccount &&
                                    !state.isVerifying)
                                  _SavedAccounts(
                                    busyUserId: _switching,
                                    onSelect: _open,
                                  ),
                                // An account made and never confirmed: the six
                                // digits take the form's place, here as on the
                                // sign-up screen, so the two doors into the
                                // same step look like one step.
                                if (state.isVerifying)
                                  VerifyCodeCard(email: state.pendingEmail!)
                                else
                                  // The credentials sit on their own pane so
                                  // the form reads as one contained task.
                                  GlassCard(
                                    radius: AppRadius.lg,
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        TextFormField(
                                          controller: _email,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.email,
                                          ],
                                          decoration: InputDecoration(
                                            labelText: l.authEmail,
                                            prefixIcon: const Icon(
                                              AppIcons.email,
                                            ),
                                          ),
                                          validator: (v) =>
                                              Validators.isEmail(v ?? '')
                                              ? null
                                              : l.authInvalidEmail,
                                        ),
                                        const SizedBox(height: AppSpacing.lg),
                                        PasswordField(
                                          controller: _password,
                                          label: l.authPassword,
                                          textInputAction: TextInputAction.done,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          onFieldSubmitted: (_) =>
                                              _submit(context),
                                          validator: (v) => (v ?? '').isEmpty
                                              ? l.commonRequired
                                              : null,
                                        ),
                                        const SizedBox(height: AppSpacing.xl),
                                        FilledButton(
                                          onPressed: state.isSubmitting
                                              ? null
                                              : () => _submit(context),
                                          child: state.isSubmitting
                                              ? const _ButtonSpinner()
                                              : Text(l.authSignIn),
                                        ),
                                      ],
                                    ),
                                  ),
                                // The divider goes with the button: "or" with
                                // nothing after it divides one thing from
                                // nothing.
                                if (isGoogleSignInSupported &&
                                    !state.isVerifying) ...[
                                  const SizedBox(height: AppSpacing.xl),
                                  _OrDivider(label: l.authOrContinueWith),
                                  const SizedBox(height: AppSpacing.xl),
                                  GoogleButton(
                                    label: l.authGoogle,
                                    onPressed: state.isSubmitting
                                        ? null
                                        : () => context
                                              .read<AuthCubit>()
                                              .signInWithGoogle(),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.lg),
                                // "No account? Sign up" is the wrong offer to
                                // somebody who has one and is three digits from
                                // reaching it.
                                if (!state.isVerifying)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        l.authNoAccount,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      TextButton(
                                        // The exemption has to travel with the
                                        // link: registering a second account is
                                        // still done from inside a live
                                        // session, and a plain /register would
                                        // be sent straight back home.
                                        onPressed: () => context.push(
                                          widget.isAddingAccount
                                              ? '${Routes.register}'
                                                    '?add=${widget.addingForUserId}'
                                              : Routes.register,
                                        ),
                                        child: Text(l.authSignUp),
                                      ),
                                    ],
                                  ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The accounts this device can open without a password, if there are any.
///
/// Draws nothing at all when there are none — a heading over an empty space is
/// a promise the device cannot keep, and the first person to use a phone should
/// see the plain sign-in form and nothing else.
class _SavedAccounts extends StatelessWidget {
  const _SavedAccounts({required this.busyUserId, required this.onSelect});

  final String? busyUserId;
  final ValueChanged<SavedAccount> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<List<SavedAccount>>(
      valueListenable: context.read<AuthRepository>().accounts,
      builder: (context, accounts, _) {
        if (accounts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.accountsSaved,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.accountsSavedHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            SavedAccountsList(
              accounts: accounts,
              busyUserId: busyUserId,
              onSelect: onSelect,
            ),
            const SizedBox(height: AppSpacing.lg),
            _OrDivider(label: l.authOrContinueWith),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    width: 22,
    child: CircularProgressIndicator(
      strokeWidth: 2.4,
      strokeCap: StrokeCap.round,
      color: Theme.of(context).colorScheme.onPrimary,
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 12, letterSpacing: 0.4),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
