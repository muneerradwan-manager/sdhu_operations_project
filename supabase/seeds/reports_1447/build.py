# -*- coding: utf-8 -*-
"""Publish the three meal reports for a season, from the documents themselves.

    export SUPABASE_SERVICE_KEY=sb_secret_...
    python supabase/seeds/reports_1447/build.py            # show only
    python supabase/seeds/reports_1447/build.py --apply

Rebuilds from scratch each run: a report of a kind is replaced rather than added
to, so this is safe to repeat and a corrected .docx is a re-run.

All three are SEASONAL. مكونات الوجبات is what a company contracted to serve
this year — next year's is a different document, and publishing it as general
would state that this year's menu is true in every year. A report that outlives
one season is entered with no season at all, which is the default the form takes.
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'decisions_1447'))

import sbx                       # noqa: E402
import meals                     # noqa: E402

APPLY = '--apply' in sys.argv
SEASON_YEAR = 1447


def main():
    season = next(
        s for s in sbx.select('seasons') if s['hijri_year'] == SEASON_YEAR
    )
    types = {t['code']: t for t in sbx.select('report_types')}
    columns = sbx.select('report_type_columns')
    sets = {s['code']: s for s in sbx.select('reference_sets')}

    # The clusters of THIS season, by name — the distribution's columns are the
    # clusters, and a cluster is contracted per year.
    cluster_items = {
        i['name_ar']: i['id']
        for i in sbx.select('reference_items')
        if i['set_id'] == sets['clusters']['id']
        and i.get('season_id') == season['id']
    }

    cluster_names, dist = meals.distribution()
    timing = meals.timing()
    components = meals.components()

    missing = [n for n in cluster_names if n not in cluster_items]
    if missing:
        # Said out loud rather than silently dropping a column of numbers.
        print('WARNING — clusters in the document with no entry this season:')
        for n in missing:
            print('   ', n)

    plan = [
        (
            'mashaaer_meal_distribution',
            'توزيع الوجبات على التكتلات — المشاعر',
            [
                {
                    'day': r['day'], 'meal': r['meal'],
                    'ratio': r['ratio'], 'total': r['total'],
                    # Cells of an expanded column are keyed by the entry's id.
                    **{
                        cluster_items[name]: r['clusters'][name]
                        for name in cluster_names
                        if name in cluster_items
                    },
                }
                for r in dist
            ],
        ),
        (
            'mashaaer_meal_timing',
            'مواعيد تقديم الوجبات — المشاعر',
            [
                {'day': r['day'], 'meal': r['meal'],
                 'nature': r['nature'], 'window': r['window']}
                for r in timing
            ],
        ),
        (
            'mashaaer_meal_components',
            'مكونات الوجبات — المشاعر',
            [
                {'day': r['day'], 'meal': r['meal'], 'nature': r['nature'],
                 'window': r['window'],
                 # One item per line: the table shows them as written, and a
                 # comma-joined string would read as one long ingredient.
                 'components': '\n'.join(r['components'])}
                for r in components
            ],
        ),
    ]

    print(f'season {SEASON_YEAR}: {season["id"]}')
    for code, title, rows in plan:
        t = types.get(code)
        cols = [c['key'] for c in columns if c['report_type_id'] == t['id']]
        print(f'  {title}')
        print(f'      {len(rows)} rows, columns declared: {", ".join(cols)}')

    if not APPLY:
        print('\nDRY RUN — nothing written. Re-run with --apply.')
        return

    for code, title, rows in plan:
        t = types[code]
        old = sbx.select(
            'reports',
            f"select=id&report_type_id=eq.{t['id']}&season_id=eq.{season['id']}",
        )
        for o in old:
            sbx.delete('reports', f"id=eq.{o['id']}")

        report = sbx.insert('reports', [{
            'report_type_id': t['id'],
            'season_id': season['id'],
            'title': title,
            'data': {},
            'is_published': True,
        }])[0]
        sbx.insert('report_rows', [
            {'report_id': report['id'], 'data': row, 'sort_order': i}
            for i, row in enumerate(rows, 1)
        ])
        print(f'  published {title} ({len(rows)} rows)')

    print('reports now:', len(sbx.select('reports', 'select=id')))


if __name__ == '__main__':
    main()
