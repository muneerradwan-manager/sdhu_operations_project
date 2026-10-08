# -*- coding: utf-8 -*-
"""Read the official decisions as tables, with merges resolved.

Word stores a vertically merged cell once, in its first row, and a horizontally
merged one as a single cell with a gridSpan. Both matter here: the sector of a
tower is a vertically merged cell covering its six towers, and a sector with no
معاون is a single cell spanning the two sector columns. So a table is expanded
into a full grid, and each cell keeps the span it was written with — the span is
what distinguishes "no معاون" from "the معاون is the same man".
"""
import zipfile, glob, os
import xml.etree.ElementTree as ET

W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
DOCS = 'assets/docs'


class Cell:
    __slots__ = ('text', 'span', 'origin', 'lines', 'vfill')

    def __init__(self, text, span, origin, lines=(), vfill=False):
        self.text = text
        self.span = span          # grid columns this cell was written across
        self.origin = origin      # True on the cell itself, False on a fill-in
        self.lines = list(lines)  # its paragraphs: two deputies are two lines
        self.vfill = vfill        # text carried down from a vertical merge

    def __repr__(self):
        return f'Cell({self.text!r},span={self.span},o={self.origin})'


def _ptext(p):
    return ''.join(t.text or '' for t in p.iter(f'{W}t')).strip()


def _cell_lines(tc):
    """A cell's paragraphs, kept apart: two deputies are two paragraphs."""
    return [x for x in (_ptext(p) for p in tc.findall(f'{W}p')) if x]


def _tables(path):
    z = zipfile.ZipFile(path)
    root = ET.fromstring(z.read('word/document.xml'))
    return list(root.find(f'{W}body').iter(f'{W}tbl'))


def grid(tbl):
    """Expand one table to a rectangular grid of Cell, merges resolved."""
    rows = []
    for tr in tbl.findall(f'{W}tr'):
        row = []
        for tc in tr.findall(f'{W}tc'):
            pr = tc.find(f'{W}tcPr')
            span, vm = 1, None
            if pr is not None:
                gs = pr.find(f'{W}gridSpan')
                if gs is not None:
                    span = int(gs.get(f'{W}val'))
                v = pr.find(f'{W}vMerge')
                if v is not None:
                    vm = v.get(f'{W}val') or 'continue'
            lines = _cell_lines(tc)
            text = '\n'.join(lines)
            row.append([text, span, vm, lines])
        rows.append(row)

    width = max((sum(s for _, s, _, _ in r) for r in rows), default=0)
    out = []
    for r in rows:
        g, col = [], 0
        for text, span, vm, lines in r:
            vfill = False
            if vm == 'continue' and out:
                above = out[-1][col] if col < len(out[-1]) else None
                text = above.text if above else ''
                lines = list(above.lines) if above else []
                vfill = True
            first = True
            for _ in range(span):
                g.append(Cell(text, span, first, lines, vfill))
                first = False
            col += span
        while len(g) < width:
            g.append(Cell('', 1, True))
        out.append(g)
    return out


def doc(name_fragment):
    """The one document whose filename contains this fragment."""
    hits = [p for p in glob.glob(os.path.join(DOCS, '*.docx'))
            if name_fragment in os.path.basename(p)]
    if len(hits) != 1:
        raise SystemExit(f'{name_fragment}: matched {len(hits)} files')
    return hits[0]


def tables_of(name_fragment):
    return [grid(t) for t in _tables(doc(name_fragment))]


def body(name_fragment):
    """Paragraphs and tables in document order: ('p', text) / ('t', grid)."""
    z = zipfile.ZipFile(doc(name_fragment))
    root = ET.fromstring(z.read('word/document.xml'))
    seq = []
    for el in root.find(f'{W}body'):
        if el.tag == f'{W}p':
            t = _ptext(el)
            if t:
                seq.append(('p', t))
        elif el.tag == f'{W}tbl':
            seq.append(('t', grid(el)))
    return seq
