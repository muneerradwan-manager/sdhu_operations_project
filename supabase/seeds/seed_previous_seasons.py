#!/usr/bin/env python3
"""
Seed historical Hajj seasons so the archive on the seasons screen has rows.

The same rows exist as migration 0015_seed_previous_seasons.sql — that is the
canonical artifact and is what applies on a fresh environment. This script is
the "apply it to the live project right now" path, for when the Postgres
connection isn't available but the REST API is. Both are idempotent on
hijri_year, so running either (or both, in any order) is safe.

`seasons` RLS restricts writes to admins, so this needs the SERVICE (secret)
key, which bypasses RLS. NEVER put that key in .env — that file is bundled as a
Flutter asset and would ship inside the APK. Use .env.seed (gitignored) or a
shell variable.

Usage:
  SUPABASE_URL=https://txmtfwdqgosfwdvpgetm.supabase.co \
  SUPABASE_SERVICE_KEY=sb_secret_xxx \
  python supabase/seeds/seed_previous_seasons.py
"""
import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("SUPABASE_URL", "https://txmtfwdqgosfwdvpgetm.supabase.co")
KEY = os.environ.get("SUPABASE_SERVICE_KEY")

if not KEY:
    sys.exit("Set SUPABASE_SERVICE_KEY (the sb_secret_... key).")

# is_current stays false for every row: the partial unique index
# `one_current_season` permits only one true, and the current season is owned by
# the app (ensure_current_season / set_current_season). gregorian_label follows
# the "YYYY/YYYY+1" convention that HijriUtils.currentGregorianLabel() emits.
SEASONS = [
    {"hijri_year": 1443, "gregorian_label": "2021/2022", "is_current": False,
     "start_date": "2022-07-05", "end_date": "2022-07-12"},
    {"hijri_year": 1444, "gregorian_label": "2022/2023", "is_current": False,
     "start_date": "2023-06-24", "end_date": "2023-07-01"},
    {"hijri_year": 1445, "gregorian_label": "2023/2024", "is_current": False,
     "start_date": "2024-06-12", "end_date": "2024-06-19"},
    {"hijri_year": 1446, "gregorian_label": "2024/2025", "is_current": False,
     "start_date": "2025-06-02", "end_date": "2025-06-09"},
    {"hijri_year": 1447, "gregorian_label": "2025/2026", "is_current": False,
     "start_date": "2026-05-23", "end_date": "2026-05-30"},
]


def api(path, method="GET", body=None, prefer=None):
    headers = {
        "apikey": KEY,
        "Authorization": f"Bearer {KEY}",
        "Content-Type": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    req = urllib.request.Request(
        BASE + path,
        data=(json.dumps(body).encode() if body is not None else None),
        method=method,
        headers=headers,
    )
    return urllib.request.urlopen(req).read()


try:
    # ignore-duplicates makes this the REST equivalent of the migration's
    # `on conflict (hijri_year) do nothing`.
    api(
        "/rest/v1/seasons?on_conflict=hijri_year",
        "POST",
        SEASONS,
        prefer="resolution=ignore-duplicates,return=minimal",
    )
except urllib.error.HTTPError as e:
    sys.exit(f"INSERT FAILED {e.code}: {e.read().decode()}")

rows = json.loads(
    api("/rest/v1/seasons?select=hijri_year,gregorian_label,is_current"
        "&order=hijri_year.desc")
)
print(f"{len(rows)} season(s) now present:")
for r in rows:
    marker = "  <- current" if r["is_current"] else ""
    print(f"  {r['hijri_year']} AH  {r['gregorian_label']}{marker}")
