import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/supabase/storage_key.dart';

/// Storage rejects an object key with anything but ASCII in it — `InvalidKey`,
/// 400, nothing uploaded — and in this app nearly every file picked off a phone
/// is named in Arabic. So the key is not the file name, and these are the cases
/// that made that necessary.
void main() {
  group('storageKey', () {
    test('an Arabic name still yields a usable key with its extension', () {
      final key = storageKey('منير عبدالله رضوان.pdf', fallback: 'plan');
      expect(key, 'plan.pdf');
      expect(key, matches(RegExp(r'^[A-Za-z0-9._-]+$')));
    });

    test('an ASCII name is kept, spaces aside', () {
      expect(storageKey('Tower plan v2.pdf'), 'Tower_plan_v2.pdf');
    });

    test('a mixed name keeps whatever was already safe', () {
      expect(storageKey('تقرير-2026.jpg'), '2026.jpg');
    });

    test('a name that is nothing but an extension still gets a base', () {
      expect(storageKey('.pdf'), 'pdf');
    });

    test('no extension, no trailing dot', () {
      expect(storageKey('صورة'), 'file');
      expect(storageKey('صورة', fallback: '3'), '3');
    });

    test('a long name is cut, and the extension survives it', () {
      final key = storageKey('${'a' * 200}.png');
      expect(key.endsWith('.png'), isTrue);
      expect(key.length, lessThanOrEqualTo(64));
    });
  });
}
