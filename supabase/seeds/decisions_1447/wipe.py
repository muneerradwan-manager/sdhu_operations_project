# -*- coding: utf-8 -*-
"""Clear the seasons' operational content and every account but the admin.

Runs as a dry run unless --apply is passed: this is irreversible against the
live project, so what it is about to remove is printed and counted first.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sbx

APPLY = '--apply' in sys.argv
TARGET_YEAR = 1447


def main():
    seasons = {s['hijri_year']: s for s in sbx.select('seasons')}
    target = seasons[TARGET_YEAR]

    modules = sbx.select('modules', 'select=id,season_id,module_type_id,is_active')
    types = {t['id']: t['name_ar'] for t in sbx.select('module_types', 'select=id,name_ar')}
    year_of = {s['id']: y for y, s in seasons.items()}

    nodes = sbx.select('module_nodes', 'select=id,module_id')
    node_members = sbx.select('module_node_members', 'select=id,node_id')
    members = sbx.select('module_members', 'select=id,module_id')
    assigned = sbx.select('module_assigned_tasks', 'select=id')
    participants = sbx.select('season_participants', 'select=id,season_id,profile_id')

    profiles = sbx.select('profiles', 'select=id,first_name,surname,is_admin')
    admins = [p for p in profiles if p['is_admin']]
    doomed = [p for p in profiles if not p['is_admin']]

    print('=' * 64)
    print('MODULES to remove (every season):')
    for m in modules:
        print(f"   {year_of.get(m['season_id'])}  {types.get(m['module_type_id'])}")
    print(f'   -> {len(modules)} files, {len(nodes)} nodes, '
          f'{len(node_members)} node members, {len(members)} flat members, '
          f'{len(assigned)} assigned tasks')
    print()
    print(f'ACCOUNTS to remove: {len(doomed)}')
    for p in doomed:
        print(f"   {p['id'][:8]}  {p['first_name']} {p['surname']}")
    print(f'ACCOUNTS to keep:   {len(admins)}')
    for p in admins:
        print(f"   {p['id'][:8]}  {p['first_name']} {p['surname']}  (admin)")
    print()
    print(f'SEASON: {TARGET_YEAR} becomes current '
          f"(was {[y for y, s in seasons.items() if s['is_current']]})")
    print('=' * 64)

    if not APPLY:
        print('\nDRY RUN — nothing changed. Re-run with --apply.')
        return

    # Children first: the schema cascades, but deleting explicitly keeps the
    # counts above honest and survives a partial run.
    print('\ndeleting assigned tasks...', len(assigned))
    sbx.delete('module_assigned_tasks', 'id=not.is.null')
    print('deleting node members...', len(node_members))
    sbx.delete('module_node_members', 'id=not.is.null')
    print('deleting nodes...', len(nodes))
    sbx.delete('module_nodes', 'id=not.is.null')
    print('deleting flat members...', len(members))
    sbx.delete('module_members', 'id=not.is.null')

    reports = sbx.select('module_reports', 'select=id')
    if reports:
        print('deleting module reports...', len(reports))
        sbx.delete('module_reports', 'id=not.is.null')

    print('deleting modules...', len(modules))
    sbx.delete('modules', 'id=not.is.null')

    print('deleting season participants...', len(participants))
    sbx.delete('season_participants', 'id=not.is.null')

    # Notifications reference profiles; clear them so the roster starts clean.
    notes = sbx.select('notifications', 'select=id')
    if notes:
        print('deleting notifications...', len(notes))
        sbx.delete('notifications', 'id=not.is.null')

    print('deleting accounts...', len(doomed))
    for p in doomed:
        sbx.delete_auth_user(p['id'])          # cascades to profiles

    left = sbx.select('profiles', 'select=id,is_admin')
    print('profiles remaining:', len(left))

    print('setting the current season...')
    sbx.update('seasons', 'is_current=eq.true', {'is_current': False})
    sbx.update('seasons', f'id=eq.{target["id"]}', {'is_current': True})
    now = [s for s in sbx.select('seasons') if s['is_current']]
    print('current season is now:', [s['hijri_year'] for s in now])
    print('\ndone.')


if __name__ == '__main__':
    main()
