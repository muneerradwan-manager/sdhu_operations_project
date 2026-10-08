import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/logging/error_reporting.dart';
import '../../../core/offline/snapshots.dart';
import '../../notifications/data/push_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/profile_enums.dart';
import '../data/auth_repository.dart';

enum SessionStatus {
  unknown,
  unauthenticated,
  incomplete, // signed in, profile not yet submitted
  pending,
  rejected,
  suspended,
  approved,
}

class SessionState extends Equatable {
  const SessionState({
    this.status = SessionStatus.unknown,
    this.profile,
    this.permissions = const {},
    this.loadFailed = false,
    this.restoredAt,
  });

  final SessionStatus status;
  final Profile? profile;
  final Set<String> permissions;

  /// True when resolving the session at startup failed (network down, server
  /// unreachable) and there is nothing older on screen to fall back to. The
  /// splash reads this to offer a retry instead of an endless progress bar.
  final bool loadFailed;

  /// When this session was last true, if it was restored from disk rather than
  /// fetched.
  ///
  /// Null on a live resolution. Carried rather than reduced to a flag for the
  /// reason [Snapshots] gives: "a saved copy" makes the reader guess how old,
  /// and the age is the only thing they need in order to decide whether to
  /// trust what they are about to do with it.
  ///
  /// It matters more here than anywhere else it appears, because what is stale
  /// is the PERMISSION SET — the thing that decides which doors are drawn. Not
  /// which doors OPEN: every write still goes to a server that enforces its own
  /// row rules, so a grant revoked while this phone was in a bag buys nobody
  /// anything except a refusal when the signal returns.
  final DateTime? restoredAt;

  bool get isAdmin => profile?.isAdmin ?? false;
  bool can(String code) => isAdmin || permissions.contains(code);

  /// Whether seasons are this person's business at all.
  ///
  /// `seasons.view` is the door, and every other seasons action requires it as
  /// a prerequisite (enforced by the DB, see 0073) — so asking for the door
  /// alone is asking for all of them.
  ///
  /// A getter rather than a check written out at each call site, because it is
  /// asked in two places that must not drift: the dashboard decides whether to
  /// show the door, and the router decides whether the door opens. A rule kept
  /// in one of those places only is decoration.
  bool get canSeeSeasons => can(PermissionCodes.seasonsView);

  /// Whether one may send a notification of any of the three blast radii —
  /// what decides if a compose button appears at all.
  bool get canSendAnyNotification =>
      can(PermissionCodes.notificationsSend) ||
      can(PermissionCodes.notificationsBroadcastModule) ||
      can(PermissionCodes.notificationsBroadcastAll);

  SessionState copyWith({
    SessionStatus? status,
    Profile? profile,
    Set<String>? permissions,
    bool? loadFailed,
    DateTime? restoredAt,
    bool clearRestoredAt = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      permissions: permissions ?? this.permissions,
      loadFailed: loadFailed ?? this.loadFailed,
      restoredAt: clearRestoredAt ? null : (restoredAt ?? this.restoredAt),
    );
  }

  @override
  List<Object?> get props => [
    status,
    profile,
    permissions,
    loadFailed,
    restoredAt,
  ];
}

/// Owns the app's authenticated session: reacts to Supabase auth events,
/// loads the profile, and derives the routing status.
class SessionCubit extends SafeCubit<SessionState> {
  SessionCubit(this._auth, this._profiles, {Stream<void>? reconnects})
    : super(const SessionState()) {
    _sub = _auth.authStateChanges.listen(_onAuthChanged);

    // A session restored from disk is a session that has not been checked, and
    // the moment the radio comes back is the moment to check it. Without this,
    // a man who started the app in a dead spot carries yesterday's permissions
    // until he closes and reopens it — which nobody does mid-shift.
    //
    // Only when there is something to correct: a live session re-fetching its
    // own profile every time a wifi flickers is work done to arrive at the
    // answer already on screen. The queue's own reconnect handler is what sends
    // the WRITES; this one only makes the session catch up.
    //
    // `onError` for the reason the outbox gives: an error on a stream handed in
    // as an argument, with nobody handling it, escapes to the framework and is
    // reported as a crash. Watching the network must never be why the app looks
    // broken.
    _reconnectSub = reconnects?.listen(
      (_) {
        if (state.restoredAt != null || state.loadFailed) unawaited(reload());
      },
      onError: (Object _) {},
      cancelOnError: false,
    );

    // Handle a session that already exists at startup.
    if (_auth.currentUser != null) {
      reload();
    } else {
      emit(const SessionState(status: SessionStatus.unauthenticated));
    }
  }

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  late final StreamSubscription<AuthState> _sub;
  StreamSubscription<void>? _reconnectSub;

  /// The account the current session state was loaded for — set the moment a
  /// load starts, not when it finishes, so that events arriving while the first
  /// one is still in flight can be recognised as redundant.
  ///
  /// Cleared when a load fails, so the next event retries rather than trusting
  /// a resolution that never happened.
  String? _loadedUserId;

  /// The load currently running, if one is. A second caller arriving while it
  /// is in flight waits on it instead of starting a fetch of its own — the
  /// answer it would arrive at is the one already on its way.
  ///
  /// Belt to [_loadedUserId]'s braces: that one recognises the specific auth
  /// events startup raises twice, this one holds for any two callers that
  /// overlap, whatever asked them to.
  Future<void>? _inFlight;

  /// Who is signed in, whatever state their account is in.
  ///
  /// Not on [SessionState], which carries the profile — and an account that has
  /// not filled one in yet still has an id. The router needs that id to tell
  /// "still adding a second account" from "the second account has arrived".
  String? get userId => _auth.currentUser?.id;

  Future<void> _onAuthChanged(AuthState event) async {
    final session = event.session;
    if (session == null) {
      _loadedUserId = null;
      CrashReporting.setUser(null);
      emit(const SessionState(status: SessionStatus.unauthenticated));
      return;
    }

    // A token rotating for the person already on screen changes nothing about
    // them — only the credential the account switcher has to hold. Refetching
    // the profile and the permission set every time one expires would be work
    // done hourly to arrive at the answer already showing.
    //
    // The same event announces a switch to a different account, because that is
    // what `setSession` does under it; the user id is what tells the two apart.
    if (event.event == AuthChangeEvent.tokenRefreshed &&
        session.user.id == _loadedUserId) {
      await _auth.syncStoredToken();
      return;
    }

    // Startup announces the restored session on this stream as well, and the
    // constructor has already begun loading it — this event is the same news
    // arriving twice. Without this the app opened with three identical profile
    // fetches racing each other: the constructor's, this one, and the refresh
    // that rotates the restored token on the way in.
    //
    // Compared against the id a load was *started* for, not the loaded profile:
    // at the moment this arrives the first fetch is still in flight, and an
    // account that has not filled in a profile yet never has one to compare to.
    if (event.event == AuthChangeEvent.initialSession &&
        session.user.id == _loadedUserId) {
      return;
    }

    await reload();
  }

  /// Re-fetch the profile and permissions and recompute status.
  ///
  /// Never throws: at startup a failure would otherwise escape to the zone and
  /// leave the splash up forever with nothing to tap; on a later refresh the
  /// state already on screen is better than a crash, so it is kept.
  ///
  /// Callers who arrive while one is already running join it rather than adding
  /// a second round trip for the same answer.
  Future<void> reload() {
    return _inFlight ??= _runReload().whenComplete(() => _inFlight = null);
  }

  Future<void> _runReload() async {
    final uid = _auth.currentUser?.id;
    if (uid == null) {
      _loadedUserId = null;
      emit(const SessionState(status: SessionStatus.unauthenticated));
      return;
    }

    // A retry from the splash: put the progress bar back while it runs.
    if (state.loadFailed) {
      emit(state.copyWith(loadFailed: false));
    }

    // Claimed before the first await, so that the auth events this same session
    // is about to raise can see a load is already under way for it.
    _loadedUserId = uid;

    // Named on every crash report from here on. The id alone, and set at the
    // point the session is known rather than at sign-in, so that a restored
    // session — the ordinary case, since nobody signs in again each morning of
    // the season — carries it too.
    CrashReporting.setUser(uid);

    try {
      await _reload();
    } catch (_) {
      _loadedUserId = null;
      if (state.status == SessionStatus.unknown) {
        // Startup with nothing resolved yet — surface a retryable failure.
        emit(state.copyWith(loadFailed: true));
      }
      // Otherwise: keep what is showing; the person can refresh again.
    }
  }

  Future<void> _reload() async {
    final read = await _profiles.fetchMine();
    final profile = read.data;

    // Recorded here rather than at sign-in: this is the first point at which
    // the account has a face and a name to be recognised by in the switcher,
    // and it runs again whenever either of them changes. Not awaited — the
    // screen the person is waiting for does not depend on it.
    unawaited(
      _auth.rememberCurrentAccount(
        name: profile?.fullName,
        photoUrl: profile?.photoUrl,
      ),
    );

    if (profile == null) {
      // Row may not be visible for a beat right after signup; treat as incomplete.
      emit(const SessionState(status: SessionStatus.incomplete));
      return;
    }

    final status = switch (profile.accountStatus) {
      AccountStatus.incomplete => SessionStatus.incomplete,
      AccountStatus.pending => SessionStatus.pending,
      AccountStatus.rejected => SessionStatus.rejected,
      AccountStatus.approved =>
        profile.isSuspended ? SessionStatus.suspended : SessionStatus.approved,
    };

    var permissions = const <String>{};
    var restoredAt = read.savedAt;
    if (status == SessionStatus.approved && !profile.isAdmin) {
      final grants = await _loadPermissions();
      permissions = grants.data;
      // The older of the two, because the session is only as fresh as its
      // stalest half — and because the profile can come off disk while the
      // grants come live, or the reverse, depending on which call the network
      // died between.
      restoredAt = _older(restoredAt, grants.savedAt);
    }

    emit(
      SessionState(
        status: status,
        profile: profile,
        permissions: permissions,
        restoredAt: restoredAt,
      ),
    );

    // Register this device for push once the user has full access.
    //
    // Skipped on a restored session: it is a network call, it would fail, and
    // the token it registers is one the server already has from the last time
    // this device was online.
    if (status == SessionStatus.approved && restoredAt == null) {
      unawaited(PushService.instance.start());
    }
  }

  static DateTime? _older(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  /// Throws on failure rather than returning an empty set: an error here used
  /// to silently strip every section card off the home screen until the next
  /// reload. Letting it propagate turns it into the same retryable failure as
  /// a profile fetch that never arrived.
  ///
  /// Kept on disk for the same reason the profile is: without it a session that
  /// survived a dead network would open every door for an administrator and
  /// none for anybody else, which is a worse answer than not opening at all.
  Future<Cached<Set<String>>> _loadPermissions() {
    final uid = _auth.currentUser?.id;
    return readWithSnapshot(
      key: 'session.permissions.$uid',
      fetch: () => Supabase.instance.client.rpc('my_permissions'),
      parse: (rows) => {
        for (final code in (rows as List?) ?? const []) code as String,
      },
    );
  }

  @override
  Future<void> close() {
    _sub.cancel();
    _reconnectSub?.cancel();
    return super.close();
  }
}
