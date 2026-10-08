import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/brand_header.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/password_field.dart';
import '../application/auth_cubit.dart';
import '../data/auth_repository.dart';
import 'widgets/google_button.dart';
import 'widgets/settings_menu_button.dart';
import 'widgets/verify_code_card.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Drives the live strength meter as the user types.
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      context.read<AuthCubit>().signUp(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(actions: const [SettingsMenuButton()]),
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
            }
            // Nothing to do when the code goes out the first time: the card
            // takes the screen's place and says so itself. This used to pop
            // back to the sign-in form with "check your email" in a snack bar,
            // which asked the reader to leave the app, find a letter, press a
            // link that opened a browser, and then work out for themselves
            // that they were supposed to come back and sign in.
          },
          builder: (context, state) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
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
                                  title: l.authRegisterTitle,
                                  subtitle: l.authRegisterSubtitle,
                                ),
                                const SizedBox(height: AppSpacing.xxl),
                                // The account is made and the code is in the
                                // post: the form has done its work and the six
                                // digits take its place, on the same page, with
                                // the address still in sight.
                                if (state.isVerifying)
                                  VerifyCodeCard(email: state.pendingEmail!)
                                else
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
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.newPassword,
                                          ],
                                          validator: (v) => (v ?? '').length < 8
                                              ? l.authPasswordTooShort
                                              : null,
                                        ),
                                        _StrengthMeter(value: _password.text),
                                        const SizedBox(height: AppSpacing.lg),
                                        PasswordField(
                                          controller: _confirm,
                                          label: l.authConfirmPassword,
                                          textInputAction: TextInputAction.done,
                                          onFieldSubmitted: (_) =>
                                              _submit(context),
                                          validator: (v) => v == _password.text
                                              ? null
                                              : l.authPasswordMismatch,
                                        ),
                                        const SizedBox(height: AppSpacing.xl),
                                        FilledButton(
                                          onPressed: state.isSubmitting
                                              ? null
                                              : () => _submit(context),
                                          child: state.isSubmitting
                                              ? SizedBox(
                                                  height: 22,
                                                  width: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.4,
                                                        strokeCap:
                                                            StrokeCap.round,
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.onPrimary,
                                                      ),
                                                )
                                              : Text(l.authSignUp),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Both hidden behind the code box. Signing in
                                // with Google, or going to the sign-in form,
                                // while six digits are waiting to be typed is
                                // a way to abandon an account halfway made
                                // without being told that is what it does.
                                if (!state.isVerifying) ...[
                                  if (isGoogleSignInSupported) ...[
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        l.authHaveAccount,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => context.pop(),
                                        child: Text(l.authSignIn),
                                      ),
                                    ],
                                  ),
                                ],
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

/// Three-segment password strength bar. Gives feedback while typing instead of
/// waiting for the form to reject the password on submit.
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.value});

  final String value;

  int get _score {
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'\d').hasMatch(value) && RegExp(r'[a-zA-Z]').hasMatch(value)) {
      score++;
    }
    return score.clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = _score;
    final colors = [scheme.error, scheme.secondary, scheme.primary];

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: value.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i < score
                              ? colors[score - 1]
                              : scheme.onSurfaceVariant.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
