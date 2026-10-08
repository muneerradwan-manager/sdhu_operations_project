import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/auth/data/saved_accounts_store.dart';
import 'package:sdhu_operations_project/features/auth/domain/saved_account.dart';

/// The list of accounts this device will open without a password.
///
/// Everything here is about the credential surviving exactly as long as it
/// should and not one day longer, because that is the whole safety argument for
/// the feature: a refresh token that stays valid indefinitely and a device that
/// offers it forever are two different problems, and only the second is ours.
void main() {
  const key = 'saved_accounts_v1';

  Map<String, String> data = {};

  setUp(() {
    data = {};
    FlutterSecureStorage.setMockInitialValues(data);
  });

  String entry({
    required String id,
    required String token,
    required Duration age,
    String? name,
  }) {
    return jsonEncode({
      'user_id': id,
      'email': '$id@example.com',
      'refresh_token': token,
      'last_used_at': DateTime.now().subtract(age).toIso8601String(),
      'name': ?name,
    });
  }

  void seed(List<String> entries) {
    data[key] = '[${entries.join(',')}]';
  }

  test('an account nobody has come back to stops being offered', () async {
    seed([
      entry(id: 'recent', token: 't1', age: const Duration(days: 3)),
      entry(id: 'forgotten', token: 't2', age: const Duration(days: 31)),
    ]);

    final store = SavedAccountsStore();
    await store.load();

    expect(store.value.map((a) => a.userId), ['recent']);
    // And gone from the keystore too, not merely hidden — the token is the
    // thing that had to go.
    expect(data[key], isNot(contains('t2')));
  });

  test('a stored entry that cannot be read costs only itself', () async {
    seed([
      '{"user_id":"good","refresh_token":"t1","last_used_at":'
          '"${DateTime.now().toIso8601String()}"}',
      '{"user_id":"tokenless"}',
      '"not an object at all"',
    ]);

    final store = SavedAccountsStore();
    await store.load();

    expect(store.value.map((a) => a.userId), ['good']);
  });

  test('a keystore that will not open leaves an empty list, not a throw', () async {
    data[key] = 'this is not json';

    final store = SavedAccountsStore();
    await expectLater(store.load(), completes);
    expect(store.value, isEmpty);
  });

  test('the account just used comes first', () async {
    final store = SavedAccountsStore();
    await store.load();

    await store.remember(userId: 'a', email: 'a@x', refreshToken: 't1');
    await store.remember(userId: 'b', email: 'b@x', refreshToken: 't2');
    expect(store.value.map((a) => a.userId), ['b', 'a']);

    await store.remember(userId: 'a', email: 'a@x', refreshToken: 't3');
    expect(store.value.map((a) => a.userId), ['a', 'b']);
    // Re-remembering is an update, not a second entry.
    expect(store.value.length, 2);
    expect(store.value.first.refreshToken, 't3');
  });

  test('past the cap the least recently used is dropped', () async {
    final store = SavedAccountsStore();
    await store.load();

    for (var i = 0; i <= SavedAccountsStore.maxAccounts; i++) {
      await store.remember(userId: 'u$i', email: 'u$i@x', refreshToken: 't$i');
    }

    expect(store.value.length, SavedAccountsStore.maxAccounts);
    expect(store.value.map((a) => a.userId), isNot(contains('u0')));
    expect(store.value.first.userId, 'u${SavedAccountsStore.maxAccounts}');
  });

  test('a rotated token replaces only its own account', () async {
    final store = SavedAccountsStore();
    await store.load();
    await store.remember(userId: 'a', email: 'a@x', refreshToken: 't1');
    await store.remember(userId: 'b', email: 'b@x', refreshToken: 't2');

    await store.updateToken('a', 'rotated');

    final a = store.value.firstWhere((x) => x.userId == 'a');
    final b = store.value.firstWhere((x) => x.userId == 'b');
    expect(a.refreshToken, 'rotated');
    expect(b.refreshToken, 't2');
    // The position is a record of use, and a token rotating is not a use.
    expect(store.value.map((x) => x.userId), ['b', 'a']);
  });

  test('a token for an account we do not hold is not an invitation', () async {
    final store = SavedAccountsStore();
    await store.load();

    await store.updateToken('stranger', 'token');

    expect(store.value, isEmpty);
  });

  test('remembering keeps the name when a later sign-in has none', () async {
    final store = SavedAccountsStore();
    await store.load();

    await store.remember(
      userId: 'a',
      email: 'a@x',
      refreshToken: 't1',
      name: 'Muneer',
      photoUrl: 'https://example.com/a.jpg',
    );
    await store.remember(userId: 'a', email: 'a@x', refreshToken: 't2');

    expect(store.value.single.name, 'Muneer');
    expect(store.value.single.photoUrl, 'https://example.com/a.jpg');
  });

  test('forgetting an account takes its token off the device', () async {
    final store = SavedAccountsStore();
    await store.load();
    await store.remember(userId: 'a', email: 'a@x', refreshToken: 'secret');

    await store.forget('a');

    expect(store.value, isEmpty);
    expect(data[key], isNot(contains('secret')));
  });

  test('what one run saves, the next run reads', () async {
    final first = SavedAccountsStore();
    await first.load();
    await first.remember(
      userId: 'a',
      email: 'a@x',
      refreshToken: 't1',
      name: 'Muneer',
    );

    final second = SavedAccountsStore();
    await second.load();

    expect(second.value.single.userId, 'a');
    expect(second.value.single.refreshToken, 't1');
    expect(second.value.single.label, 'Muneer');
  });

  test('a card falls back to the address when there is no name', () {
    final account = SavedAccount(
      userId: 'a',
      email: 'a@example.com',
      refreshToken: 't',
      lastUsedAt: DateTime.now(),
      name: '   ',
    );

    expect(account.label, 'a@example.com');
  });

  test('an account never says its token out loud', () {
    final account = SavedAccount(
      userId: 'a',
      email: 'a@example.com',
      refreshToken: 'super-secret-refresh-token',
      lastUsedAt: DateTime.now(),
    );

    expect(account.toString(), isNot(contains('super-secret')));
  });
}
