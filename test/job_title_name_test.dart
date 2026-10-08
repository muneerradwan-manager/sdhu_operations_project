import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/profile/domain/profile.dart';

/// A job description reaches the app down two different paths — embedded as
/// `job_title:job_title_id(name_ar, name_en)` in a profile query, or flattened
/// into `job_title_name` / `job_title_name_en` by `assignable_employees` — and
/// both have to end up as the same pair of names. Miss the second and the
/// employee picker is the one screen that silently goes back to Arabic.
void main() {
  group('jobTitleNameOrNull', () {
    test('reads the embedded join', () {
      final name = jobTitleNameOrNull({
        'job_title': {'name_ar': 'طبيب', 'name_en': 'Doctor'},
      });
      expect(name?.ar, 'طبيب');
      expect(name?.en, 'Doctor');
    });

    test('reads the flat columns the search function returns', () {
      final name = jobTitleNameOrNull({
        'job_title_name': 'سائق',
        'job_title_name_en': 'Driver',
      });
      expect(name?.ar, 'سائق');
      expect(name?.en, 'Driver');
    });

    test('a title with no English name still carries the Arabic', () {
      final name = jobTitleNameOrNull({
        'job_title': {'name_ar': 'مطوف', 'name_en': null},
      });
      expect(name?.ar, 'مطوف');
      expect(name?.en, isNull);
    });

    test('null when the query never asked for it', () {
      expect(jobTitleNameOrNull({'id': 'x'}), isNull);
    });
  });
}
