import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/app_logger.dart';

/// Keeps the Supabase session in the platform keystore instead of the
/// SharedPreferences file the library defaults to.
///
/// The session string holds a live refresh token — the same credential the
/// account switcher already refuses to put anywhere but the keystore (see
/// SavedAccountsStore). Leaving the *primary* session in a plaintext XML file
/// while guarding the secondary ones was the lock on the shed and not the
/// house.
///
/// On first run it migrates the existing session out of SharedPreferences, so
/// nobody is signed out by the upgrade; the plaintext copy is deleted after
/// the move.
///
/// Never throws: the keystore can fail to open — the known Android case is a
/// backup restored onto a different device, where the keys no longer decrypt —
/// and the consequence must be the login screen, not an app that cannot start.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({required this.persistSessionKey});

  /// Same key the library's default storage uses (`sb-<host>-auth-token`), so
  /// the migration below finds the legacy value under the same name.
  final String persistSessionKey;

  // The login keychain on macOS, not the data-protection one: the latter
  // needs the Keychain Sharing entitlement, which needs a provisioning
  // profile, and without it every write fails quietly. No effect elsewhere.
  final _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  Future<void> initialize() async {
    try {
      if (await _storage.read(key: persistSessionKey) != null) return;
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(persistSessionKey);
      if (legacy == null) return;
      await _storage.write(key: persistSessionKey, value: legacy);
      await prefs.remove(persistSessionKey);
      AppLogger.info('auth', 'session migrated to secure storage');
    } catch (e) {
      AppLogger.warn('auth', 'secure session init failed: $e');
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await _storage.containsKey(key: persistSessionKey);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: persistSessionKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: persistSessionKey, value: persistSessionString);
    } catch (e) {
      AppLogger.warn('auth', 'session persist failed: $e');
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: persistSessionKey);
    } catch (e) {
      AppLogger.warn('auth', 'session remove failed: $e');
    }
  }
}
