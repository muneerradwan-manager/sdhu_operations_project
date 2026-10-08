# -*- coding: utf-8 -*-
"""Build season 1447's operational files from the official decisions.

Every file is created once for the season, its tree is entered from the
decision that established it, and each man is placed where that decision put
him. Nothing here invents a post: where a decision leaves one open ('مختص
إعاشة: يحدد لاحقاً', a قطاع with no معاون) the post is simply left unfilled.
"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sbx, roster, extract as ex
from names import key_of, normalise, bare

SEASON_YEAR = 1447
HERE = os.path.dirname(os.path.abspath(__file__))

ORDINALS = ['', 'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس',
            'السابع', 'الثامن', 'التاسع', 'العاشر']

# The date each decision set its file's work going. 3142–3153 are all issued
# 20/11/1447 but state that work begins 15 ذو القعدة 1447 = 03/05/2026; the
# later decisions run from the day they were issued.
STARTS = {
    'makkah_sectors_towers': '2026-05-03',
    'makkah_tawafa_transport': '2026-05-03',
    'makkah_central_catering': '2026-05-03',
    'makkah_construction': '2026-05-03',
    'jeddah_airport_reception': '2026-05-03',
    'mission_offices_affairs': '2026-05-03',
    'central_aviation': '2026-05-03',
    'financial_administration': '2026-05-03',
    'oversight_complaints': '2026-05-03',
    'follow_up_evaluation': '2026-05-03',
    'mashaaer_teams': '2026-05-23',
    'arafat_camp_assignment': '2026-05-24',
    'mina_camp_assignment': '2026-05-25',
    'madinah_admin_office': '2026-05-29',
    'five_star_services_review': '2026-06-10',
}


class Ctx:
    def __init__(self):
        self.season = next(s for s in sbx.select('seasons')
                           if s['hijri_year'] == SEASON_YEAR)
        self.types = {t['code']: t for t in sbx.select('module_types')}
        self.levels = {}
        for l in sbx.select('module_type_levels'):
            self.levels.setdefault(l['module_type_id'], {})[l['code']] = l
        self.roles = {}
        for r in sbx.select('module_type_roles'):
            self.roles.setdefault(r['module_type_id'], {})[r['code']] = r
        self.sets = {s['code']: s for s in sbx.select('reference_sets')}

        plan = json.load(open(os.path.join(HERE, 'roster.json'), encoding='utf-8'))
        self.by_key = {tuple(p['key']): p['existing_id'] for p in plan}
        self.name_of = {tuple(p['key']): p['name'] for p in plan}
        self.missing = set()

    def level(self, code, lvl):
        return self.levels[self.types[code]['id']][lvl]['id']

    def role(self, code, r):
        return self.roles[self.types[code]['id']][r]['id']

    def pid(self, name):
        """The profile of the man this decision names, however it spells him.

        Keyed exactly as the roster was built, aliases included — otherwise a
        surname the decisions spell two ways ('دلل' / 'دلة') looks like a man
        with no account.
        """
        if not name:
            return None
        k = roster.person_key(name)
        if k is None:
            return None
        got = self.by_key.get(k)
        if got is None:
            self.missing.add((name, k))
        return got


def reset_reference_items(ctx):
    """The season's hotels and clusters, entered from 3142."""
    sid = ctx.season['id']
    junk = sbx.select('reference_items', f'select=id,name_ar,set_id&season_id=eq.{sid}')
    if junk:
        print(f'  clearing {len(junk)} leftover reference items in {SEASON_YEAR}')
        sbx.delete('reference_items', f'season_id=eq.{sid}')

    sectors = ex.makkah_sectors_towers()
    hotels, clusters = [], []
    for s in sectors:
        for t in s['towers']:
            hotels.append(t['hotel'])
            clusters.extend(t['clusters'])
    hotels = list(dict.fromkeys(hotels))
    clusters = list(dict.fromkeys(clusters))

    makkah = next((i for i in sbx.select('reference_items', 'select=id,name_ar,set_id')
                   if i['set_id'] == ctx.sets['saudi_cities']['id']
                   and 'مكة' in i['name_ar']), None)
    city = {'city': makkah['id']} if makkah else {}

    made = sbx.insert('reference_items', [
        {'set_id': ctx.sets['hotels']['id'], 'season_id': sid, 'name_ar': h,
         'sort_order': i, 'data': city}
        for i, h in enumerate(hotels, 1)])
    made += sbx.insert('reference_items', [
        {'set_id': ctx.sets['clusters']['id'], 'season_id': sid, 'name_ar': c,
         'sort_order': i, 'data': city}
        for i, c in enumerate(clusters, 1)])
    print(f'  + {len(hotels)} hotels, {len(clusters)} clusters')
    return ({h['name_ar']: h['id'] for h in made
             if h['set_id'] == ctx.sets['hotels']['id']},
            {c['name_ar']: c['id'] for c in made
             if c['set_id'] == ctx.sets['clusters']['id']})


def make_module(ctx, code):
    t = ctx.types[code]
    got = sbx.select('modules',
                     f"select=id&module_type_id=eq.{t['id']}&season_id=eq.{ctx.season['id']}")
    if got:
        sbx.delete('modules', f"id=eq.{got[0]['id']}")
    m = sbx.insert('modules', [{
        'module_type_id': t['id'], 'season_id': ctx.season['id'],
        'starts_on': STARTS[code], 'is_active': True, 'data': {},
    }])[0]
    return m['id']


def node(module_id, level_id, parent_id=None, ref=None, label=None,
         data=None, order=0):
    return {'module_id': module_id, 'level_id': level_id, 'parent_id': parent_id,
            'reference_item_id': ref, 'label': label, 'data': data or {},
            'sort_order': order}


def members_of(node_id, role_id, pids):
    return [{'node_id': node_id, 'role_id': role_id, 'profile_id': p}
            for p in dict.fromkeys([x for x in pids if x])]


# ------------------------------------------------------------------ the files

def build_towers(ctx, hotels, clusters):
    code = 'makkah_sectors_towers'
    mid = make_module(ctx, code)
    L = lambda c: ctx.level(code, c)
    R = lambda r: ctx.role(code, r)
    nodes, nm = [], []
    for si, s in enumerate(ex.makkah_sectors_towers(), 1):
        sec = sbx.insert('module_nodes', [node(
            mid, L('sector'), label=f'القطاع {ORDINALS[si]}', order=si)])[0]
        nm += members_of(sec['id'], R('sector_supervisor'), [ctx.pid(s['supervisor'])])
        nm += members_of(sec['id'], R('sector_deputy'), [ctx.pid(s['deputy'])])
        for t in s['towers']:
            tw = sbx.insert('module_nodes', [node(
                mid, L('tower'), parent_id=sec['id'],
                ref=hotels[t['hotel']], order=t['no'])])[0]
            nm += members_of(tw['id'], R('tower_supervisor'), [ctx.pid(t['supervisor'])])
            nm += members_of(tw['id'], R('tower_deputy'),
                             [ctx.pid(d) for d in t['deputies']])
            for ci, c in enumerate(t['clusters'], 1):
                sbx.insert('module_nodes', [node(
                    mid, L('cluster'), parent_id=tw['id'],
                    ref=clusters[c], order=ci)])
    sbx.insert('module_node_members', nm)
    return mid, nm


def build_roster_file(ctx, code, head_role, head, member_role, members):
    mid = make_module(ctx, code)
    rows = []
    if head:
        rows += [{'module_id': mid, 'role_id': ctx.role(code, head_role),
                  'profile_id': ctx.pid(head)}]
    seen = set()
    for m in members:
        p = ctx.pid(m)
        if p and p not in seen:
            seen.add(p)
            rows.append({'module_id': mid, 'role_id': ctx.role(code, member_role),
                         'profile_id': p})
    rows = [r for r in rows if r['profile_id']]
    sbx.insert('module_members', rows)
    return mid, rows


def build_labelled_file(ctx, code, mapping):
    """3145/3146/3148 — each row of the decision names a post and its holder."""
    mid = make_module(ctx, code)
    rows = []
    for label, who in mapping:
        role = None
        for needle, rcode in POSTS[code]:
            if needle in label:
                role = rcode
                break
        p = ctx.pid(who) if who else None
        if role and p:
            rows.append({'module_id': mid, 'role_id': ctx.role(code, role),
                         'profile_id': p})
    sbx.insert('module_members', rows)
    return mid, rows


POSTS = {
    'makkah_central_catering': [('سلامة غذائية', 'food_safety_officer'),
                                ('مختص', 'catering_specialist'),
                                ('معاون', 'deputy'), ('مشرف', 'supervisor')],
    'makkah_construction': [('المواقع', 'sites_officer'), ('عضو', 'member'),
                            ('مشرف', 'supervisor')],
    'mission_offices_affairs': [('عضو', 'member'), ('مشرف', 'supervisor')],
}


def build_mashaaer(ctx):
    code = 'mashaaer_teams'
    mid = make_module(ctx, code)
    L = lambda c: ctx.level(code, c)
    R = lambda r: ctx.role(code, r)
    secs, co, mon = ex.mashaaer_teams()
    nm, fm = [], []
    for si, s in enumerate(secs, 1):
        sec = sbx.insert('module_nodes', [node(
            mid, L('sector'), label=s['label'] or f'القطاع {ORDINALS[si]}',
            order=si)])[0]
        nm += members_of(sec['id'], R('sector_supervisor'), [ctx.pid(s['supervisor'])])
        nm += members_of(sec['id'], R('sector_deputy'), [ctx.pid(s['deputy'])])
        nm += members_of(sec['id'], R('tarwiyah_member'),
                         [ctx.pid(x) for x in s['tarwiyah']])
        nm += members_of(sec['id'], R('arafat_member'),
                         [ctx.pid(x) for x in s['arafat']])
        nm += members_of(sec['id'], R('tashreeq_member'),
                         [ctx.pid(x) for x in s['mina']])
    for rcode, who in [('coasters_manager', [co['manager']]),
                       ('coasters_deputy', [co['deputy']]),
                       ('coasters_member', co['members']),
                       ('catering_monitor', mon)]:
        for p in dict.fromkeys([ctx.pid(x) for x in who if x]):
            if p:
                fm.append({'module_id': mid, 'role_id': R(rcode), 'profile_id': p})
    sbx.insert('module_node_members', nm)
    sbx.insert('module_members', fm)
    return mid, nm + fm


def build_arafat(ctx):
    code = 'arafat_camp_assignment'
    mid = make_module(ctx, code)
    L = lambda c: ctx.level(code, c)
    R = lambda r: ctx.role(code, r)
    nm = []
    for i, c in enumerate(ex.arafat_centers(), 1):
        cen = sbx.insert('module_nodes', [node(
            mid, L('center'), label=f"المركز رقم {c['no']}", order=int(c['no']))])[0]
        nm += members_of(cen['id'], R('center_supervisor'), [ctx.pid(c['supervisor'])])
        for j, cm in enumerate(c['camps'], 1):
            data = {}
            if cm['tents']:
                data['tents'] = cm['tents']
            if cm['bodies']:
                data['bodies'] = '\n'.join(cm['bodies'])
            camp = sbx.insert('module_nodes', [node(
                mid, L('camp'), parent_id=cen['id'],
                label=f"المخيم رقم {cm['no']}"
                      + (f" — خيمة {cm['tents']}" if len(c['camps']) > 1 else ''),
                data=data, order=j)])[0]
            nm += members_of(camp['id'], R('camp_member'),
                             [ctx.pid(x) for x in cm['members']])
    sbx.insert('module_node_members', nm)
    return mid, nm


def build_mina(ctx):
    """مخيمات منى (3173) — the names recovered by mina.py, not read off the page.

    Its centers carry the tent numbers the decision gives, its فريق الكوسترات
    sits on the file, and the bodies allotted space stay on their camp.
    """
    import mina
    code = 'mina_camp_assignment'
    centers, flat, where, got, cipher, _ = mina.solve()
    resolved, low = {}, 0
    for i, (name, s) in got.items():
        resolved[i] = name
        if s < mina.CONFIDENT:
            low += 1

    mid = make_module(ctx, code)
    L = lambda c: ctx.level(code, c)
    R = lambda r: ctx.role(code, r)
    nm, fm, k = [], [], 0
    for ci, c in enumerate(centers, 1):
        cen = sbx.insert('module_nodes', [node(
            mid, L('center'), label=f"المركز رقم {c['no']}", order=ci)])[0]
        nm += members_of(cen['id'], R('center_supervisor'),
                         [ctx.pid(s) for s in c['supervisors']])
        for j, cm in enumerate(c['camps'], 1):
            data = {}
            if cm['tents']:
                data['tents'] = cm['tents']
            if cm['bodies']:
                data['bodies'] = '\n'.join(cm['bodies'])
            camp = sbx.insert('module_nodes', [node(
                mid, L('camp'), parent_id=cen['id'],
                label=f"المخيم رقم {cm['no']}"
                      + (f" — خيمة {cm['tents']}" if len(c['camps']) > 1 else ''),
                data=data, order=j)])[0]
            pids = []
            for _ in cm['members']:
                pids.append(ctx.pid(resolved.get(k)) if k in resolved else None)
                k += 1
            nm += members_of(camp['id'], R('camp_member'), pids)
        if c.get('coasters'):
            sup = ctx.pid(c['coasters']['supervisor'])
            if sup:
                fm.append({'module_id': mid, 'role_id': R('coasters_supervisor'),
                           'profile_id': sup})
            for _ in c['coasters']['members']:
                p = ctx.pid(resolved.get(k)) if k in resolved else None
                k += 1
                if p:
                    fm.append({'module_id': mid, 'role_id': R('coasters_member'),
                               'profile_id': p})
    sbx.insert('module_node_members', nm)
    sbx.insert('module_members', _dedupe(fm))
    return mid, nm + fm, low


def build_madinah(ctx):
    code = 'madinah_admin_office'
    mid = make_module(ctx, code)
    R = lambda r: ctx.role(code, r)
    m = ex.madinah_office()
    nm, fm = [], []
    for i, comp in enumerate(m['companies'], 1):
        cn = sbx.insert('module_nodes', [node(
            mid, ctx.level(code, 'service_company'), label=comp['name'], order=i)])[0]
        nm += members_of(cn['id'], R('guide'), [ctx.pid(g) for g in comp['guides']])
    for role, who in m['coordinators']:
        p = ctx.pid(who)
        if p:
            fm.append({'module_id': mid,
                       'role_id': R('office_coordinator' if role == 'office'
                                    else 'travel_coordinator'),
                       'profile_id': p})
    # 3190 forms one more team of this office, and names its محاسب.
    dep_head, dep_members, accountant = ex.madinah_departures()
    if dep_head:
        p = ctx.pid(dep_head)
        if p:
            fm.append({'module_id': mid, 'role_id': R('departures_supervisor'),
                       'profile_id': p})
    for who in dep_members:
        p = ctx.pid(who)
        if p:
            fm.append({'module_id': mid, 'role_id': R('departures_member'),
                       'profile_id': p})
    if accountant:
        p = ctx.pid(accountant)
        if p:
            fm.append({'module_id': mid, 'role_id': R('accountant'),
                       'profile_id': p})

    TEAM = {'housing': ('housing_supervisor', 'housing_member'),
            'airport': ('airport_supervisor', 'airport_member'),
            'aviation': ('aviation_supervisor', 'aviation_member'),
            'baggage': (None, 'baggage_member')}
    for team, v in m['teams'].items():
        sup_role, mem_role = TEAM[team]
        if v['head'] and sup_role:
            p = ctx.pid(v['head'])
            if p:
                fm.append({'module_id': mid, 'role_id': R(sup_role), 'profile_id': p})
        for who in v['members']:
            p = ctx.pid(who)
            if p:
                fm.append({'module_id': mid, 'role_id': R(mem_role), 'profile_id': p})
    sbx.insert('module_node_members', nm)
    sbx.insert('module_members', _dedupe(fm))
    return mid, nm + fm


def _dedupe(rows):
    seen, out = set(), []
    for r in rows:
        k = (r['module_id'], r['role_id'], r['profile_id'])
        if k not in seen:
            seen.add(k)
            out.append(r)
    return out


def main():
    ctx = Ctx()
    print(f'season {SEASON_YEAR}: {ctx.season["id"]}')
    # A hotel standing as a tower cannot be deleted from the season's list, so
    # the files go first and the lists are rebuilt behind them.
    old = sbx.select('modules', f"select=id&season_id=eq.{ctx.season['id']}")
    if old:
        print(f'  removing {len(old)} existing files in the season')
        sbx.delete('modules', f"season_id=eq.{ctx.season['id']}")
    hotels, clusters = reset_reference_items(ctx)

    total = 0
    mid, rows = build_towers(ctx, hotels, clusters)
    print(f'  قطاعات وأبراج: {len(rows)} assignments'); total += len(rows)

    for code, (hr, mr), fn in [
        ('makkah_tawafa_transport', ('supervisor', 'member'), ex.tawafa_transport),
        ('jeddah_airport_reception', ('supervisor', 'member'), ex.airport_reception),
        ('central_aviation', ('supervisor', 'member'), ex.central_aviation),
        ('financial_administration', ('supervisor', 'member'), ex.financial_administration),
        ('oversight_complaints', ('coordinator', 'member'), ex.oversight_complaints),
        ('follow_up_evaluation', ('supervisor', 'member'), ex.follow_up_evaluation),
    ]:
        head, members = fn()
        _, rows = build_roster_file(ctx, code, hr, head, mr, members)
        print(f'  {ctx.types[code]["name_ar"][:34]}: {len(rows)}'); total += len(rows)

    for code, fn in [('makkah_central_catering', ex.central_catering),
                     ('makkah_construction', ex.construction),
                     ('mission_offices_affairs', ex.mission_offices)]:
        _, rows = build_labelled_file(ctx, code, fn())
        print(f'  {ctx.types[code]["name_ar"][:34]}: {len(rows)}'); total += len(rows)

    _, rows = build_mashaaer(ctx)
    print(f'  فرق المشاعر: {len(rows)}'); total += len(rows)
    _, rows = build_arafat(ctx)
    print(f'  مخيمات عرفات: {len(rows)}'); total += len(rows)
    _, rows, low = build_mina(ctx)
    print(f'  مخيمات منى: {len(rows)}'
          + (f'  ({low} low-confidence name matches)' if low else
             '  (every name matched confidently)')); total += len(rows)
    _, rows = build_madinah(ctx)
    print(f'  المكتب الإداري بالمدينة: {len(rows)}'); total += len(rows)

    chair, members = ex.five_star_panel()
    _, rows = build_roster_file(ctx, 'five_star_services_review',
                                'chair', chair, 'member', members)
    print(f'  لجنة 5 نجوم: {len(rows)}'); total += len(rows)

    print(f'\ntotal assignments: {total}')
    if ctx.missing:
        print(f'\nUNMATCHED NAMES ({len(ctx.missing)}):')
        for n, k in sorted(ctx.missing):
            print('   ', n, k)

    # Everyone named in the season's files takes part in the season.
    pids = {r['profile_id'] for r in sbx.select('module_node_members', 'select=profile_id')}
    pids |= {r['profile_id'] for r in sbx.select('module_members', 'select=profile_id')}
    sbx.delete('season_participants', f'season_id=eq.{ctx.season["id"]}')
    sbx.insert('season_participants',
               [{'season_id': ctx.season['id'], 'profile_id': p, 'status': 'active'}
                for p in pids])
    print(f'season participants: {len(pids)}')


if __name__ == '__main__':
    main()
