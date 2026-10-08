# -*- coding: utf-8 -*-
"""Wipe every operational record of season 1448, leaving the season standing.

    export SUPABASE_SERVICE_KEY=sb_secret_...
    python supabase/seeds/clean_season_1448.py            # show only
    python supabase/seeds/clean_season_1448.py --apply
    python supabase/seeds/clean_season_1448.py --apply --keep-participants

What goes — everything scoped to the hijri_year-1448 seasons row:

  * reports               -> report_rows, report_blocks, report_attachments
                             follow by cascade;
  * modules               -> module_members, module_nodes, node members,
                             assigned tasks, module_reports and their
                             attachments, ratings follow by cascade;
  * reference_items       carrying that season_id (the 1448 hotels/clusters —
                             cities carry none and are untouched);
  * season_participants   for that season;
  * storage               the `modules` bucket folder of every deleted file
                             (official PDFs and filed-report attachments both
                             live under {module_id}/) and the `reports` bucket
                             folder of every deleted report.

What stays: the seasons row itself (the current-season machinery owns it),
audit_log (a cleanup that erases its own trail isn't one), notifications,
profiles, permissions, and every catalog table — module_types, report_types,
reference_sets, job_titles.

The service key bypasses RLS, and the 0073 guards fire on UPDATE only, so no
temporary admin account is needed here (unlike attach_official_docs.py, whose
writes are updates). The 0077 audit triggers record the deletions with a null
actor, which is what actually happened.

One soft spot: the 0040 backfill assigned a shared hotel/cluster entry to one
season arbitrarily, so a 1448 reference item can still be pointed at by an
older season's node (on delete restrict). Such rows are kept and listed rather
than failed on — each is one edit away in master data.

Modules are deleted before reference_items on purpose: the 1448 nodes holding
the restrict FKs must be gone first.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'decisions_1447'))
import sbx                        # noqa: E402

APPLY = '--apply' in sys.argv
# The enrolled employees can outlive a data wipe: cleaning what 1448 accumulated
# is not the same as un-enrolling 158 people from the season being run.
KEEP_PARTICIPANTS = '--keep-participants' in sys.argv
SEASON_YEAR = 1448


# ------------------------------------------------------------------- storage

def walk(bucket, prefix):
    """Every file under prefix, recursively — the list endpoint is one level."""
    files, offset = [], 0
    while True:
        page = sbx.call(f'/storage/v1/object/list/{bucket}', 'POST',
                        {'prefix': prefix, 'limit': 1000, 'offset': offset}) or []
        for entry in page:
            path = f"{prefix}/{entry['name']}" if prefix else entry['name']
            if entry.get('id'):
                files.append(path)
            else:                           # a folder: id is null
                files.extend(walk(bucket, path))
        if len(page) < 1000:
            return files
        offset += 1000


def remove(bucket, paths):
    for i in range(0, len(paths), 100):
        sbx.call(f'/storage/v1/object/{bucket}', 'DELETE',
                 {'prefixes': paths[i:i + 100]})


# ------------------------------------------------------------------ the season

rows = sbx.select(
    'seasons',
    f'select=id,hijri_year,gregorian_label,is_current&hijri_year=eq.{SEASON_YEAR}')
if not rows:
    sys.exit(f'No seasons row for {SEASON_YEAR} AH — nothing to clean.')
season = rows[0]
sid = season['id']
print(f"Season {season['hijri_year']} AH ({season.get('gregorian_label')})"
      f"{'  <- current' if season['is_current'] else ''}")

# ------------------------------------------------------------------- gather

# 0024 dropped modules.title: a file is named by its type.
modules = sbx.select(
    'modules', f'select=id,module_types(name_ar)&season_id=eq.{sid}')
reports = sbx.select('reports', f'select=id,title&season_id=eq.{sid}')
ref_items = sbx.select('reference_items',
                       f'select=id,name_ar&season_id=eq.{sid}')
participants = sbx.select('season_participants',
                          f'select=id&season_id=eq.{sid}')

module_files = [p for m in modules for p in walk('modules', m['id'])]
report_files = [p for r in reports for p in walk('reports', r['id'])]

print(f"""
Will delete:
  {len(modules):4} operational file(s) and everything hanging off them
  {len(reports):4} report(s) and their rows/blocks/attachments
  {len(ref_items):4} season-scoped reference item(s)
  {len(participants) if not KEEP_PARTICIPANTS else 0:4} season participant row(s)"""
      + (f'  (kept: {len(participants)})' if KEEP_PARTICIPANTS else '') + f"""
  {len(module_files):4} file(s) in the `modules` bucket
  {len(report_files):4} file(s) in the `reports` bucket

Keeps: the seasons row, audit_log, notifications, profiles, catalogs.""")
for m in modules:
    print(f"  file:   {(m.get('module_types') or {}).get('name_ar', m['id'])}")
for r in reports:
    print(f"  report: {r['title']}")

if not APPLY:
    print('\nDry run. Re-run with --apply to delete.')
    sys.exit(0)

# ------------------------------------------------------------------- delete
#
# Storage first: if it fails midway the database is untouched and the run can
# simply be repeated — every step below re-derives its targets from the DB.

remove('modules', module_files)
remove('reports', report_files)
print(f'storage: {len(module_files) + len(report_files)} file(s) removed')

gone = sbx.delete('reports', f'season_id=eq.{sid}') or []
print(f'reports: {len(gone)} deleted')

gone = sbx.delete('modules', f'season_id=eq.{sid}') or []
print(f'modules: {len(gone)} deleted')

# Bulk first; only on a restrict violation fall back to one-by-one so the
# survivors can be named instead of aborting the whole cleanup.
kept = []
try:
    gone = sbx.delete('reference_items', f'season_id=eq.{sid}') or []
    print(f'reference_items: {len(gone)} deleted')
except RuntimeError:
    n = 0
    for item in ref_items:
        try:
            sbx.delete('reference_items', f"id=eq.{item['id']}")
            n += 1
        except RuntimeError:
            kept.append(item)
    print(f'reference_items: {n} deleted')

if KEEP_PARTICIPANTS:
    print(f'season_participants: kept ({len(participants)})')
else:
    gone = sbx.delete('season_participants', f'season_id=eq.{sid}') or []
    print(f'season_participants: {len(gone)} deleted')

if kept:
    print('\nKept — still referenced by another season\'s file '
          '(reassign or delete them in master data):')
    for item in kept:
        print(f"  {item['name_ar']}  ({item['id']})")

print(f'\nSeason {SEASON_YEAR} AH is clean. The seasons row itself stands.')
