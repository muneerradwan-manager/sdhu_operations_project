# -*- coding: utf-8 -*-
"""Turn the official decisions into the shape the operational files have.

One function per decision, because the decisions are not one shape: 3142 is a
tree of sectors and towers, 3144 is a bare roster, 3172 is centers and camps.
Guessing a common shape would be a way of getting one of them wrong quietly.
"""
import re, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import docparse as dp
from names import clean, is_placeholder, is_person, normalise

# Repairs for the PDF→Word conversion, which splits some letters from their word
# ('عف ارء') and reverses parentheses. Applied to PLACE names only; people are
# matched by the registry instead.
_FIXES = {
    'عف ارء': 'عفراء',
    'مي ازب الخير': 'ميازب الخير',
    'ازد اليقين': 'أزد اليقين',
    'دفلى 2': 'دفلى 2',
    'كنوز الرحمة )صبغة(': 'كنوز الرحمة (صبغة)',
    'فيلفيت ان )الهدى(': 'فيلفيت ان (الهدى)',
    'سنود المشاعر1': 'سنود المشاعر 1',
}


def place(s):
    s = clean(s)
    s = _FIXES.get(s, s)
    s = s.replace(')', '(').replace('(', ')') if False else s
    return re.sub(r'\s+', ' ', s).strip()


def people(cell):
    """Names in one cell — one per paragraph, placeholders dropped."""
    return [clean(x) for x in getattr(cell, 'lines', []) if is_person(x)]


# ---------------------------------------------------------------- 3142 towers

def makkah_sectors_towers():
    """قطاعات وأبراج حجاج سوريا في مكة المكرمة — 5 sectors, 20 towers.

    Columns: معاون مشرف القطاع | مشرف القطاع | نائب مشرف البرج | مشرف البرج |
             اسم التكتل | الفندق | #
    A sector cell written across BOTH sector columns means that sector has a
    مشرف and no معاون — not that the same man holds both.
    """
    g = dp.tables_of('3142')[0]
    sectors, by_sup = [], {}
    for row in g[1:]:
        sup_cell, dep_cell = row[1], row[0]
        supervisor = clean(sup_cell.text)
        deputy = None if sup_cell.span > 1 else (
            clean(dep_cell.text) if not is_placeholder(dep_cell.text) else None)
        if supervisor not in by_sup:
            sec = {'label': f'القطاع {len(sectors) + 1}',
                   'supervisor': supervisor, 'deputy': deputy, 'towers': []}
            sectors.append(sec)
            by_sup[supervisor] = sec
        sec = by_sup[supervisor]
        clusters = [place(c) for c in re.split(r'\s*/\s*', row[4].text) if c.strip()]
        sec['towers'].append({
            'no': int(re.sub(r'\D', '', row[6].text) or 0),
            'hotel': place(row[5].text),
            'clusters': clusters,
            'supervisor': clean(row[3].text),
            'deputies': people(row[2]),
        })
    return sectors


# ------------------------------------------------------- flat roster decisions

def _roster(fragment, table=0, mark='مشرفا'):
    """A decision that is just a list of people, one of them marked as its head.

    The head carries a suffix ('- مشرفاً', '- منسقاً'); everyone else is a member.
    """
    g = dp.tables_of(fragment)[table]
    head, members = None, []
    for row in g:
        seen = set()
        for c in row:
            if not c.origin or c.text in seen:
                continue
            seen.add(c.text)
            raw = c.text
            if is_placeholder(raw):
                continue
            if '-' in raw and mark in normalise(raw):
                head = clean(re.split(r'\s*[-–]\s*', raw)[0])
            else:
                members.append(clean(raw))
    return head, members


def tawafa_transport():
    return _roster('3144')


def airport_reception():
    return _roster('3147')


def central_aviation():
    return _roster('3150')


def financial_administration():
    return _roster('3151')


def oversight_complaints():
    return _roster('3152', mark='منسقا')


def follow_up_evaluation():
    return _roster('3153')


def _labelled(fragment):
    """A two-column decision: the post on one side, the person on the other."""
    out = []
    for row in dp.tables_of(fragment)[0]:
        cells = [c for c in row if c.origin]
        if len(cells) < 2:
            continue
        label, who = clean(cells[0].text), clean(cells[1].text)
        out.append((label, None if is_placeholder(who) else who))
    return out


def central_catering():
    return _labelled('3145')


def construction():
    return _labelled('3146')


def mission_offices():
    return _labelled('3148')


# ------------------------------------------------------------ مشاعر teams

_TEAM_HEADS = {'فريق التروية': 'tarwiyah',
               'فريق عرفات': 'arafat',
               'فريق منى أيام التشريق': 'mina'}


def mashaaer_teams():
    """تشكيل فرق المشاعر — 7 sectors, each with تروية/عرفات teams, plus the
    coasters team and the Mashaaer catering monitors at file level.

    منى أيام التشريق lists no names of its own: its table repeats the headings
    'فريق عرفات' and 'فريق التروية', which is the decision saying that both
    teams serve during Tashreeq. So its membership is the union of the two.
    """
    seq = dp.body('فرق المشاعر')
    sectors, pending_label, current = [], None, None
    coasters = {'manager': None, 'deputy': None, 'members': []}
    monitors = []
    mode = 'sectors'

    for kind, payload in seq:
        if kind == 'p':
            t = clean(payload)
            m = re.match(r'^القطاع\s+(\S+)\s*:?$', t)
            if m:
                pending_label = t.rstrip(':')
            elif 'الكوسترات' in t:
                mode = 'coasters'
            elif 'إعاشة المشاعر' in t or 'اعاشة المشاعر' in normalise(t):
                mode = 'monitors'
            continue

        g = payload
        if mode == 'sectors':
            head = clean(g[0][0].text) + ' ' + clean(g[0][-1].text)
            if 'مشرف القطاع' in head:
                sup = dep = None
                for c in g[0]:
                    if not c.origin:
                        continue
                    txt = clean(c.text)
                    if ':' not in txt:
                        continue
                    who = clean(txt.split(':', 1)[1])
                    if txt.startswith('معاون مشرف القطاع'):
                        dep = None if is_placeholder(who) else who
                    elif txt.startswith('مشرف القطاع'):
                        sup = None if is_placeholder(who) else who
                current = {'label': pending_label or f'القطاع {len(sectors)+1}',
                           'supervisor': sup, 'deputy': dep,
                           'tarwiyah': [], 'arafat': []}
                sectors.append(current)
                pending_label = None
                rows = g[1:]
            else:
                rows = g            # a table continued across a page break
            if current is None:
                continue
            team = current.get('_team')
            for row in rows:
                first = clean(row[0].text)
                if first in _TEAM_HEADS:
                    team = _TEAM_HEADS[first]
                    current['_team'] = team
                    continue
                if team in ('tarwiyah', 'arafat'):
                    seen = set()
                    for c in row:
                        if not c.origin or c.text in seen:
                            continue
                        seen.add(c.text)
                        if not is_placeholder(c.text):
                            current[team].append(clean(c.text))
        elif mode == 'coasters':
            for row in g:
                seen = set()
                for c in row:
                    if not c.origin or c.text in seen:
                        continue
                    seen.add(c.text)
                    t = clean(c.text)
                    if is_placeholder(t):
                        continue
                    if t.startswith('مدير الفريق'):
                        coasters['manager'] = clean(t.split(':', 1)[1])
                    elif t.startswith('معاون مدير الفريق'):
                        coasters['deputy'] = clean(t.split(':', 1)[1])
                    else:
                        coasters['members'].append(t)
            mode = None
        elif mode == 'monitors':
            for row in g:
                seen = set()
                for c in row:
                    if not c.origin or c.text in seen:
                        continue
                    seen.add(c.text)
                    if not is_placeholder(c.text):
                        monitors.append(clean(c.text))
            mode = None

    for s in sectors:
        s.pop('_team', None)
        # منى أيام التشريق = both teams, as the decision's own table says.
        s['mina'] = list(dict.fromkeys(s['tarwiyah'] + s['arafat']))
    return sectors, coasters, monitors


# ------------------------------------------------------------- 3172 عرفات

def arafat_centers():
    """توزيع أعضاء المكاتب على مخيمات عرفات — مركز, its مشرف, its مخيمات.

    A مخيم is 'رقم المخيم: N' with 'رقم الخيمة' beside it; a center may hold
    more than one (مركز 16 has tents 154 and 158), and the second arrives as a
    table with no مشرف row of its own.
    """
    seq = dp.body('3172')
    centers, current, pending = [], None, None
    for kind, payload in seq:
        if kind == 'p':
            m = re.match(r'^المركز\s+رقم\s+(\d+)', clean(payload))
            if m:
                pending = m.group(1)
            continue
        g = payload
        head = ' '.join(clean(c.text) for c in g[0] if c.origin)
        if 'مشرف المركز' in head:
            sup = clean(head.split(':', 1)[1])
            current = {'no': pending, 'supervisor': sup, 'camps': []}
            centers.append(current)
            pending = None
            rows = g[1:]
        else:
            rows = g
        if current is None:
            continue
        camp = None
        for row in rows:
            joined = ' '.join(clean(c.text) for c in row if c.origin)
            if 'رقم المخيم' in joined:
                camp_no = tent = None
                for c in row:
                    if not c.origin:
                        continue
                    t = clean(c.text)
                    if t.startswith('رقم المخيم'):
                        camp_no = clean(t.split(':', 1)[1])
                    elif t.startswith('رقم الخيمة'):
                        tent = clean(t.split(':', 1)[1])
                camp = {'no': camp_no, 'tents': tent, 'members': [], 'bodies': []}
                current['camps'].append(camp)
                continue
            if camp is None:
                continue
            seen = set()
            for c in row:
                if not c.origin or c.text in seen:
                    continue
                seen.add(c.text)
                if is_person(c.text):
                    camp['members'].append(clean(c.text))
                elif not is_placeholder(c.text):
                    # A BODY holding tent space — 'الإدارة الصحية'. It is a real
                    # allocation and stays on the camp, but it is not a man and
                    # cannot be given an account.
                    camp['bodies'].append(clean(c.text))
    return centers


# ------------------------------------------------------- 3179 Madinah office

# 3179 was converted with the same broken glyph map as 3197 — 'م' arrives as
# 'ة', 'ن' as 'ف', 'ك' as '2'. Only the headings and two company names are hit,
# and every one of them is named in full elsewhere in the same decision set.
_P3179 = {
    'عدناف باجار': 'عدنان باجاري',        # 3146 مشرف الإنشاءات
    'ةعاذ العثماف': 'معاذ العثمان',       # 3150 مشرف الطيران المركزي
    'شركة هوليد إف': 'شركة هوليداي إن',
    'شركة أبراج ة2ة': 'شركة أبراج مكة',
}


def _fix79(s):
    return _P3179.get(clean(s), clean(s))


def madinah_office():
    """فرق ولجان المكتب الإداري في المدينة المنورة.

    Six teams and two coordinators; فريق شركة الخدمة is a list of COMPANIES,
    each with its own أدلاء, so it comes back keyed by company. A guide's
    company cell is vertically merged, so a new company starts only where the
    cell was actually written — not where Word repeated it.
    """
    seq = dp.body('3179')
    out = {'coordinators': [], 'teams': {}, 'companies': []}
    label = None
    for kind, payload in seq:
        if kind == 'p':
            t = clean(payload)
            m = re.match(r'^(?:-\s*)?السيد\s+(.+?)\s+منسق', t)
            if m:
                role = 'office' if 'المكتب الإداري' in t else 'travel'
                out['coordinators'].append((role, clean(m.group(1))))
            elif 'تس' in t and 'الحجاج' in t:
                label = 'housing'
            elif 'شركة الخدمة' in t or 'الأدل' in t:
                label = 'companies'
            elif 'المطار' in t:
                label = 'airport'
            elif 'المركز' in t and ('الطي' in t or 'طيران' in t):
                label = 'aviation'
            elif 'الحقائ' in t:
                label = 'baggage'
            continue
        g = payload
        if label == 'companies':
            company = None
            for row in g:
                cells = [c for c in row if c.origin]
                if len(cells) < 2:
                    continue
                guide_cell, comp_cell = cells[0], cells[1]
                comp = _fix79(comp_cell.text)
                # A company written down starts a new one; one carried down by
                # the merge belongs to the company already open.
                if comp and not is_placeholder(comp) and not comp_cell.vfill:
                    company = {'name': comp, 'guides': []}
                    out['companies'].append(company)
                if company and is_person(guide_cell.text):
                    company['guides'].append(clean(guide_cell.text))
            label = None
            continue
        head, members = None, []
        for row in g:
            seen = set()
            for c in row:
                if not c.origin or c.text in seen:
                    continue
                seen.add(c.text)
                raw = c.text
                if is_placeholder(raw):
                    continue
                # '- مشرفاً' survives the mangling only as 'ةمرفا˝', so the
                # marker is the dash plus a مشرف-shaped tail, not the word.
                if re.search(r'[-–]\s*[ةم]?مرفا|[-–]\s*مشرفا', raw):
                    head = _fix79(re.split(r'\s*[-–]\s*', raw)[0])
                else:
                    members.append(clean(raw))
        if label:
            out['teams'][label] = {'head': head, 'members': members}
        label = None
    return out


# ------------------------------------------- 3190 Madinah departures follow-up

def madinah_departures():
    """فريق متابعة ترحيل وسفر الحجاج من المدينة المنورة — 3190.

    A further team of the SAME office 3179 formed, signed by that office's own
    director, so it lands in the Madinah file beside the others rather than
    opening a second one. The decision also names the office's محاسب, in a
    clause of its own.

    Returns (supervisor, members, accountant).
    """
    g = dp.tables_of('3190')[0]
    head, members = None, []
    for row in g:
        seen = set()
        for c in row:
            if not c.origin or c.text in seen:
                continue
            seen.add(c.text)
            raw = c.text
            if not is_person(raw):
                continue
            if re.search(r'[-–]\s*مشرفا', raw):
                head = clean(re.split(r'\s*[-–]\s*', raw)[0])
            else:
                members.append(clean(raw))

    # 'ثالثاً- يكلّف السيد محمد مصمص محاسباً للمكتب الإداري في المدينة المنورة.'
    accountant = None
    for kind, payload in dp.body('3190'):
        if kind != 'p':
            continue
        m = re.search(r'السيد\s+(.+?)\s+محاسبا', clean(payload))
        if m:
            accountant = clean(m.group(1))
            break
    return head, members, accountant


# ------------------------------------------------------- 3197 five-star panel

# 3197 was converted with a broken glyph map, so its four names arrive mangled.
# All four are named in full in other decisions, and each mangled form has only
# one candidate among them, so they are repaired by hand rather than guessed.
_P3197 = {
    'دحمد دلحدد': 'أحمد الحداد',        # رئيس المكتب الإداري, signs 3142–3153
    'ح~س نقLو': 'حسن نقاوة',            # 3146 مسؤول المواقع والمخيمات
    'عدنLن بLجLري': 'عدنان باجاري',     # 3146 مشرف الإنشاءات
    'موسى ويس': 'موسى محمد ويس',        # المشاعر, القطاع السادس
}


def five_star_panel():
    """لجنة دراسة الخدمات المقدمة لحجاج مستوى 5 نجوم — a chair and three members."""
    g = dp.tables_of('3197')[0]
    chair, members = None, []
    for row in g:
        seen = set()
        for c in row:
            if not c.origin or c.text in seen:
                continue
            seen.add(c.text)
            raw = c.text
            if is_placeholder(raw):
                continue
            if 'رئي' in raw and '-' in raw:
                chair = _P3197.get(clean(re.split(r'\s*[-–]\s*', raw)[0]),
                                   clean(re.split(r'\s*[-–]\s*', raw)[0]))
            else:
                members.append(_P3197.get(clean(raw), clean(raw)))
    return chair, members
