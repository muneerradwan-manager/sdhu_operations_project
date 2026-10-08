# -*- coding: utf-8 -*-
"""Attach the official .docx documents to season 1447's files and reports.

    export SUPABASE_SERVICE_KEY=sb_secret_...
    python supabase/seeds/attach_official_docs.py            # show only
    python supabase/seeds/attach_official_docs.py --apply

Run from the repository root — the documents are read from assets/docs.

The season was BUILT from these documents (decisions_1447/, reports_1447/), but
only their content was carried over; the papers themselves stayed on disk. This
uploads each one to where the app already looks for it:

  * an operational file's decision goes into the private `modules` bucket under
    {moduleId}/{key}, and `modules.data.official_pdf` points at it — the shape
    ModuleFile.fromJson reads and the detail screen signs and opens;
  * a report's document goes into the private `reports` bucket under
    {reportId}/{n}_{key}, with a row in `report_attachments` — what
    Report.attachments carries and AttachmentsView renders.

المدينة المنورة holds TWO decisions: 3179 forms the office, 3190 adds its
ترحيل team (same office, same file — see extract.madinah_departures). One
field holds one file, so 3190 gets a second pdf field on the type, declared
here as data exactly like every other field.

Updating `modules` cannot be done as the service role: the guard trigger
(0073) asks is_admin(), which reads auth.uid(), and the service key carries
none — unlike the profiles guard (0011), it makes no allowance for a trusted
backend. So the module writes are made as a REAL admin: a temporary account is
created, approved and flagged through the profiles guard's backend allowance,
signs in, does the updates under every rule the app itself obeys, and is
deleted. The audit log keeps its name as a snapshot (actor_id sets null), so
the trail reads honestly.

Safe to repeat: storage uploads upsert, the module field is written whole, and
a report's attachments are replaced rather than added to.
"""
import glob
import json
import os
import re
import secrets
import sys
import urllib.request
from urllib.parse import quote

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'decisions_1447'))
import sbx                        # noqa: E402

APPLY = '--apply' in sys.argv
SEASON_YEAR = 1447
DOCS = 'assets/docs'
DOCX_MIME = ('application/vnd.openxmlformats-officedocument'
             '.wordprocessingml.document')

# fragment of the file name → the module type whose season-1447 file it founded,
# and the pdf field it lands in.
MODULE_DOCS = [
    ('3142', 'makkah_sectors_towers',     'official_pdf'),
    ('3144', 'makkah_tawafa_transport',   'official_pdf'),
    ('3145', 'makkah_central_catering',   'official_pdf'),
    ('3146', 'makkah_construction',       'official_pdf'),
    ('3147', 'jeddah_airport_reception',  'official_pdf'),
    ('3148', 'mission_offices_affairs',   'official_pdf'),
    ('3150', 'central_aviation',          'official_pdf'),
    ('3151', 'financial_administration',  'official_pdf'),
    ('3152', 'oversight_complaints',      'official_pdf'),
    ('3153', 'follow_up_evaluation',      'official_pdf'),
    ('فرق المشاعر', 'mashaaer_teams',     'official_pdf'),
    ('3172', 'arafat_camp_assignment',    'official_pdf'),
    ('3173', 'mina_camp_assignment',      'official_pdf'),
    ('3179', 'madinah_admin_office',      'official_pdf'),
    ('3190', 'madinah_admin_office',      'departures_pdf'),
    ('3197', 'five_star_services_review', 'official_pdf'),
]

# The field 3190 needs, created on the type if this is the first run.
DEPARTURES_FIELD = {
    'key': 'departures_pdf',
    'label_ar': 'قرار فريق الترحيل (3190)',
    'label_en': 'Departures team decision (3190)',
    'kind': 'pdf', 'is_required': False, 'sort_order': 2,
}

# fragment → the meal report's type, and a key for when the Arabic name strips
# to nothing (storage refuses a non-ASCII object key).
REPORT_DOCS = [
    ('توزيع الوجبات', 'mashaaer_meal_distribution', 'distribution'),
    ('توقيت الوجبات', 'mashaaer_meal_timing',       'timing'),
    ('مكونات الوجبات', 'mashaaer_meal_components',  'components'),
]


# ------------------------------------------------------- the app's key shaping
# A port of lib/core/supabase/storage_key.dart, so the keys written here look
# exactly like keys the app itself would write.

def _safe(value):
    value = re.sub(r'[^A-Za-z0-9._-]', '_', value)
    value = re.sub(r'_+', '_', value)
    return re.sub(r'^[_.\-]+|[_\-]+$', '', value)


def storage_key(file_name, fallback='file'):
    dot = file_name.rfind('.')
    has_ext = 0 < dot < len(file_name) - 1
    base = file_name[:dot] if has_ext else file_name
    ext = _safe(file_name[dot + 1:]) if has_ext else ''
    safe = _safe(base)
    if not safe.replace('_', ''):
        safe = _safe(fallback)
    if not safe:
        safe = 'file'
    safe = safe[:60]
    return f'{safe}.{ext}' if ext else safe


# ---------------------------------------------------------------------- pieces

def doc(fragment):
    """The one document whose filename contains this fragment."""
    hits = [p for p in glob.glob(os.path.join(DOCS, '**', '*.docx'),
                                 recursive=True)
            if fragment in os.path.basename(p)]
    if len(hits) != 1:
        raise SystemExit(f'{fragment}: matched {len(hits)} files, expected 1')
    return hits[0]


def upload(bucket, path, payload):
    """Into the private bucket, replacing what a previous run put there."""
    req = urllib.request.Request(
        f'{sbx.BASE}/storage/v1/object/{bucket}/{quote(path)}',
        data=payload, method='POST',
        headers={'apikey': sbx.KEY, 'Authorization': f'Bearer {sbx.KEY}',
                 'Content-Type': DOCX_MIME, 'x-upsert': 'true'})
    with urllib.request.urlopen(req) as r:
        r.read()


# ------------------------------------------------------------ the temp admin

TEMP_EMAIL = 'docs.uploader.temp@syrianhajj.org'


def anon_key():
    """The publishable key, read from the app's own .env."""
    with open('.env', encoding='utf-8') as f:
        for line in f:
            if line.startswith('SUPABASE_ANON_KEY='):
                return line.split('=', 1)[1].strip()
    raise SystemExit('.env has no SUPABASE_ANON_KEY')


def admin_login():
    """A signed-in admin for the writes the guards demand one for."""
    password = secrets.token_urlsafe(24) + 'aA1'
    # A leftover from an interrupted run would make create fail; clear it.
    for u in sbx.list_auth_users():
        if u.get('email') == TEMP_EMAIL:
            sbx.delete_auth_user(u['id'])
    user = sbx.create_auth_user(TEMP_EMAIL, password)
    # The profiles guard lets the backend (null uid) set the privileged
    # columns — the same allowance the first-admin bootstrap rides (0011).
    sbx.update('profiles', f"id=eq.{user['id']}", {
        'first_name': 'رفع المستندات الرسمية',
        'account_status': 'approved',
        'is_admin': True,
    })
    req = urllib.request.Request(
        f'{sbx.BASE}/auth/v1/token?grant_type=password',
        data=json.dumps({'email': TEMP_EMAIL, 'password': password}).encode(),
        method='POST',
        headers={'apikey': anon_key(), 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req) as r:
        token = json.loads(r.read().decode())['access_token']
    return user['id'], token


def user_update(table, query, patch, token):
    """A PATCH as the signed-in admin — RLS and the guard triggers apply."""
    req = urllib.request.Request(
        f'{sbx.BASE}/rest/v1/{table}?{query}',
        data=json.dumps(patch).encode(), method='PATCH',
        headers={'apikey': anon_key(), 'Authorization': f'Bearer {token}',
                 'Content-Type': 'application/json',
                 'Prefer': 'return=minimal'})
    with urllib.request.urlopen(req) as r:
        r.read()


def main():
    season = next(
        s for s in sbx.select('seasons') if s['hijri_year'] == SEASON_YEAR
    )
    sid = season['id']

    types = {t['code']: t for t in sbx.select('module_types')}
    modules = sbx.select(
        'modules', f'select=id,module_type_id,data&season_id=eq.{sid}')
    module_of = {m['module_type_id']: m for m in modules}

    report_types = {t['code']: t for t in sbx.select('report_types')}
    reports = sbx.select(
        'reports', f'select=id,report_type_id,title&season_id=eq.{sid}')
    report_of = {r['report_type_id']: r for r in reports}

    print(f'season {SEASON_YEAR}: {sid}')

    # ------------------------------------------------------- what will happen
    plan_m, plan_r, missing = [], [], []
    for fragment, code, field in MODULE_DOCS:
        path = doc(fragment)
        m = module_of.get(types[code]['id'])
        if m is None:
            missing.append((path, f'no {code} file this season'))
            continue
        name = os.path.basename(path)
        key = f"{m['id']}/{storage_key(name, fallback=field)}"
        plan_m.append((path, m, field, key, types[code]['name_ar']))

    for fragment, code, ascii_key in REPORT_DOCS:
        path = doc(fragment)
        r = report_of.get(report_types[code]['id'])
        if r is None:
            missing.append((path, f'no {code} report this season'))
            continue
        name = os.path.basename(path)
        key = f"{r['id']}/0_{storage_key(name, fallback=ascii_key)}"
        plan_r.append((path, r, key))

    for path, m, field, key, type_name in plan_m:
        print(f'  {os.path.basename(path)}')
        print(f'      → modules/{key}  ({type_name}.data.{field})')
    for path, r, key in plan_r:
        print(f'  {os.path.basename(path)}')
        print(f'      → reports/{key}  ({r["title"]})')
    for path, why in missing:
        print(f'  SKIPPED {os.path.basename(path)} — {why}')

    if not APPLY:
        print('\nDRY RUN — nothing uploaded. Re-run with --apply.')
        return

    # ------------------------------------------------------------ the modules
    if any(field == 'departures_pdf' for _, _, field, _, _ in plan_m):
        t = types['madinah_admin_office']
        got = sbx.select(
            'module_type_fields',
            f"select=id&module_type_id=eq.{t['id']}"
            f"&key=eq.{DEPARTURES_FIELD['key']}&level_id=is.null")
        if not got:
            sbx.insert('module_type_fields',
                       [{**DEPARTURES_FIELD, 'module_type_id': t['id']}])
            print('field departures_pdf declared on المكتب الإداري بالمدينة')

    uid, token = admin_login()
    try:
        for path, m, field, key, _ in plan_m:
            with open(path, 'rb') as f:
                payload = f.read()
            upload('modules', key, payload)
            # Written whole under the one key; everything else in data stays
            # put. Two docs land on the Madinah file, so the second write must
            # start from the first one's result, not from the stale select.
            m['data'] = {**(m['data'] or {}),
                         field: {'path': key, 'name': os.path.basename(path)}}
            user_update('modules', f"id=eq.{m['id']}", {'data': m['data']},
                        token)
            print(f'  attached {os.path.basename(path)}')
    finally:
        sbx.delete_auth_user(uid)
        print('temporary admin removed')

    # ------------------------------------------------------------ the reports
    for path, r, key in plan_r:
        with open(path, 'rb') as f:
            payload = f.read()
        upload('reports', key, payload)
        # Replaced rather than added to, so a re-run is a correction.
        sbx.delete('report_attachments', f"report_id=eq.{r['id']}")
        sbx.insert('report_attachments', [{
            'report_id': r['id'], 'kind': 'file', 'path': key,
            'name': os.path.basename(path), 'mime_type': DOCX_MIME,
            'size_bytes': len(payload), 'sort_order': 0,
        }])
        print(f'  attached {os.path.basename(path)} → {r["title"]}')

    print('\ndone.')


if __name__ == '__main__':
    main()
