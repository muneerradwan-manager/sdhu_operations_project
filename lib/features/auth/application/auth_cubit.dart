import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/auth_repository.dart';

enum AuthStatus {
  idle,
  submitting,

  /// The account exists and a six-digit code is in the post. Nothing is signed
  /// in, and the screen is showing the code box rather than the form.
  awaitingCode,

  error,
}

class AuthUiState extends Equatable {
  const AuthUiState({
    this.status = AuthStatus.idle,
    this.error,
    this.pendingEmail,
    this.codeResent = false,
  });

  final AuthStatus status;
  final String? error;

  /// The address the code went to.
  ///
  /// Kept in the state rather than in the screen because it survives what the
  /// screen does not: an error emitted while the code box is open must not lose
  /// which address is being confirmed, or the resend button has nothing to
  /// resend to.
  final String? pendingEmail;

  /// A fresh code has just gone out. Consumed by the screen to say so once,
  /// then cleared — it is an event, and it rides in the state only because
  /// there is nowhere else for it to ride.
  final bool codeResent;

  bool get isSubmitting => status == AuthStatus.submitting;

  /// Whether the screen should be showing the code box.
  ///
  /// True through the submitting and error states as well: typing a wrong code
  /// must leave the box where it is, with the message under it, rather than
  /// throwing the reader back to a form they have already filled in.
  bool get isVerifying => pendingEmail != null;

  AuthUiState copyWith({
    AuthStatus? status,
    String? error,
    String? pendingEmail,
    bool? codeResent,
  }) => AuthUiState(
    status: status ?? this.status,
    error: error,
    pendingEmail: pendingEmail ?? this.pendingEmail,
    codeResent: codeResent ?? false,
  );

  @override
  List<Object?> get props => [status, error, pendingEmail, codeResent];
}

/// Handles the sign-in / sign-up / Google actions on the auth screens.
/// The [SessionCubit] reacts to the resulting auth state change separately.
class AuthCubit extends SafeCubit<AuthUiState> {
  AuthCubit(this._repo) : super(const AuthUiState());

  final AuthRepository _repo;

  Future<void> signIn(String email, String password) async {
    emit(const AuthUiState(status: AuthStatus.submitting));
    try {
      await _repo.signInWithEmail(email: email, password: password);
      emit(const AuthUiState(status: AuthStatus.idle));
    } on AuthFailure catch (e) {
      // Not a wrong password: an account created and never confirmed, whose
      // owner has come back. The door is the code box, and refusing them with
      // "invalid credentials" would strand an account nobody can reach — the
      // password is right, and no amount of retyping it will help.
      if (e.isEmailNotConfirmed) {
        await _sendCodeTo(email.trim());
        return;
      }
      emit(AuthUiState(status: AuthStatus.error, error: e.message));
    }
  }

  Future<void> signUp(String email, String password) async {
    emit(const AuthUiState(status: AuthStatus.submitting));
    try {
      final outcome = await _repo.signUpWithEmail(
        email: email,
        password: password,
      );
      emit(switch (outcome) {
        // The project is not asking for confirmation — the session is already
        // running and the router is about to move. Both paths stay supported
        // so that turning the setting on or off does not need a new build.
        SignUpOutcome.signedIn => const AuthUiState(status: AuthStatus.idle),
        SignUpOutcome.awaitingCode => AuthUiState(
          status: AuthStatus.awaitingCode,
          pendingEmail: email.trim(),
        ),
      });
    } on AuthFailure catch (e) {
      emit(AuthUiState(status: AuthStatus.error, error: e.message));
    }
  }

  /// Hands the posted code back. On success there is a session and the router
  /// takes it from there.
  Future<void> verifyCode(String code) async {
    final email = state.pendingEmail;
    if (email == null) return;

    emit(state.copyWith(status: AuthStatus.submitting));
    try {
      await _repo.verifyEmailCode(email: email, code: code);
      emit(const AuthUiState(status: AuthStatus.idle));
    } on AuthFailure catch (e) {
      // pendingEmail survives, so the box stays open with the message under it.
      emit(state.copyWith(status: AuthStatus.error, error: e.message));
    }
  }

  /// Another code to the same address.
  Future<void> resendCode() async {
    final email = state.pendingEmail;
    if (email == null) return;

    emit(state.copyWith(status: AuthStatus.submitting));
    try {
      await _repo.resendEmailCode(email);
      emit(state.copyWith(status: AuthStatus.awaitingCode, codeResent: true));
    } on AuthFailure catch (e) {
      emit(state.copyWith(status: AuthStatus.error, error: e.message));
    }
  }

  /// Sends the first code to somebody who already has an unconfirmed account.
  Future<void> _sendCodeTo(String email) async {
    try {
      await _repo.resendEmailCode(email);
    } on AuthFailure {
      // The code box opens regardless. The account IS unconfirmed — that much
      // is known — and one they were sent earlier may still be in hand; sending
      // them back to a password form they will fill in identically is the one
      // answer that leads nowhere.
    }
    emit(AuthUiState(status: AuthStatus.awaitingCode, pendingEmail: email));
  }

  /// Back out of the code box to the form — a wrong address typed, or a change
  /// of mind. The account stays; signing up again with the same address would
  /// be refused, so the way back in is the door above.
  void cancelVerification() => emit(const AuthUiState(status: AuthStatus.idle));

  Future<void> signInWithGoogle() async {
    emit(const AuthUiState(status: AuthStatus.submitting));
    try {
      await _repo.signInWithGoogle();
      emit(const AuthUiState(status: AuthStatus.idle));
    } on AuthFailure catch (e) {
      if (e.message == 'cancelled') {
        emit(const AuthUiState(status: AuthStatus.idle));
        return;
      }
      emit(AuthUiState(status: AuthStatus.error, error: e.message));
    }
  }

  void clearError() => emit(
    state.copyWith(
      status: state.isVerifying ? AuthStatus.awaitingCode : AuthStatus.idle,
    ),
  );
}
