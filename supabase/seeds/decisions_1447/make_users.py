# -*- coding: utf-8 -*-
"""Create an account for every person named in the decisions.

The admin already has one and appears in the decisions himself (منير رضوان
serves in القطاع الثالث and المركز 14), so he is matched to his roster entry
rather than duplicated.

Writes roster.json — the name→profile map every later stage reads.
"""
import sys, os, json, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sbx, roster
from names import split_name, normalise

APPLY = '--apply' in sys.argv
DOMAIN = 'syrianhajj.org'          # the mission's own domain, from 3197
PASSWORD = 'Hajj@1447'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'roster.json')

# Enough to build a readable, unique address; ambiguity is settled by a suffix.
_TR = {
    'ا': 'a', 'أ': 'a', 'إ': 'i', 'آ': 'a', 'ب': 'b', 'ت': 't', 'ث': 'th',
    'ج': 'j', 'ح': 'h', 'خ': 'kh', 'د': 'd', 'ذ': 'dh', 'ر': 'r', 'ز': 'z',
    'س': 's', 'ش': 'sh', 'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z', 'ع': 'a',
    'غ': 'gh', 'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n',
    'ه': 'h', 'ة': 'a', 'و': 'w', 'ي': 'y', 'ى': 'a', 'ئ': 'y', 'ؤ': 'w',
    'ء': '', 'ّ': '',
}


def latin(s):
    out = ''.join(_TR.get(c, '' if c.isspace() else '') for c in s)
    return re.sub(r'[^a-z]', '', out.lower()) or 'x'


# A post that puts a man over others earns the 'مشرف' title; the rest are
# administrative officers. The decisions name no other職 for these people.
_LEAD = ('مشرف', 'رأس', 'رئيس', 'منسق', 'مدير', 'مسؤول')


def job_for(sources):
    return 'مشرف' if any(any(k in s for k in _LEAD) for s in sources) else 'موظف إداري'


def main():
    r = roster.build()
    people = r.all()
    # Both lists live in the reference catalog since 0085.
    def set_items(code):
        rows = sbx.select(
            'reference_items',
            'select=id,name_ar,reference_sets!inner(code)'
            f'&reference_sets.code=eq.{code}',
        )
        return {r['name_ar']: r['id'] for r in rows}

    titles = set_items('job_titles')
    missions = set_items('mission_types')

    existing = sbx.select('profiles', 'select=id,first_name,father_name,surname,is_admin')
    by_key = {}
    for p in existing:
        full = ' '.join(x for x in [p.get('first_name'), p.get('father_name'),
                                    p.get('surname')] if x)
        k = roster.person_key(full)
        if k:
            by_key[k] = p

    used, plan = set(), []
    for rec in people:
        first, father, surname = split_name(rec['name'])
        base = f'{latin(first)}.{latin(surname)}'
        email, n = f'{base}@{DOMAIN}', 1
        while email in used:
            n += 1
            email = f'{base}{n}@{DOMAIN}'
        used.add(email)
        plan.append({
            'key': list(rec['key']),
            'name': rec['name'],
            'first_name': first, 'father_name': father, 'surname': surname,
            'email': email,
            'job_title': job_for(rec['sources']),
            'sources': sorted(rec['sources']),
            'existing_id': (by_key.get(rec['key']) or {}).get('id'),
        })

    matched = [p for p in plan if p['existing_id']]
    fresh = [p for p in plan if not p['existing_id']]
    print(f'roster: {len(plan)} people')
    print(f'  already have an account: {len(matched)}')
    for p in matched:
        print(f"      {p['name']}  -> {p['existing_id'][:8]}")
    print(f'  to create: {len(fresh)}')
    print(f'  supervisors: {sum(1 for p in plan if p["job_title"] == "مشرف")}')

    if not APPLY:
        print('\nDRY RUN — nothing created. Re-run with --apply.')
        print('sample:', json.dumps(fresh[:3], ensure_ascii=False, indent=2))
        return

    for i, p in enumerate(fresh, 1):
        try:
            u = sbx.create_auth_user(p['email'], PASSWORD)
            p['existing_id'] = u['id']
        except Exception as e:
            print(f"  FAILED {p['email']}: {e}")
            continue
        if i % 25 == 0:
            print(f'   created {i}/{len(fresh)}')
    print(f'   created {len(fresh)}/{len(fresh)}')

    # Fill the profiles the signup trigger made.
    print('filling profiles...')
    for p in plan:
        if not p['existing_id']:
            continue
        patch = {
            'first_name': p['first_name'],
            'father_name': p['father_name'],
            'surname': p['surname'],
            'gender': 'male',
            'mission_type_id': missions.get('البعثة الإدارية'),
            'job_title_id': titles.get(p['job_title']),
            'account_status': 'approved',
        }
        sbx.update('profiles', f"id=eq.{p['existing_id']}", patch)

    json.dump(plan, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('wrote', OUT)
    print('profiles now:', len(sbx.select('profiles', 'select=id')))


if __name__ == '__main__':
    main()
