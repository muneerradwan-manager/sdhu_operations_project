# -*- coding: utf-8 -*-
"""Thin Supabase admin client: PostgREST for data, GoTrue admin for accounts."""
import os, json, time, urllib.request, urllib.error

BASE = os.environ.get('SUPABASE_URL', 'https://txmtfwdqgosfwdvpgetm.supabase.co')
KEY = os.environ['SUPABASE_SERVICE_KEY']


def call(path, method='GET', body=None, extra=None, retries=3):
    h = {'apikey': KEY, 'Authorization': f'Bearer {KEY}',
         'Content-Type': 'application/json'}
    if extra:
        h.update(extra)
    data = json.dumps(body).encode() if body is not None else None
    last = None
    for attempt in range(retries):
        req = urllib.request.Request(BASE + path, data=data, method=method, headers=h)
        try:
            with urllib.request.urlopen(req) as r:
                raw = r.read().decode()
                return json.loads(raw) if raw.strip() else None
        except urllib.error.HTTPError as e:
            detail = e.read().decode()[:500]
            last = RuntimeError(f'{e.code} {method} {path} :: {detail}')
            if e.code in (429, 500, 502, 503, 504):
                time.sleep(1.5 * (attempt + 1))
                continue
            raise last
        except urllib.error.URLError as e:
            last = RuntimeError(f'{method} {path} :: {e}')
            time.sleep(1.5 * (attempt + 1))
    raise last


def select(table, query='select=*'):
    """Every row, paged — PostgREST caps a response at 1000."""
    out, offset = [], 0
    while True:
        page = call(f'/rest/v1/{table}?{query}',
                    extra={'Range-Unit': 'items',
                           'Range': f'{offset}-{offset + 999}'}) or []
        out.extend(page)
        if len(page) < 1000:
            return out
        offset += 1000


def insert(table, rows, upsert=False):
    if not rows:
        return []
    pref = 'return=representation'
    if upsert:
        pref += ',resolution=merge-duplicates'
    out = []
    for i in range(0, len(rows), 500):        # keep each request small
        got = call(f'/rest/v1/{table}', 'POST', rows[i:i + 500],
                   extra={'Prefer': pref}) or []
        out.extend(got)
    return out


def update(table, query, patch):
    return call(f'/rest/v1/{table}?{query}', 'PATCH', patch,
                extra={'Prefer': 'return=representation'})


def delete(table, query):
    return call(f'/rest/v1/{table}?{query}', 'DELETE',
                extra={'Prefer': 'return=representation'})


def rpc(fn, args=None):
    return call(f'/rest/v1/rpc/{fn}', 'POST', args or {})


# ------------------------------------------------------------------- accounts

def list_auth_users():
    out, page = [], 1
    while True:
        got = call(f'/auth/v1/admin/users?page={page}&per_page=200')
        users = got.get('users', []) if isinstance(got, dict) else []
        out.extend(users)
        if len(users) < 200:
            return out
        page += 1


def create_auth_user(email, password):
    return call('/auth/v1/admin/users', 'POST',
                {'email': email, 'password': password, 'email_confirm': True})


def delete_auth_user(uid):
    return call(f'/auth/v1/admin/users/{uid}', 'DELETE')
