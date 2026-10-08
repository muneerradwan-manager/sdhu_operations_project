# -*- coding: utf-8 -*-
"""Read the three meal documents into report rows.

assets/docs/meals holds three published tables — توزيع الوجبات على التكتلات,
مواعيد تقديم الوجبات, and مكونات الوجبات. All three are keyed by (التاريخ,
الوجبة) and all three write the date once and read it down the page, so the
first job of every reader here is to carry that date down.

Nothing is transcribed. The .docx files are the source, so a corrected document
is a file swap and a re-run — the same rule the 1447 decisions seed follows.
"""
import os, re, sys, glob

# The decision seed already knows how to read a Word table with its merges
# resolved; a report table is the same problem.
sys.path.insert(
    0,
    os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'decisions_1447'),
)
import docparse as dp  # noqa: E402

MEALS = os.path.join('assets', 'docs', 'meals')


def _doc(fragment):
    hits = [p for p in glob.glob(os.path.join(MEALS, '*.docx'))
            if fragment in os.path.basename(p)]
    if len(hits) != 1:
        raise SystemExit(f'{fragment}: matched {len(hits)} files')
    return hits[0]


def _tables(fragment):
    import xml.etree.ElementTree as ET
    root = ET.fromstring(
        dp.zipfile.ZipFile(_doc(fragment)).read('word/document.xml')
    )
    return [dp.grid(t) for t in root.find(f'{dp.W}tbl'.rsplit('}', 1)[0] + '}body')
            if t.tag == f'{dp.W}tbl']


def _clean(s):
    return re.sub(r'\s+', ' ', (s or '').replace('‏', '')).strip()


def _carry(rows, key):
    """Fill a column that was written once and meant for every row beneath it."""
    last = ''
    for r in rows:
        v = _clean(r.get(key, ''))
        if v:
            last = v
        else:
            r[key] = last
    return rows


# ------------------------------------------------------------- 1. التوزيع

def distribution():
    """Rows of (day, meal, ratio, total) plus a count per تكتل.

    Cluster counts come back keyed by the cluster's NAME; the builder resolves
    each to the reference item of the season it is seeding, because the columns
    of this table are the clusters and those are contracted per year.
    """
    grid = _tables('توزيع')[0]
    header = [_clean(c.text) for c in grid[0]]
    # Everything between المجموع and الوجبة is a cluster.
    first = header.index('المجموع') + 1
    last = header.index('الوجبة')
    clusters = header[first:last]

    out = []
    for row in grid[1:]:
        cells = [_clean(c.text) for c in row]
        if not any(cells):
            continue
        out.append({
            'day': cells[header.index('التاريخ')],
            'meal': cells[header.index('الوجبة')],
            'ratio': cells[header.index('النسبة')],
            'total': cells[header.index('المجموع')],
            'clusters': {
                name: cells[first + i] for i, name in enumerate(clusters)
            },
        })
    return clusters, _carry(out, 'day')


# --------------------------------------------------------------- 2. التوقيت

def timing():
    grid = _tables('توقيت')[0]
    header = [_clean(c.text) for c in grid[0]]
    idx = {name: header.index(name) for name in
           ('التاريخ', 'الوجبة', 'نوعها', 'توقيتها')}
    out = []
    for row in grid[1:]:
        cells = [_clean(c.text) for c in row]
        if not any(cells):
            continue
        out.append({
            'day': cells[idx['التاريخ']],
            'meal': cells[idx['الوجبة']],
            'nature': cells[idx['نوعها']],
            'window': cells[idx['توقيتها']],
        })
    return _carry(out, 'day')


# ------------------------------------------------------------- 3. المكونات

_HEAD = re.compile(r'^وجبة\s+(\S+)\s*[-–]\s*(\S+)')


def components():
    """One row per meal: its day, kind, service window, and what is in it.

    The document is a run of blocks rather than a table with a header — each
    block opens with 'وجبة غداء - جافة', then a التوقيت line, then one or two
    rows of items. The items are kept as lines rather than split into columns:
    the shortest meal has four and the longest ten.
    """
    out = []
    for grid in _tables('مكونات'):
        current = None
        for row in grid:
            cells = [_clean(c.text) for c in row if c.origin]
            joined = ' '.join(cells)
            if not joined:
                continue

            head = _HEAD.match(cells[0]) if cells else None
            if head:
                current = {'meal': head.group(1), 'nature': head.group(2),
                           'day': '', 'window': '', 'components': []}
                out.append(current)
                continue
            if current is None:
                continue

            if 'التوقيت' in cells:
                at = cells.index('التوقيت')
                # The date sits after the label, the window before it.
                current['window'] = cells[at - 1] if at else ''
                current['day'] = cells[at + 1] if at + 1 < len(cells) else ''
                continue
            if 'المكونات' in cells:
                at = cells.index('المكونات')
                # Written right-to-left across the row, so each ROW is reversed
                # as it is read — not the whole list at the end, which would put
                # the second row's items before the first row's.
                current['components'] += [
                    c for c in reversed(cells[:at]) if c
                ]
                continue
    for r in out:
        r['components'] = list(dict.fromkeys(r['components']))
    return out


if __name__ == '__main__':
    clusters, dist = distribution()
    print(f'توزيع الوجبات — {len(dist)} rows, {len(clusters)} cluster columns')
    print('   clusters:', ', '.join(clusters))
    for r in dist[:3]:
        print(f"   {r['day']:<26} {r['meal']:<6} {r['ratio']:<5} "
              f"total={r['total']:<6} عطاء={r['clusters'].get('عطاء')}")
    print()
    t = timing()
    print(f'مواعيد التقديم — {len(t)} rows')
    for r in t[:3]:
        print(f"   {r['day']:<26} {r['meal']:<6} {r['nature']:<6} {r['window']}")
    print()
    c = components()
    print(f'المكونات — {len(c)} meals')
    for r in c[:3]:
        print(f"   {r['day']:<26} {r['meal']:<6} {r['nature']:<6} {r['window']}")
        print(f"      {' | '.join(r['components'])}")
