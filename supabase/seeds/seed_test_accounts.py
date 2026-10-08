#!/usr/bin/env python3
"""
Seed test accounts for hajjoperations.

Auth users cannot be created with plain SQL (auth.users needs a properly hashed
password), so this uses the Supabase Admin REST API. It:
  1. POST /auth/v1/admin/users        -> creates a confirmed auth user
     (a profiles row is auto-created as 'incomplete' by the on_auth_user_created trigger)
  2. PATCH /rest/v1/profiles?id=eq.X  -> fills the profile and sets account_status

Requires the SERVICE (secret) key. NEVER ship this key in the app.

Usage:
  SUPABASE_URL=https://txmtfwdqgosfwdvpgetm.supabase.co \
  SUPABASE_SERVICE_KEY=sb_secret_xxx \
  python supabase/seeds/seed_test_accounts.py

All accounts use password: Passw0rd!23
"""
import os, sys, json, urllib.request

BASE = os.environ.get("SUPABASE_URL", "https://txmtfwdqgosfwdvpgetm.supabase.co")
KEY = os.environ.get("SUPABASE_SERVICE_KEY")
PASSWORD = "Passw0rd!23"

if not KEY:
    sys.exit("Set SUPABASE_SERVICE_KEY (the sb_secret_... key).")

def api(path, method="GET", body=None):
    req = urllib.request.Request(
        BASE + path,
        data=(json.dumps(body).encode() if body is not None else None),
        method=method,
        headers={
            "apikey": KEY,
            "Authorization": f"Bearer {KEY}",
            "Content-Type": "application/json",
        },
    )
    return urllib.request.urlopen(req).read()

def set_items(code):
    """name -> id for one reference list (0085 moved both of these into it)."""
    rows = json.loads(api(
        "/rest/v1/reference_items"
        f"?select=id,name_ar,reference_sets!inner(code)&reference_sets.code=eq.{code}"
    ))
    return {r["name_ar"]: r["id"] for r in rows}

# name -> job description (must exist from 0010_seed_job_titles.sql, moved by 0085)
JT = set_items("job_titles")
MISSIONS = set_items("mission_types")
EMPLOYEE_JT = JT.get("موظف إداري")

# email, first, father, surname, gender, mission, job_title_id, phone, status
ACCOUNTS = [
    ("ahmad.test@example.com",  "أحمد", "محمد",   "الحلبي",     "male",   MISSIONS.get("البعثة الإدارية"), JT.get("نائب رئيس البعثة"), "0999111222", "approved"),
    ("fatima.test@example.com", "فاطمة","علي",    "الدمشقي",    "female", MISSIONS.get("البعثة الطبية"),        JT.get("طبيب"),            "0999333444", "approved"),
    ("omar.test@example.com",   "عمر",  "خالد",   "الحمصي",     "male",   MISSIONS.get("البعثة الدينية"),      JT.get("مدير إداري"),      "0999555666", "approved"),
    ("layla.test@example.com",  "ليلى", "حسن",    "اللاذقاني",  "female", MISSIONS.get("البعثة الإدارية"), JT.get("مشرف"),            "0999777888", "approved"),
    ("yousef.test@example.com", "يوسف", "إبراهيم","الحموي",     "male",   MISSIONS.get("البعثة الطبية"),        JT.get("طبيب"),            "0999999000", "approved"),
    ("khaled.pending@example.com","خالد","سمير",  "العبدالله",  "male",   MISSIONS.get("البعثة الإدارية"), EMPLOYEE_JT,               "0988111000", "pending"),
    ("noor.pending@example.com", "نور",  "ماجد",   "الخطيب",     "female", MISSIONS.get("البعثة الطبية"),        EMPLOYEE_JT,               "0988222000", "pending"),
]

for email, first, father, surname, gender, mission, jt, phone, status in ACCOUNTS:
    try:
        resp = json.loads(api("/auth/v1/admin/users", "POST",
            {"email": email, "password": PASSWORD, "email_confirm": True}))
        uid = resp.get("id")
    except Exception as e:
        print("SKIP (exists?)", email, e)
        continue
    if not uid:
        print("NO UID", email, resp)
        continue
    body = {
        "first_name": first, "father_name": father, "surname": surname,
        "gender": gender, "mission_type_id": mission, "job_title_id": jt,
        "phone_sy": phone, "date_of_birth": "1990-01-15",
        "account_status": status,
    }
    try:
        api(f"/rest/v1/profiles?id=eq.{uid}", "PATCH", body)
        print("OK", status, email)
    except Exception as e:
        print("PATCH ERR", email, e)
