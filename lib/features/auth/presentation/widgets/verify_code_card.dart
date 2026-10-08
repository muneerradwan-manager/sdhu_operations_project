import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../application/auth_cubit.dart';
import '../../data/auth_repository.dart';

/// How long before another code may be asked for.
///
/// Sixty because that is Supabase's own minimum between two letters to one
/// address. Set shorter, the button goes live while the server would still
/// refuse — and the reader presses an enabled button and is told off for it,
/// which reads as the app being broken rather than as a rule.
///
/// It also stops the button being pressed four times in six seconds by
/// somebody who has decided the first letter is not coming: that posts four
/// codes of which only the last one works, and leaves them typing an earlier
/// one out of whichever letter they happened to open.
const _resendCooldown = Duration(seconds: 60);

/// The gap between two boxes.
const _pinGap = 6.0;

/// The second half of creating an account: the digits that came by post.
///
/// A CODE rather than a link, which is the whole reason this screen exists. A
/// confirmation link mailed to a phone opens in whichever browser the phone
/// prefers — not in the app — so the account is confirmed somewhere the person
/// cannot see, while the screen they are actually looking at has not moved.
/// Digits carried back by hand close that gap with nothing to configure.
///
/// It replaces the form in place rather than pushing a screen. The address is
/// on it, the way back is on it, and the reader never leaves the page they
/// started on — a sign-up is one errand and should look like one.
class VerifyCodeCard extends StatefulWidget {
  const VerifyCodeCard({super.key, required this.email});

  /// The address the code went to. Shown, because the commonest reason a code
  /// never arrives is that it went somewhere with a letter missing.
  final String email;

  @override
  State<VerifyCodeCard> createState() => _VerifyCodeCardState();
}

class _VerifyCodeCardState extends State<VerifyCodeCard> {
  final _code = TextEditingController();
  final _focus = FocusNode();

  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    // The first code went out with the sign-up, so the clock starts at once —
    // otherwise "إعادة الإرسال" is live at the moment the first letter is still
    // in the air, which is exactly when it is pressed by mistake.
    _startCooldown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _ticker?.cancel();
    setState(() => _secondsLeft = _resendCooldown.inSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  void _submit() {
    if (_code.text.trim().length < kEmailCodeLength) {
      _focus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().verifyCode(_code.text);
  }

  void _resend() {
    _code.clear();
    _startCooldown();
    context.read<AuthCubit>().resendCode();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final glass = context.glass;
    final state = context.watch<AuthCubit>().state;
    final waiting = _secondsLeft > 0;
    final rejected = state.status == AuthStatus.error;

    return GlassCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.email, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l.authVerifyTitle,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.authVerifySubtitle(widget.email),
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),

          // One box per digit rather than one field for all of them.
          //
          // A code is copied across in glances — read two, type two, look back
          // — and a single field gives the eye nothing to keep its place
          // against. The boxes are the place: how many are filled and how many
          // are left is answered by looking, not by counting characters.
          //
          // Measured rather than fixed, because the count is a project setting
          // and can be ten: eight boxes at a comfortable size overflow a narrow
          // phone, and a row of digits clipped off the edge is worse than a row
          // of smaller ones.
          LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth;
              final width =
                  ((available - _pinGap * (kEmailCodeLength - 1)) /
                          kEmailCodeLength)
                      .clamp(30.0, 52.0);
              final theme = _pinTheme(width, text, scheme, glass);

              // The boxes fill LEFT to right even in Arabic: the digits are a
              // number, and a number does not turn round because the page it
              // sits on does. Left to the page's direction, the first digit
              // typed lands where the reader expects the last one.
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Pinput(
                  length: kEmailCodeLength,
                  controller: _code,
                  focusNode: _focus,
                  autofocus: true,
                  defaultPinTheme: theme,
                  focusedPinTheme: theme.copyDecorationWith(
                    border: Border.all(color: scheme.primary, width: 1.6),
                    color: scheme.primary.withValues(alpha: 0.06),
                  ),
                  submittedPinTheme: theme.copyDecorationWith(
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.35),
                    ),
                    color: scheme.primary.withValues(alpha: 0.10),
                  ),
                  errorPinTheme: theme.copyDecorationWith(
                    border: Border.all(color: scheme.error, width: 1.4),
                    color: scheme.error.withValues(alpha: 0.07),
                  ),
                  // Painted red by the state rather than by a validator: what
                  // makes this code wrong is the server's answer, which arrives
                  // long after anything the field could check for itself.
                  forceErrorState: rejected,
                  separatorBuilder: (_) => const SizedBox(width: _pinGap),
                  mainAxisAlignment: MainAxisAlignment.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  // The platform's own one-time-code autofill: on both phones
                  // this is what puts the digits in straight from the
                  // notification, without the reader leaving the app to go and
                  // read the letter.
                  autofillHints: const [AutofillHints.oneTimeCode],
                  hapticFeedbackType: HapticFeedbackType.lightImpact,
                  // The last digit submits. Having typed all of them, being
                  // asked to reach for a button as well is one motion too many.
                  onCompleted: (_) => _submit(),
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: state.isSubmitting ? null : _submit,
            child: state.isSubmitting
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      strokeCap: StrokeCap.round,
                      color: scheme.onPrimary,
                    ),
                  )
                : Text(l.authVerifyAction),
          ),
          const SizedBox(height: AppSpacing.sm),
          // The junk folder, said before it is asked about. It is where these
          // letters land often enough that leaving the reader to think of it
          // themselves costs more than one quiet line does.
          Text(
            l.authVerifyJunkHint,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: state.isSubmitting
                    ? null
                    : () => context.read<AuthCubit>().cancelVerification(),
                child: Text(l.authVerifyChangeEmail),
              ),
              TextButton(
                onPressed: waiting || state.isSubmitting ? null : _resend,
                child: Text(
                  waiting
                      ? l.authVerifyResendIn(_secondsLeft)
                      : l.authVerifyResend,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One box at rest: the same well every field in this app is cut into, at the
  /// size the row worked out it could afford.
  PinTheme _pinTheme(
    double width,
    TextTheme text,
    ColorScheme scheme,
    GlassTokens glass,
  ) => PinTheme(
    width: width,
    height: width * 1.22,
    textStyle: text.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    decoration: BoxDecoration(
      color: scheme.onSurface.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(AppRadius.xs),
      border: Border.all(color: glass.stroke),
    ),
  );
}
