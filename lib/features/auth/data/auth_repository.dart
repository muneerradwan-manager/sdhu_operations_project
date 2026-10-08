import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/offline/snapshots.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../notifications/data/push_service.dart';
import '../../prayer_times/application/prayer_scheduler.dart';
import '../domain/saved_account.dart';
import 'saved_accounts_store.dart';

/// Domain-level auth error carrying a user-presentable message.
class AuthFailure implements Exception {
  AuthFailure(this.message, {this.code});

  final String message;

  /// The machine-readable code, where the provider gave one.
  ///
  /// Carried because one of them changes what the app DOES rather than what it
  /// says: `email_not_confirmed` is not a failure to sign in, it is a sign-in
  /// interrupted halfway through creating the account — and the answer to it is
  /// the code box, not an apology.
  final String? code;

  bool get isEmailNotConfirmed => code == 'email_not_confirmed';

  /// The code was wrong, or it has expired. One sentence for both because the
  /// provider does not reliably separate them and the reader's next move is the
  /// same either way: type it again, or ask for another.
  bool get isBadCode =>
      code == 'otp_expired' ||
      code == 'otp_disabled' ||
      code == 'invalid_credentials' && _looksLikeToken;

  bool get _looksLikeToken => message.toLowerCase().contains('token');

  @override
  String toString() => message;
}

/// How many digits the posted code has.
///
/// **It must equal the project's own setting** — Supabase, Authentication →
/// Providers → Email → *Email OTP Length* (six by default, and settable from
/// six to ten). The two are not negotiated at runtime: nothing in the API
/// reports the length, so this number and that one are two copies of one fact
/// and the only thing keeping them in step is that they are written down.
///
/// Get it wrong and the failure is silent and total: the field refuses to
/// accept the code the reader is holding, and no message anywhere says why.
/// That is exactly how it was first shipped — six here, eight in the project.
const kEmailCodeLength = 8;

/// What creating an account produced.
enum SignUpOutcome {
  /// A session, straight away — the project is not asking for confirmation.
  signedIn,

  /// A six-digit code was posted to the address, and nothing is signed in until
  /// it comes back. See [AuthRepository.verifyEmailCode].
  awaitingCode,
}

/// Whether Google sign-in exists on the platform the app is running on.
///
/// `google_sign_in` declares four: android, ios, macos and web. Windows and
/// Linux have no implementation at all, so the button there fails on the tap
/// rather than at sign-in — no OAuth client of any kind changes that, because
/// there is no code to use one.
///
/// Web is excluded too. It is a supported platform for the package, but this
/// app hands `serverClientId` to it, which is the mobile arrangement; making
/// the browser flow work is its own piece of setup, and until it is done the
/// button would be an offer the app cannot keep.
///
/// A button that cannot work is worse than no button: it reads as the way in,
/// and the person who taps it concludes the app is broken rather than that this
/// door was never open here.
bool get isGoogleSignInSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

/// Wraps Supabase Auth. Supabase is the sole identity provider; Google is used
/// only to obtain an ID token that we hand to Supabase.
class AuthRepository {
  AuthRepository(this._accounts);

  /// The accounts this device may return to without a password. The repository
  /// owns it because every event that changes it is an auth event: a sign-in
  /// records one, a token rotation refreshes one, a sign-out removes one.
  final SavedAccountsStore _accounts;

  SavedAccountsStore get accounts => _accounts;

  User? get currentUser => supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  /// GoogleSignIn.initialize() may be called only once per process.
  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized(String webClientId) async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: webClientId);
    _googleInitialized = true;
  }

  /// Creates the account.
  ///
  /// Which of the two things happens next is the PROJECT's decision, not this
  /// app's: with email confirmation off, `signUp` hands back a session and the
  /// person is in; with it on, there is no session and a code has been posted
  /// to the address. The caller is told which rather than left to guess, and
  /// the app supports both — a project setting must not be something the client
  /// has to be rebuilt to follow.
  Future<SignUpOutcome> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email.trim(),
        password: password,
      );
      return response.session == null
          ? SignUpOutcome.awaitingCode
          : SignUpOutcome.signedIn;
    } on AuthException catch (e) {
      throw AuthFailure(e.message, code: e.code);
    }
  }

  /// Hands back the code that was posted to the address, which confirms the
  /// account and signs it in in one step.
  ///
  /// A CODE and not a link, and that is the whole point of this path. A link
  /// mailed to a phone opens in whichever browser the phone prefers, which is
  /// not the app: the account is confirmed somewhere the person cannot see, and
  /// they are left looking at a screen that has not moved. Six digits carried
  /// back by hand cross that gap without needing deep links to be configured on
  /// two platforms and a web build.
  ///
  /// Requires the project's "Confirm signup" template to contain `{{ .Token }}`.
  /// Left as the default `{{ .ConfirmationURL }}`, the letter arrives with a
  /// link and no code, and there is nothing for the reader to type.
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      await supabase.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.signup,
      );
      unawaited(_logAuthEvent('login'));
    } on AuthException catch (e) {
      throw AuthFailure(e.message, code: e.code);
    }
  }

  /// Posts another code to the same address.
  ///
  /// The first one goes astray often enough to matter — a filter, a typo caught
  /// too late, a letter that took nine minutes — and without this the only way
  /// out is to try to sign up again with an address that now exists.
  Future<void> resendEmailCode(String email) async {
    try {
      await supabase.auth.resend(type: OtpType.signup, email: email.trim());
    } on AuthException catch (e) {
      throw AuthFailure(e.message, code: e.code);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      unawaited(_logAuthEvent('login'));
    } on AuthException catch (e) {
      // `email_not_confirmed` comes back here and is not a wrong password: it
      // is somebody who signed up, closed the app before typing the code, and
      // has come back. Passed through with its code so the screen can offer
      // them the code box instead of telling them their details are wrong —
      // without that, an interrupted sign-up is an account nobody can ever
      // reach again.
      throw AuthFailure(e.message, code: e.code);
    }
  }

  Future<void> signInWithGoogle() async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    if (webClientId == null || webClientId.isEmpty) {
      throw AuthFailure('Google client id is not configured');
    }

    try {
      await _ensureGoogleInitialized(webClientId);

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw AuthFailure('No ID token returned from Google');
      }
      _logIdTokenAudience(idToken);

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      unawaited(_logAuthEvent('login'));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthFailure('cancelled');
      }
      throw AuthFailure(e.description ?? 'Google sign-in failed');
    } on AuthException catch (e) {
      throw AuthFailure(e.message, code: e.code);
    } on AuthFailure {
      rethrow;
    } catch (e) {
      // Surface any other error (e.g. platform/config issues) instead of
      // leaving the UI stuck in a submitting state.
      throw AuthFailure('Google sign-in failed: $e');
    }
  }

  /// Prints the `aud` and `iss` of the Google ID token, debug builds only.
  ///
  /// Supabase rejecting this exchange says only "Internal Server Error", which
  /// names nothing. The single fact that identifies the mismatch is the token
  /// AUDIENCE — the client id Google issued it for. It has to appear, exactly,
  /// as the Client ID of the Google provider in Supabase (or in its Authorized
  /// Client IDs). Printing it turns an opaque 500 into a string to compare.
  ///
  /// The claims only, never the token: an id_token is a credential, and a
  /// console log is not a private place.
  void _logIdTokenAudience(String idToken) {
    if (!AppLogger.enabled) return;
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) return;
      final payload = parts[1].padRight((parts[1].length + 3) ~/ 4 * 4, '=');
      final claims =
          jsonDecode(utf8.decode(base64Url.decode(payload)))
              as Map<String, dynamic>;
      AppLogger.info(
        'auth',
        "google id_token aud=${claims['aud']} iss=${claims['iss']} "
        "email_verified=${claims['email_verified']}",
      );
    } catch (e) {
      AppLogger.warn('auth', 'could not read id_token claims: $e');
    }
  }

  /// Updates the signed-in user's own password.
  Future<void> updatePassword(String newPassword) async {
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// Updates the signed-in user's own email address.
  ///
  /// Through the `admin-set-email` Edge Function rather than
  /// `auth.updateUser(email:)`: the auth-side self-service flow mails
  /// confirmation links to both addresses, and this mission hands accounts
  /// out in person — nothing is mailed, the address just changes. The
  /// function lets anyone in good standing change their own; a duplicate
  /// comes back as `email_taken` (auth enforces uniqueness itself).
  Future<void> updateEmail(String newEmail) async {
    final res = await supabase.functions.invoke(
      'admin-set-email',
      body: {'id': supabase.auth.currentUser!.id, 'email': newEmail.trim()},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }

  /// Writes a sign-in or sign-out line into the audit log.
  ///
  /// Sessions live in the auth schema, where the database's own audit
  /// triggers cannot see them, so the app reports these two events itself.
  /// Best-effort by construction: failing to log must never fail the door.
  Future<void> _logAuthEvent(String event) async {
    try {
      await supabase
          .rpc('log_auth_event', params: {'p_event': event})
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // The event is lost, the sign-in/out is not.
    }
  }

  /// Records the account that is signed in now, so it can be reopened later
  /// with a tap instead of a password.
  ///
  /// Called on every profile load rather than on sign-in alone, for two
  /// reasons: the name and the photo are only known once the profile is read,
  /// and they change afterwards — a card in the switcher showing last year's
  /// photo is a card the person hesitates over.
  Future<void> rememberCurrentAccount({String? name, String? photoUrl}) async {
    final session = supabase.auth.currentSession;
    final token = session?.refreshToken;
    if (session == null || token == null) return;

    await _accounts.remember(
      userId: session.user.id,
      email: session.user.email ?? '',
      refreshToken: token,
      name: name,
      photoUrl: photoUrl,
    );
  }

  /// Brings the stored token for the active account in line with the one
  /// Supabase is now using.
  ///
  /// Refresh tokens rotate — each renewal issues a new one and retires the old.
  /// Without this the entry saved at sign-in would quietly go dead in the hour
  /// after it was written, and the switcher would offer a door that no longer
  /// opens. Cheap to call: it writes only when the token actually changed.
  Future<void> syncStoredToken() async {
    final session = supabase.auth.currentSession;
    final token = session?.refreshToken;
    if (session == null || token == null) return;
    await _accounts.updateToken(session.user.id, token);
  }

  /// Opens a saved account, replacing the current session with it.
  ///
  /// Nothing is signed out. Supabase revokes a session the moment you ask it
  /// to sign out — even locally scoped, the call reaches the server — and a
  /// revoked session is one the switcher can never reopen. So the account being
  /// left keeps its session, and its stored token stays good; this is the whole
  /// reason switching and signing out are two different actions in this app.
  ///
  /// Push is dropped first, and it has to be first: [PushService.mute] deletes
  /// the row belonging to whoever is signed in, and after the swap that would
  /// be the account we just arrived at. The new one re-subscribes when the
  /// session settles.
  ///
  /// If the stored token has died — revoked elsewhere, or expired past its
  /// reuse window — Supabase ends the current session too, which is why the
  /// account is forgotten here: the app lands on the login screen, and the door
  /// that did not open is no longer offered.
  Future<void> switchTo(SavedAccount account) async {
    if (account.userId == currentUser?.id) return;

    await PushService.instance.mute().timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );

    try {
      await supabase.auth.setSession(account.refreshToken);
      unawaited(_logAuthEvent('login'));
    } on AuthException catch (e) {
      await _accounts.forget(account.userId);
      unawaited(PushService.instance.start());
      throw AuthFailure(e.message);
    } catch (e) {
      unawaited(PushService.instance.start());
      throw AuthFailure('$e');
    }
  }

  /// Removes an account from the switcher without touching the current session.
  Future<void> forgetAccount(String userId) => _accounts.forget(userId);

  /// Signs out, dropping this device's push subscriptions first: FCM topics
  /// outlive a session, and the next person to use the phone must not receive
  /// the last one's files. The device token row goes too — [PushService.mute]
  /// rather than just the topics, or pushes addressed to the departed account
  /// personally would keep reaching this phone, including after somebody else
  /// signs in on it.
  ///
  /// Neither step is allowed to hold the door shut. Unsubscribing talks to
  /// Firebase one topic at a time and on a bad connection simply does not come
  /// back; the sign-out itself talks to Supabase. A person who has decided to
  /// leave must leave, so each half is bounded, and if the server cannot be
  /// reached the session is cleared on the device anyway — a token that outlives
  /// its use is the lesser problem, and it expires on its own.
  ///
  /// The account also leaves the switcher, and that is not a preference: this
  /// call revokes the session on the server, so the token saved for it stops
  /// working. Keeping the card would be keeping a door that reports itself
  /// locked only after it has been tried. Whoever wants to come back without a
  /// password uses "switch account", which revokes nothing.
  Future<void> signOut() async {
    final uid = currentUser?.id;

    // The saved answers go with the session, and this is not tidiness.
    //
    // A phone in an operations room is shared: one man hands it to the next,
    // who signs in as himself. The snapshots hold what the FIRST man could see
    // — the staff directory with its telephone numbers, the roster of files he
    // serves in — and a second man reading that out of a cache is not a stale
    // screen, it is a leak. The keys carry the user id, so nothing would be
    // shown to the wrong person by accident; this makes it impossible rather
    // than unlikely, and it also means an account removed from a file cannot
    // keep reading it from disk.
    //
    // Unawaited and unguarded: it never throws (see [Snapshots.clear]), and
    // signing out must not wait on a disk.
    unawaited(Snapshots.instance?.clear() ?? Future.value());

    // While the session still exists to sign the line. Awaited but bounded:
    // it carries its own timeout, and a log must never hold the door shut.
    await _logAuthEvent('logout');

    await PushService.instance.mute().timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
    // The prayer alarms are local and would otherwise outlive the account that
    // asked for them: seventy of them, laid down in Android's own scheduler,
    // going off for a week in a phone that has been handed to somebody else.
    // The times on the widget stay — they are astronomy, not anybody's data.
    await PrayerScheduler.instance.stop();
    if (uid != null) await _accounts.forget(uid);

    try {
      await supabase.auth.signOut().timeout(const Duration(seconds: 8));
    } catch (_) {
      try {
        await supabase.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Out of options worth taking: the session listener is what moves the
        // app to the login screen, and a local clear is the last thing that
        // triggers it.
      }
    }
  }
}
