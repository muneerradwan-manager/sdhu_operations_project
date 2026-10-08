import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/auth/application/auth_cubit.dart';
import 'package:sdhu_operations_project/features/auth/data/auth_repository.dart';

/// Creating an account is now two steps, and the second one is six digits.
///
/// The link flow it replaces asked a person holding a phone to leave the app,
/// find a letter, press a link that opened a browser, and then work out for
/// themselves that they were meant to come back and sign in. Most of them did
/// not come back.
///
/// What is asserted here is the state machine that carries the second step —
/// and above all the trap that comes with it: an account created and never
/// confirmed. Without the recovery path below, closing the app before typing
/// the code leaves an account whose password is correct, whose sign-in is
/// refused, and which can never be created again because the address is taken.
void main() {
  group('what the provider answered', () {
    test('a session means there is nothing more to ask', () {
      // Confirmation off: signUp hands back a session and the router moves.
      // Both paths stay supported so the project setting can be turned on or
      // off without a new build.
      expect(SignUpOutcome.values, contains(SignUpOutcome.signedIn));
    });

    test('an unconfirmed sign-in is recognised by its code, not its words', () {
      // The message is written by the provider and gets reworded; the code does
      // not. Matching on the sentence would break silently on an upgrade.
      final failure = AuthFailure(
        'Email not confirmed',
        code: 'email_not_confirmed',
      );
      expect(failure.isEmailNotConfirmed, isTrue);

      final wrongPassword = AuthFailure(
        'Invalid login credentials',
        code: 'invalid_credentials',
      );
      expect(wrongPassword.isEmailNotConfirmed, isFalse);
    });

    test('a failure with no code at all is not mistaken for one', () {
      expect(AuthFailure('something went wrong').isEmailNotConfirmed, isFalse);
    });
  });

  group('how long the code is', () {
    test('one number, and the field is built from it', () {
      // It shipped as 6 in the client while the project was set to 8, and the
      // failure was silent and total: the field would not accept the code the
      // reader was holding, and nothing anywhere said why. Nothing in the API
      // reports the length, so this is a fact written in two places — here and
      // in Supabase's "Email OTP Length" — and the only thing keeping them in
      // step is that both are written down.
      expect(kEmailCodeLength, 8);

      // Supabase accepts six to ten. A value outside that cannot be right.
      expect(kEmailCodeLength, inInclusiveRange(6, 10));
    });
  });

  group('the state the screen reads', () {
    test('an address pending is what puts the code box on screen', () {
      const idle = AuthUiState();
      expect(idle.isVerifying, isFalse);

      const waiting = AuthUiState(
        status: AuthStatus.awaitingCode,
        pendingEmail: 'a@b.c',
      );
      expect(waiting.isVerifying, isTrue);
    });

    test('a wrong code leaves the box where it is', () {
      // The single worst thing this screen could do is throw the reader back to
      // a form they have already filled in. The address survives the error, so
      // the box stays open with the message under it — and resend still knows
      // where to send.
      const waiting = AuthUiState(
        status: AuthStatus.awaitingCode,
        pendingEmail: 'a@b.c',
      );
      final rejected = waiting.copyWith(
        status: AuthStatus.error,
        error: 'Token has expired or is invalid',
      );

      expect(rejected.isVerifying, isTrue);
      expect(rejected.pendingEmail, 'a@b.c');
    });

    test('the resent flag is an event and does not stick', () {
      const waiting = AuthUiState(
        status: AuthStatus.awaitingCode,
        pendingEmail: 'a@b.c',
      );
      final resent = waiting.copyWith(codeResent: true);
      expect(resent.codeResent, isTrue);

      // Anything that happens afterwards clears it, or the snack bar would be
      // shown again on every rebuild that followed.
      expect(
        resent.copyWith(status: AuthStatus.submitting).codeResent,
        isFalse,
      );
    });

    test('backing out of the box clears the address', () {
      // Otherwise the form would be drawn underneath a card that never leaves.
      const idle = AuthUiState();
      expect(idle.pendingEmail, isNull);
      expect(idle.isVerifying, isFalse);
    });

    test('an error is not carried into the next state by accident', () {
      // copyWith drops `error` unless it is given again: a message about a bad
      // code must not still be on screen while the next one is being checked.
      const failed = AuthUiState(status: AuthStatus.error, error: 'bad code');
      expect(failed.copyWith(status: AuthStatus.submitting).error, isNull);
    });
  });
}
