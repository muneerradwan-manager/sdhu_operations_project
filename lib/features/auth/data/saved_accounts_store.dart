import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/logging/app_logger.dart';
import '../domain/saved_account.dart';

/// The accounts this device can switch between, and their refresh tokens.
///
/// A [ValueNotifier] rather than a cubit because there is no state to derive:
/// the list is the state, it is read once at startup, and both screens that
/// show it want exactly the same thing. It notifies so the picker on the login
/// screen updates the moment an account is added or forgotten.
///
/// Storage is the platform keystore — Android Keystore, iOS Keychain, DPAPI on
/// Windows — and not shared preferences, where the app's own Supabase session
/// lives. A refresh token opens the account on its own; a file readable by a
/// backup tool or a rooted device is not where several of them should sit.
class SavedAccountsStore extends ValueNotifier<List<SavedAccount>> {
  SavedAccountsStore({FlutterSecureStorage? storage})
    // macOS option: see SecureSessionStorage._storage.
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          ),
      super(const []);

  static const _key = 'saved_accounts_v1';

  /// How long an account may go untouched before it stops being offered.
  ///
  /// A Supabase refresh token does not expire on its own, so without this the
  /// account of somebody who used the device once, a year ago, would still be
  /// one tap from open. The person who still wants it signs in again; the
  /// person who never comes back leaves nothing behind.
  static const staleAfter = Duration(days: 30);

  /// How many accounts the picker will hold. Past this the least recently used
  /// is dropped — a switcher is for the two or three accounts somebody moves
  /// between, and a list long enough to scroll is a list nobody reads.
  static const maxAccounts = 5;

  final FlutterSecureStorage _storage;

  /// Reads the stored accounts and drops the stale ones. Call once at startup.
  ///
  /// Never throws. The keystore can fail to open — a known Android case after a
  /// restore onto a different device, where the keys no longer decrypt — and
  /// the consequence of that must be a login screen without shortcuts, not an
  /// app that will not start.
  Future<void> load() async {
    List<SavedAccount> accounts;
    try {
      final raw = await _storage.read(key: _key);
      accounts = _decode(raw);
    } catch (e) {
      AppLogger.warn('auth', 'saved accounts unreadable: $e');
      value = const [];
      return;
    }

    final now = DateTime.now();
    final fresh = accounts
        .where((a) => now.difference(a.lastUsedAt) < staleAfter)
        .toList();

    value = _sorted(fresh);
    if (fresh.length != accounts.length) await _persist();
  }

  /// Records the account that is signed in right now, or refreshes what is
  /// already recorded about it. Safe to call on every profile load.
  Future<void> remember({
    required String userId,
    required String email,
    required String refreshToken,
    String? name,
    String? photoUrl,
  }) async {
    final existing = value.where((a) => a.userId == userId).firstOrNull;
    final updated = SavedAccount(
      userId: userId,
      email: email.isNotEmpty ? email : existing?.email ?? '',
      refreshToken: refreshToken,
      lastUsedAt: DateTime.now(),
      name: name ?? existing?.name,
      photoUrl: photoUrl ?? existing?.photoUrl,
    );

    // Placed at the head rather than re-sorted: the list is already in order,
    // and this account has just become the most recent by definition. Sorting
    // a list whose first entries share a timestamp — two accounts remembered in
    // the same millisecond, which the tests do — decides between them
    // arbitrarily, and the one that was just used would sometimes lose.
    value = [
      updated,
      ...value.where((a) => a.userId != userId),
    ].take(maxAccounts).toList();
    await _persist();
  }

  /// Replaces the stored token for [userId], leaving everything else alone.
  ///
  /// Supabase rotates the refresh token on every renewal and the previous one
  /// stops working shortly after. The token kept here is therefore only good
  /// for as long as it is the current one — so the active account's entry is
  /// rewritten each time it rotates, and an account that is merely stored,
  /// never refreshing, keeps the last token it was left with.
  Future<void> updateToken(String userId, String refreshToken) async {
    final index = value.indexWhere((a) => a.userId == userId);
    if (index < 0) return;
    if (value[index].refreshToken == refreshToken) return;

    final next = [...value];
    next[index] = next[index].copyWith(refreshToken: refreshToken);
    value = next;
    await _persist();
  }

  /// Drops an account from the picker. Called when its session is signed out
  /// for real — the token has been revoked by then and offering it would be
  /// offering a door that no longer opens — and when the person asks.
  Future<void> forget(String userId) async {
    if (!value.any((a) => a.userId == userId)) return;
    value = value.where((a) => a.userId != userId).toList();
    await _persist();
  }

  bool has(String userId) => value.any((a) => a.userId == userId);

  /// Most recently used first, with the id as a tie-break so a list read back
  /// off the keystore comes out the same way every time.
  List<SavedAccount> _sorted(List<SavedAccount> accounts) =>
      [...accounts]..sort((a, b) {
        final byTime = b.lastUsedAt.compareTo(a.lastUsedAt);
        return byTime != 0 ? byTime : a.userId.compareTo(b.userId);
      });

  List<SavedAccount> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    final accounts = <SavedAccount>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final account = SavedAccount.fromJson(entry.cast<String, dynamic>());
      if (account != null) accounts.add(account);
    }
    return accounts;
  }

  Future<void> _persist() async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode([for (final a in value) a.toJson()]),
      );
    } catch (e) {
      // The list in memory is already right, so the switcher works for this
      // run; only the next launch loses it. Not worth failing a sign-in over.
      AppLogger.warn('auth', 'could not save accounts: $e');
    }
  }
}
