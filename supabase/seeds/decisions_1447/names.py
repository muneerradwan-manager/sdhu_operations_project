# -*- coding: utf-8 -*-
"""Arabic name normalisation and a registry that unifies the same person
appearing under different name forms across the official decisions.

The documents disagree about how much of a name they print:
    3142      'أ. عبد الرزاق قشمير'
    المشاعر    'عبد الرزاق عبد العزيز قشمير'
    3172      'عبد الرزاق قشمير'
All three are one man. The registry keys a person by (first token, last token)
after normalisation, and keeps the LONGEST form seen as the canonical name —
the fuller form is the one the Administration wrote when it had room.
"""
import re, unicodedata

# Honorifics and noise the decisions prefix names with.
_PREFIX = re.compile(r'^\s*(أ\s*\.|الأستاذ|السيد|د\s*\.|م\s*\.)\s*')
_TASHKEEL = re.compile(r'[ؐ-ًؚ-ٰٟۖ-ۭ]')
_TATWEEL = 'ـ'

# Particles that are part of a compound given name, never a surname on their own.
COMPOUND_HEADS = {'عبد', 'أبو', 'ابو', 'أبي', 'بن', 'ابن', 'ذو', 'أم', 'ام'}


def strip_marks(s: str) -> str:
    s = unicodedata.normalize('NFKC', s)
    s = _TASHKEEL.sub('', s)
    # The conversion also leaves stray combining marks ('أحمد د ̆له'), which are
    # not tashkeel and would otherwise split a name from its own spelling.
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn')
    s = s.replace(_TATWEEL, '')
    return s


def normalise(s: str) -> str:
    """Fold the spelling variations that are never meaningful in these files."""
    s = strip_marks(s)
    s = re.sub(r'[آأإٱ]', 'ا', s)   # آ أ إ ٱ -> ا
    s = s.replace('ى', 'ي')                        # ى -> ي
    s = s.replace('ة', 'ه')                        # ة -> ه
    s = s.replace('ؤ', 'و').replace('ئ', 'ي')  # ؤ ئ
    s = re.sub(r'[^ء-ي\s]', ' ', s)           # drop latin/digits/punct
    s = re.sub(r'\s+', ' ', s).strip()
    return s


# Names the conversion broke by dropping a letter and leaving its space behind.
# Each is repaired to the spelling the same man carries in the other decisions.
_NAME_REPAIRS = {
    'أحمد د له': 'أحمد دله',        # 3153; 'أحمد نبهان دلة' elsewhere
    'احمد د له': 'أحمد دله',
}


def clean(raw: str) -> str:
    """A printable name: honorific removed, spacing repaired, spelling kept."""
    s = strip_marks(raw).strip()
    s = _PREFIX.sub('', s)
    s = s.replace('‏', '').replace('‎', '')
    # The conversion sprinkles apostrophes and breves inside words — 'أحمد نبهان
    # د'له'. Dropping them rejoins the word; leaving them splits a surname in two.
    s = re.sub(r"[’'`´˘ˆ˜]", '', s)
    s = re.sub(r'\s+', ' ', s).strip(' -–—:')
    return _NAME_REPAIRS.get(s, s)


# Some cells hold a BODY rather than a man: مخيم 16 in 3172 allots tent space to
# 'الإدارة الصحية' and 'أعضاء اللجنة الاعتبارية' the same way it allots it to
# named members. They are real allocations and belong in the file, but they are
# not people and must never become accounts.
_BODY_HEADS = ('أعضاء', 'عضو ', 'الإدارة', 'الهيئة', 'لجنة', 'اللجنة',
               'فريق', 'قسم', 'مكتب', 'وزارة', 'شركة')


def is_body(raw: str) -> bool:
    n = normalise(clean(raw))
    return bool(n) and n.startswith(tuple(normalise(h) for h in _BODY_HEADS))


def is_placeholder(raw: str) -> bool:
    """Cells that name nobody: '-', '', 'يحدد لاحقاً', a role left open."""
    c = clean(raw)
    if not c or c in {'-', '_', '—', '–'}:
        return True
    n = normalise(c)
    if not n:
        return True
    return n.startswith('يحدد') or n in {'لا يوجد', 'شاغر'}


def is_person(raw: str) -> bool:
    return not is_placeholder(raw) and not is_body(raw)


def tokens(raw: str) -> list:
    return [t for t in normalise(clean(raw)).split(' ') if t]


def bare(surname: str) -> str:
    """A surname without its definite article: الدرويش and درويش are one name.

    The decisions are inconsistent about it — 'حسين درويش' in 3179 is 'حسين محمد
    الدرويش' in 3142 — and no two men in these files are told apart by it.
    """
    s = surname
    if len(s) > 4 and s.startswith('ال'):
        s = s[2:]
    return s


def key_of(raw: str):
    """(first, last) after folding compound given names into one token.

    'عبد الرزاق قشمير' -> ('عبدالرزاق', 'قشمير')
    'عبد الرزاق عبد العزيز قشمير' -> ('عبدالرزاق', 'قشمير')
    """
    ts = tokens(raw)
    if not ts:
        return None
    first = ts[0]
    i = 1
    while first in COMPOUND_HEADS and i < len(ts):
        first = first + ts[i]
        i += 1
    if len(ts) == i:            # a single-token name
        return (first, bare(first))
    last = ts[-1]
    j = len(ts) - 2
    # A surname may itself be compound: '... ابو الشامات', '... الملا طه'.
    if j >= i and ts[j] in COMPOUND_HEADS:
        last = ts[j] + last
        return (first, last)
    return (first, bare(last))


class Registry:
    """Every distinct person named anywhere in the decisions."""

    def __init__(self):
        self.by_key = {}        # (first,last) -> record

    def add(self, raw: str, source: str):
        if is_placeholder(raw):
            return None
        k = key_of(raw)
        if k is None:
            return None
        name = clean(raw)
        rec = self.by_key.get(k)
        if rec is None:
            rec = {'key': k, 'name': name, 'forms': set(), 'sources': set()}
            self.by_key[k] = rec
        # Keep the fullest spelling as canonical.
        if len(tokens(name)) > len(tokens(rec['name'])):
            rec['name'] = name
        rec['forms'].add(name)
        rec['sources'].add(source)
        return k

    def get(self, raw: str):
        k = key_of(raw)
        return self.by_key.get(k) if k else None

    def all(self):
        return sorted(self.by_key.values(), key=lambda r: normalise(r['name']))


def split_name(full: str):
    """(first_name, father_name, surname) as the profiles table wants them."""
    ts = clean(full).split(' ')
    # Rebuild compound given name.
    first_parts = [ts[0]]
    i = 1
    while normalise(first_parts[-1]).split(' ')[0] in COMPOUND_HEADS and i < len(ts):
        first_parts.append(ts[i])
        i += 1
    first = ' '.join(first_parts)
    rest = ts[i:]
    if not rest:
        return first, None, first
    # Surname may be compound ('ابو الشامات', 'الملا طه', 'حاج قدور').
    if len(rest) >= 2 and normalise(rest[-2]) in COMPOUND_HEADS | {'حاج', 'الحاج', 'الملا', 'شيخ', 'الشيخ'}:
        surname = ' '.join(rest[-2:])
        father = ' '.join(rest[:-2]) or None
    else:
        surname = rest[-1]
        father = ' '.join(rest[:-1]) or None
    return first, father, surname
