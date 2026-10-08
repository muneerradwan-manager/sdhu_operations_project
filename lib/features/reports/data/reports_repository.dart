import '../../../core/supabase/supabase_client.dart';
import '../domain/report.dart';
import '../domain/report_type.dart';

/// Reading the reports section.
///
/// RLS does the deciding: a published report is readable by any approved
/// account, an unpublished one only by whoever manages reports. So nothing here
/// filters on `is_published` — asking the database twice for the same rule is
/// how the two answers come to disagree.
class ReportsRepository {
  static const _columns = '''
    id, report_type_id, season_id, title, subtitle, kind, number, data, is_published,
    updated_at,
    created_at,
    report_types(name_ar, name_en),
    seasons(hijri_year)
  ''';

  /// The list's projection: everything a ReportCard shows, and NOT `data` —
  /// the header jsonb can carry paragraphs, and the list never renders it.
  static const _listColumns = '''
    id, report_type_id, season_id, title, subtitle, kind, number, is_published,
    updated_at,
    created_at,
    report_types(name_ar, name_en),
    seasons(hijri_year)
  ''';

  /// A ceiling on the list. Not pagination — reports are entered by hand and a
  /// season's worth is small — but a guard against the year the table grows
  /// past what one screenful of cards was ever going to show.
  static const listLimit = 200;

  /// The type catalog changes when somebody edits the schema, which is close
  /// enough to never that every screen re-fetching it was pure waste. Held per
  /// process for [_typesTtl]; [fetchTypes] refreshes it when it goes stale.
  static List<ReportType>? _typesCache;
  static DateTime? _typesFetchedAt;
  static const _typesTtl = Duration(minutes: 5);

  /// The catalog: every kind of report, with its header fields and its columns.
  Future<List<ReportType>> fetchTypes() async {
    final cache = _typesCache;
    final at = _typesFetchedAt;
    if (cache != null &&
        at != null &&
        DateTime.now().difference(at) < _typesTtl) {
      return cache;
    }
    final rows = await supabase
        .from('report_types')
        .select('*, report_type_fields(*), report_type_columns(*)')
        .order('sort_order');
    final types = (rows as List)
        .map((r) => ReportType.fromMap(r as Map<String, dynamic>))
        .toList();
    _typesCache = types;
    _typesFetchedAt = DateTime.now();
    return types;
  }

  /// One type by id, from the same cached catalog.
  Future<ReportType?> fetchType(String id) async =>
      (await fetchTypes()).where((t) => t.id == id).firstOrNull;

  /// The list, newest first.
  ///
  /// [seasonId] narrows to one season AND the general reports — a general
  /// report is true in every season, so filtering it out of one would be
  /// hiding something that applies. Null returns everything readable.
  Future<List<Report>> fetchReports({String? seasonId}) async {
    final query = supabase.from('reports').select(_listColumns);
    final rows =
        await (seasonId == null
                ? query
                : query.or('season_id.is.null,season_id.eq.$seasonId'))
            .order('updated_at', ascending: false)
            .limit(listLimit);
    return (rows as List)
        .map((r) => Report.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// One document in full: its header, its table, its BLOCKS and its
  /// attachments.
  ///
  /// `report_blocks` was missing from this select from 0069 until 0103, and it
  /// hid because nothing exercised it: the only type with blocks was `general`,
  /// and `general` had zero documents until the meal shapes were converted into
  /// it. The moment there was a written document, it read as blank.
  ///
  /// The blank page was the lesser half. This same call feeds the EDITOR — both
  /// screens push `ReportEditorScreen(existing: …)` with what they fetched, and
  /// the editor never refetches — while `save_report` deletes every block and
  /// re-inserts the ones it is handed. So a written document opened and saved
  /// would have had its entire content deleted, silently, by somebody who
  /// changed its title. `test/reports_select_test.dart` holds this shut.
  Future<Report?> fetchReport(String id) async {
    final row = await supabase
        .from('reports')
        .select(
          '$_columns, report_rows(*), report_blocks(*), report_attachments(*)',
        )
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Report.fromMap(row);
  }

  /// Deletes a report; rows, blocks and attachments cascade with it.
  ///
  /// Here and not in the two screens that ask for it: presentation deleting
  /// straight through `supabase.from` was the only raw query left in a widget,
  /// twice, and both copies have to change together or they drift.
  Future<void> deleteReport(String id) async {
    await supabase.from('reports').delete().eq('id', id);
  }

  /// A signed URL for an attachment, minted on demand — the bucket is private.
  ///
  /// Same shape as the notifications signer, because [AttachmentSigner] is what
  /// the shared attachments widget takes: with [download], storage is asked to
  /// hand the file over under the name the filer's device gave it rather than
  /// opening it in a tab.
  Future<String> signedUrl(
    String path, {
    int expiresInSeconds = 3600,
    bool download = false,
    String? downloadName,
  }) {
    return supabase.storage
        .from('reports')
        .createSignedUrl(path, expiresInSeconds)
        .then((url) {
          if (!download) return url;
          final separator = url.contains('?') ? '&' : '?';
          final name = Uri.encodeComponent(downloadName ?? '');
          return '$url${separator}download${name.isEmpty ? '' : '=$name'}';
        });
  }
}
