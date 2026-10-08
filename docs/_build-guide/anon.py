# -*- coding: utf-8 -*-
"""Fake names on the way IN: the guides never show a real person.

The app is captured against the LIVE database, and nearly every management
screen is a list of real staff. Blurring them leaves a guide full of smudges;
this instead rewrites the data between Supabase and the browser, so the app
draws a believable, consistent cast of fake people — the same arrangement the
testing-website guides have with their demo data ("جميع الأسماء وهمية").

Nothing is written anywhere. Responses are rewritten in the browser's network
layer only; the database is read, never changed.

How a real person is recognised:
  * by key — first_name / father_name / surname, every *_name that holds a
    person (reporter_name, author_name, …), phones, emails, photo and document
    URLs;
  * by value — the full list of staff names is read once at start-up, so a
    name copied into free text (a notification body, an audit-log diff) is
    replaced too.
Mapping is deterministic: the same real name becomes the same fake name in
every screenshot, so a person who appears on two screens stays one person.
"""
import hashlib, json, re, urllib.request
from pathlib import Path

ROOT = Path(__file__).parent
ENV = ROOT.parents[1] / ".env"

GIVEN_M = ["أحمد", "محمد", "خالد", "عمر", "يوسف", "سامر", "باسل", "ماهر", "حسان", "رامي", "طارق", "وسيم",
           "فادي", "نزار", "مازن", "هشام", "زياد", "أنس", "بلال", "معاذ", "جهاد", "عماد", "غسان", "لؤي",
           "مهند", "ناصر", "قصي", "رضا", "إياد", "صهيب", "عدنان", "فراس", "حمزة", "كنان", "مروان", "وائل"]
GIVEN_F = ["فاطمة", "مريم", "سلمى", "رنا", "هالة", "ديما", "لمى", "نسرين", "رهف", "سوسن", "منى", "علا",
           "ريم", "هبة", "سماح", "نور", "لينا", "دعاء", "أسماء", "رغد", "بشرى", "جمانة", "سهى", "ميساء"]
FAMILY = ["الحلبي", "الدمشقي", "الحمصي", "الحموي", "الإدلبي", "اللاذقاني", "الطرطوسي", "الدرعاوي", "الرقاوي",
          "الشامي", "العطار", "الخطيب", "النجار", "الصباغ", "الكيالي", "الأيوبي", "البيطار", "الزعبي",
          "الحوراني", "السقا", "القباني", "المصري", "الحسيني", "الجابي", "الشهابي", "العلي", "السيد", "الحكيم",
          "الخياط", "الدباغ", "الملا", "الزين", "البغدادي", "الطويل", "القاسم", "الرفاعي"]

PERSON_KEYS = {"full_name", "actor_name", "author_name", "complainant_name", "confirmed_by_name",
               "evaluator_name", "handled_by_name", "owner_name", "reporter_name", "subject_name",
               "display_name", "employee_name", "assignee_name", "assigned_by_name", "created_by_name",
               "member_name", "person_name", "user_name", "decided_by_name"}
PHONE_KEYS = {"phone", "phone_sy", "phone_sa", "reporter_phone", "subject_phone", "mobile", "whatsapp"}
NULL_KEYS = {"photo_url", "actor_photo_url", "author_photo_url", "complainant_photo_url",
             "evaluator_photo_url", "avatar_url", "passport_image_url", "visa_image_url",
             "nusuk_card_image_url", "subject_photo_url", "reporter_photo_url", "owner_photo_url"}
# Keyboard-mash entries left in the live data by testing. Exact values only —
# a generic "looks like gibberish" rule would also hit enum values the app
# depends on. Found from ascii_seen (see dump_ascii); extend as new ones appear.
JUNK = {
    "srthsrth": "تعطّل حافلة النقل عند مدخل مخيّم منى",
    "ddzzdfbdzfbdzfb": "تأخّر وصول وجبة الغداء إلى فندق المجموعة الثالثة",
    "dfsgbaDB": "حاجّ مفقود قرب جسر الجمرات",
    "fgbhgb": "انقطاع الكهرباء في الطابق الرابع من الفندق",
    "ibuuvuhuvuvu": "تعطّل المصعد في فندق المجموعة الأولى",
    "lvjvj": "تقييم أداء العاملين في الملف",
    "Jvjvj": "تقييم أداء العاملين في الملف",
    "Jvjvg": "تقييم أداء العاملين في الملف",
    "Hvhvhvjvj": "هل التزم بمواعيد مناوبته طوال الموسم؟",
    "Gjvjvjv": "نعم، والتزم بها دون تأخير.",
}
ASCII_RE = re.compile(r"[A-Za-z]{4,}")
EMAIL_RE = re.compile(r"[\w.+-]+@[\w-]+(\.[\w-]+)+")
PHONE_RE = re.compile(r"^\+?[\d٠-٩][\d٠-٩ \-]{7,15}$")


def _h(s, n):
    return int(hashlib.sha1(s.encode("utf-8")).hexdigest(), 16) % n


def env():
    return dict(l.split("=", 1) for l in ENV.read_text("utf-8").splitlines() if "=" in l)


class Anon:
    def __init__(self, email, password):
        e = env()
        self.url, self.key = e["SUPABASE_URL"].strip(), e["SUPABASE_ANON_KEY"].strip()
        self.real_emails = {}
        self.ascii_seen = set()
        self.tok_given, self.tok_family = {}, {}
        self.variants = []          # (real, fake), longest first
        self.people = self._load(email, password)
        self._build()

    # ── the real cast, read once ────────────────────────────────────────
    def _req(self, path, body=None, token=None, method=None):
        h = {"apikey": self.key, "Content-Type": "application/json"}
        if token:
            h["Authorization"] = f"Bearer {token}"
        r = urllib.request.Request(self.url + path, data=json.dumps(body).encode() if body else None,
                                   headers=h, method=method or ("POST" if body else "GET"))
        with urllib.request.urlopen(r) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else None

    def _load(self, email, password):
        t = self._req("/auth/v1/token?grant_type=password", {"email": email, "password": password})
        tok = t["access_token"]
        try:
            rows = self._req("/rest/v1/profiles?select=id,first_name,father_name,surname,gender"
                             "&limit=20000", token=tok)
        finally:
            try:
                # scope=local: only THIS throwaway session. The default is
                # global, which would sign the admin out on every device.
                self._req("/auth/v1/logout?scope=local", {}, token=tok)
            except Exception:
                pass
        return rows or []

    def _fake_given(self, real, female=False):
        if not real:
            return real
        m = self.tok_given
        if (real, female) not in m:
            pool = GIVEN_F if female else GIVEN_M
            m[(real, female)] = pool[_h(real, len(pool))]
        return m[(real, female)]

    def _fake_family(self, real):
        if not real:
            return real
        if real not in self.tok_family:
            self.tok_family[real] = FAMILY[_h(real, len(FAMILY))]
        return self.tok_family[real]

    def _build(self):
        pairs = {}
        for p in self.people:
            f, fa, s = (p.get("first_name") or "").strip(), (p.get("father_name") or "").strip(), (p.get("surname") or "").strip()
            fem = (p.get("gender") == "female")
            F, FA, S = self._fake_given(f, fem), self._fake_given(fa), self._fake_family(s)
            for real, fake in (((f, fa, s), (F, FA, S)), ((f, s), (F, S)), ((f, fa), (F, FA))):
                if all(real) and len(" ".join(real)) >= 5:
                    pairs[" ".join(real)] = " ".join(fake)
            if f and fa and s:
                pairs[f"{f}{fa} {s}"] = f"{F} {FA} {S}"
        self.variants = sorted(pairs.items(), key=lambda kv: -len(kv[0]))
        self.real_tokens = {(p.get("first_name") or "").strip() for p in self.people} | \
                           {(p.get("surname") or "").strip() for p in self.people}
        self.real_tokens.discard("")

    # ── rewriting ──────────────────────────────────────────────────────
    def fake_email(self, real):
        if real not in self.real_emails:
            self.real_emails[real] = f"user{len(self.real_emails) + 1:02d}@example.com"
        return self.real_emails[real]

    def fake_phone(self, real, key=""):
        d = f"{_h(real, 10 ** 7):07d}"
        return ("+9665" if key.endswith("_sa") else "09") + ("3" + d)[:8]

    def text(self, s):
        for junk, fine in JUNK.items():
            if junk in s:
                s = s.replace(junk, fine)
        for real, fake in self.variants:
            if real in s:
                s = s.replace(real, fake)
        return EMAIL_RE.sub(lambda m: self.fake_email(m.group(0)), s)

    def person(self, s):
        """A whole person-name string: known variant, else token by token."""
        t = self.text(s)
        if t != s:
            return t
        toks = s.split()
        if not toks:
            return s
        out = [self._fake_given(x) for x in toks[:-1]] + [self._fake_family(toks[-1]) if len(toks) > 1 else self._fake_given(toks[-1])]
        return " ".join(out)

    def walk(self, v, key=""):
        if isinstance(v, dict):
            fem = v.get("gender") == "female"
            out = {}
            for k, x in v.items():
                if k in NULL_KEYS:
                    out[k] = None
                elif isinstance(x, str) and k == "first_name":
                    out[k] = self._fake_given(x.strip(), fem)
                elif isinstance(x, str) and k == "father_name":
                    out[k] = self._fake_given(x.strip())
                elif isinstance(x, str) and k == "surname":
                    out[k] = self._fake_family(x.strip())
                elif isinstance(x, str) and k in PERSON_KEYS:
                    out[k] = self.person(x)
                elif isinstance(x, str) and (k in PHONE_KEYS or (PHONE_RE.match(x) and "phone" in k)):
                    out[k] = self.fake_phone(x, k)
                elif isinstance(x, str) and k == "email":
                    out[k] = self.fake_email(x)
                elif isinstance(x, str) and k == "date_of_birth":
                    out[k] = "1985-01-01"
                else:
                    out[k] = self.walk(x, k)
            return out
        if isinstance(v, list):
            return [self.walk(x, key) for x in v]
        if isinstance(v, str):
            if v.startswith("http") or len(v) > 4000:
                return v
            if v in JUNK:
                return JUNK[v]
            if ASCII_RE.fullmatch(v):
                self.ascii_seen.add((key, v))
            return self.text(v)
        return v

    def leaks(self, texts):
        """Real names still visible in a list of on-screen texts (safety net)."""
        found = []
        for t in texts:
            for real, _ in self.variants:
                if real in t:
                    found.append(real)
            for m in EMAIL_RE.finditer(t):
                if not m.group(0).endswith("@example.com"):
                    found.append(m.group(0))
        return sorted(set(found))

    # ── Playwright hook ────────────────────────────────────────────────
    def install(self, ctx):
        def handle(route):
            try:
                resp = route.fetch()
            except Exception:
                return route.continue_()
            ct = resp.headers.get("content-type", "")
            body = resp.body()
            if "json" not in ct or not body:
                return route.fulfill(response=resp)
            try:
                data = json.loads(body)
            except Exception:
                return route.fulfill(response=resp)
            # The body is re-encoded, so the original length and compression
            # headers no longer describe it and must not be passed on.
            hdrs = {k: v for k, v in resp.headers.items()
                    if k.lower() not in ("content-length", "content-encoding", "transfer-encoding")}
            return route.fulfill(status=resp.status, headers=hdrs,
                                 body=json.dumps(self.walk(data), ensure_ascii=False).encode("utf-8"))
        host = self.url.split("//", 1)[1]
        ctx.route(f"**://{host}/rest/v1/**", handle)
        ctx.route(f"**://{host}/auth/v1/**", handle)
        ctx.route(f"**://{host}/functions/v1/**", handle)

    def dump_ascii(self, path):
        Path(path).write_text("\n".join(f"{k}\t{v}" for k, v in sorted(self.ascii_seen)), "utf-8")
