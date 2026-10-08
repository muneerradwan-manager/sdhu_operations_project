# -*- coding: utf-8 -*-
"""Every person named across the decisions, unified into one roster.

The same man is written three ways across the files — 'أ. عبد الرزاق قشمير',
'عبد الرزاق عبد العزيز قشمير', 'عبد الرزاق قشمير' — so the roster keys him by
(first, last) and keeps the fullest spelling. Where two spellings of a surname
differ only by the conversion's own damage ('دلل' / 'دله' / 'دلله'), an explicit
alias joins them: guessing that two surnames are one is exactly the mistake
that would merge two real men, so it is written down rather than inferred.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import extract as ex
from names import Registry, key_of, clean, normalise

# Surname spellings the decisions disagree about, and the form to settle on.
# Each is one man appearing in several files, confirmed by his post: أحمد نبهان
# دلة runs القطاع الثاني in 3142, القطاع الخامس in المشاعر and المركز 16 in 3172.
SURNAME_ALIASES = {
    'دلل': 'دله', 'دلله': 'دله',
    'حنيفه': 'حنفي', 'حنيفة': 'حنفي',
    'نقاوه': 'نقاوة',
    'الاحمر': 'الأحمر',
    'العبده': 'العبدة',
    'صباغ': 'الصباغ',
    'الفلوط': 'فلوط',
    'بج': 'البج',
    'الخياط': 'خياط',
    'حليمه': 'حليمة',
}

# Men the (first,last) key would wrongly JOIN. 3172 puts 'حسين محمد الفلوط' in
# المركز 13 and 'حسين فلوط' in المركز 16 — one decision, two camps, and nobody
# is distributed to two camps. So they are two men who share a surname, and the
# shorter form is pinned to a key of its own.
FORCE_DISTINCT = {'حسين فلوط'}

# Men written SHORT in one decision and in full in others, where the short form
# drops a middle name and so keys differently — 'عامر مصمص' against 'محمد عامر
# مصمص'. The (first, last) key cannot join those: it is the FIRST name that went
# missing, not the surname.
#
# Each is listed only because the evidence is one-sided: the short form appears
# in exactly one decision, the full form in several, and the two never appear in
# the same list. زاهر حبوباتي is the clearest — 3142 has him running برج 17
# under محمد ذكرى, and المشاعر has محمد زاهر عماد الدين حبوباتي in that same
# man's قطاع.
NAME_MERGES = {
    'زاهر حبوباتي': 'محمد زاهر عماد الدين حبوباتي',
    'طاهر عبد الحميد': 'طاهر عبد الحميد الشاوي',
    'عامر مصمص': 'محمد عامر مصمص',
    'كرم حاتم': 'كرم حاتم الحاجي مصطفى',
    'مصطفى حاج قدور': 'مصطفى كمال حاج قدور كوسة',
}


def _alias(k):
    if k is None:
        return None
    first, last = k
    return (first, normalise(SURNAME_ALIASES.get(last, last)))


def person_key(raw):
    """The key everything else must agree on: aliases folded, clashes pinned."""
    name = clean(raw)
    if name in FORCE_DISTINCT:
        return ('=' + normalise(name), '')
    return _alias(key_of(NAME_MERGES.get(name, name)))


class Roster(Registry):
    def add(self, raw, source):
        k = super().add(raw, source)
        return k

    def _key(self, raw):
        return _alias(key_of(raw))


def build():
    """Walk every decision and collect the people, with where each was seen."""
    r = Registry()
    # Fold aliases in by overriding how a key is computed.
    orig_key = key_of

    def add(raw, src):
        k = person_key(raw)
        if k is None:
            return
        from names import is_person, clean as _c, tokens
        if not is_person(raw):
            return
        name = _c(raw)
        rec = r.by_key.get(k)
        if rec is None:
            rec = {'key': k, 'name': name, 'forms': set(), 'sources': set()}
            r.by_key[k] = rec
        if len(tokens(name)) > len(tokens(rec['name'])):
            rec['name'] = name
        rec['forms'].add(name)
        rec['sources'].add(src)

    # 3142 — sectors and towers
    for s in ex.makkah_sectors_towers():
        add(s['supervisor'], '3142/مشرف قطاع')
        if s['deputy']:
            add(s['deputy'], '3142/معاون قطاع')
        for t in s['towers']:
            add(t['supervisor'], '3142/مشرف برج')
            for d in t['deputies']:
                add(d, '3142/نائب برج')

    # flat rosters
    for src, fn in [('3144', ex.tawafa_transport), ('3147', ex.airport_reception),
                    ('3150', ex.central_aviation), ('3151', ex.financial_administration),
                    ('3152', ex.oversight_complaints), ('3153', ex.follow_up_evaluation)]:
        head, members = fn()
        if head:
            add(head, f'{src}/رأس')
        for m in members:
            add(m, f'{src}/عضو')

    for src, fn in [('3145', ex.central_catering), ('3146', ex.construction),
                    ('3148', ex.mission_offices)]:
        for label, who in fn():
            if who:
                add(who, f'{src}/{label}')

    # المشاعر
    secs, co, mon = ex.mashaaer_teams()
    for s in secs:
        if s['supervisor']:
            add(s['supervisor'], 'مشاعر/مشرف قطاع')
        if s['deputy']:
            add(s['deputy'], 'مشاعر/معاون قطاع')
        for who in s['tarwiyah']:
            add(who, 'مشاعر/تروية')
        for who in s['arafat']:
            add(who, 'مشاعر/عرفات')
    if co['manager']:
        add(co['manager'], 'مشاعر/مدير الكوسترات')
    if co['deputy']:
        add(co['deputy'], 'مشاعر/معاون الكوسترات')
    for who in co['members']:
        add(who, 'مشاعر/كوسترات')
    for who in mon:
        add(who, 'مشاعر/مراقبة إعاشة')

    # 3172 عرفات
    for c in ex.arafat_centers():
        add(c['supervisor'], '3172/مشرف مركز')
        for cm in c['camps']:
            for who in cm['members']:
                add(who, '3172/عضو مخيم')

    # 3179 المدينة
    m = ex.madinah_office()
    for role, who in m['coordinators']:
        add(who, f'3179/منسق {role}')
    for team, v in m['teams'].items():
        if v['head']:
            add(v['head'], f'3179/{team} رأس')
        for who in v['members']:
            add(who, f'3179/{team}')
    for comp in m['companies']:
        for who in comp['guides']:
            add(who, '3179/دليل')

    # 3190 — a further team of the same Madinah office, and its accountant
    head, members, accountant = ex.madinah_departures()
    if head:
        add(head, '3190/مشرف الترحيل')
    for who in members:
        add(who, '3190/عضو الترحيل')
    if accountant:
        add(accountant, '3190/محاسب المكتب')

    # 3197 لجنة 5 نجوم
    chair, members = ex.five_star_panel()
    if chair:
        add(chair, '3197/رئيس')
    for who in members:
        add(who, '3197/عضو')

    return r


if __name__ == '__main__':
    r = build()
    people = r.all()
    print(f'total distinct people: {len(people)}\n')
    multi = [p for p in people if len(p['forms']) > 1]
    print(f'--- {len(multi)} people written more than one way ---')
    for p in multi:
        print(f"  {p['name']:38} <- {' | '.join(sorted(p['forms']))}")
    print()
    print('--- everyone ---')
    for p in people:
        print(f"  {p['name']:40} ({len(p['sources'])} posts)")
