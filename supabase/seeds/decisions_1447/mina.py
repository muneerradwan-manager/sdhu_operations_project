# -*- coding: utf-8 -*-
"""مخيمات منى (3173), whose member names the conversion destroyed.

The file was produced from a font whose medial letter forms carry no Unicode
mapping, so a name arrives with its middle eaten: 'قتيبه محمد صالح' is written
'قل به م د صLةح'. The damage is not invertible — several source letters land on
the same空 glyph — so the names cannot be READ. They can only be RECOGNISED,
and only because the pool they come from is closed: everyone in منى is someone
the other fourteen decisions already named.

So each garbled string is scored against the 161-man roster on what the damage
left behind — the number of words, their lengths, and the letters that did
survive, first and last of each word above all — and the whole document is then
matched one-to-one: a man serves in one منى camp, so no two garbled strings may
claim the same person. That constraint is what makes the weak per-name signal
reliable in aggregate.

Every match is scored and printed. Anything below CONFIDENT is reported for a
human to confirm rather than written silently.
"""
import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import docparse as dp
import roster
from names import clean, normalise, is_placeholder, is_body

CONFIDENT = 0.62


# ---------------------------------------------------------------- the document

def parse():
    """Centers, their camps and tents, supervisors, and the garbled rosters."""
    seq = dp.body('3173')
    centers, current, camp, pending = [], None, None, None
    coasters = None
    for kind, payload in seq:
        if kind == 'p':
            m = re.match(r'^-?\s*\d+\s*[-.]?\s*المركز\s+رقم\s+([\d\s/+]+)', clean(payload))
            if m:
                pending = m.group(1).strip()
            continue
        for row in payload:
            joined = ' '.join(clean(c.text) for c in row if c.origin)
            if 'مشرف' in joined and 'المراك' in joined or joined.startswith('مشرف المركز'):
                sup = clean(joined.split(':', 1)[1]) if ':' in joined else None
                current = {'no': pending, 'supervisors': [
                    s.strip() for s in re.split(r'\s*/\s*', sup or '') if s.strip()],
                    'camps': []}
                centers.append(current)
                pending, camp, coasters = None, None, None
                continue
            if 'الكوسترات' in joined:
                sup = joined.split(':', 1)[1] if ':' in joined else ''
                coasters = {'supervisor': clean(sup), 'members': []}
                camp = None
                current['coasters'] = coasters
                continue
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
                coasters = None
                continue
            bucket = coasters['members'] if coasters else (camp['members'] if camp else None)
            if bucket is None:
                continue
            seen = set()
            for c in row:
                if not c.origin or c.text in seen:
                    continue
                seen.add(c.text)
                t = clean(c.text)
                if is_placeholder(t):
                    continue
                if is_body(t) and camp is not None and not coasters:
                    camp['bodies'].append(t)
                else:
                    bucket.append(t)
    return centers


# ------------------------------------------------------------------ the match

_ARABIC = re.compile(r'[ء-ي]')


def shape(s):
    """What the damage left: words, each as (length, surviving letters)."""
    s = normalise(clean(s))
    return [(len(w), [c for c in w if _ARABIC.match(c)]) for w in s.split() if w]


def score(garbled, candidate):
    """How well a roster name explains this wreck of a string.

    The conversion drops letters and turns others into spaces, so a candidate
    is never longer than its garbled form by much and never shorter than the
    letters that survived. Word count and the letters that DID come through are
    the two things it could not fake.
    """
    g, c = shape(garbled), shape(candidate)
    if not g or not c:
        return 0.0
    # Word count: the damage splits words but rarely merges them across a space.
    wc = 1.0 - min(abs(len(g) - len(c)), 4) / 4.0

    gl = [ch for _, letters in g for ch in letters]
    cl = [ch for _, letters in c for ch in letters]
    if not gl:
        return 0.0
    # Every surviving letter should be somewhere in the candidate, in order.
    import difflib
    sm = difflib.SequenceMatcher(None, ''.join(gl), ''.join(cl))
    order = sm.ratio()
    kept = sum(1 for ch in set(gl) if ch in cl) / len(set(gl))

    # The first letter of a word survives far more often than the middle.
    heads_g = [w[1][0] for w in g if w[1]]
    heads_c = [w[1][0] for w in c if w[1]]
    heads = difflib.SequenceMatcher(None, ''.join(heads_g), ''.join(heads_c)).ratio()

    # A candidate much shorter than what survived cannot be right.
    span = min(len(cl) / max(len(gl), 1), 1.0) if len(cl) < len(gl) else 1.0

    return (0.34 * order + 0.28 * kept + 0.24 * heads + 0.14 * wc) * span


def learn_cipher(anchors):
    """What each surviving glyph turned out to stand for.

    Built from the matches the plain scorer was already sure of: aligning those
    garbled strings against the names they resolved to shows, for instance, that
    '~' is س, 'L' is ا and 'ة' is ل in this document. The mapping is per-file —
    it is a font subset, not a code — so it is learned rather than assumed.
    """
    import difflib
    from collections import defaultdict
    seen = defaultdict(lambda: defaultdict(int))
    for g, t in anchors:
        gs = normalise(clean(g)).replace(' ', '')
        ts = normalise(clean(t)).replace(' ', '')
        sm = difflib.SequenceMatcher(None, gs, ts, autojunk=False)
        for op, i1, i2, j1, j2 in sm.get_opcodes():
            if op == 'equal':
                for k in range(i2 - i1):
                    seen[gs[i1 + k]][ts[j1 + k]] += 1
            elif op == 'replace' and (i2 - i1) == (j2 - j1):
                for k in range(i2 - i1):
                    seen[gs[i1 + k]][ts[j1 + k]] += 1
    # Keep the readings that actually recur; a single sighting is noise.
    return {g: {t for t, n in opts.items() if n >= 2} or set(opts)
            for g, opts in seen.items()}


def lcs_under(cipher, g, t):
    """Longest run of the wreck that the candidate can account for, in order."""
    n, m = len(g), len(t)
    if not n or not m:
        return 0
    prev = [0] * (m + 1)
    for i in range(1, n + 1):
        cur = [0] * (m + 1)
        gi = g[i - 1]
        ok = cipher.get(gi, set()) | {gi}
        for j in range(1, m + 1):
            cur[j] = (prev[j - 1] + 1) if t[j - 1] in ok else max(prev[j], cur[j - 1])
        prev = cur
    return prev[m]


def score_with(cipher, garbled, candidate):
    g = normalise(clean(garbled)).replace(' ', '')
    t = normalise(clean(candidate)).replace(' ', '')
    if not g or not t:
        return 0.0
    covered = lcs_under(cipher, g, t)
    # What survived must be explained by the candidate (precision), and the
    # candidate must not be far longer than the wreck it is explaining.
    precision = covered / len(g)
    length = min(len(g), len(t)) / max(len(g), len(t))
    return 0.75 * precision + 0.25 * length


def resolve(garbled_names, candidates, cipher=None, prior=None, bonus=0.22):
    """One-to-one: the assignment of names to wrecks that scores best overall.

    `prior` maps a garbled index to the people its عرفات counterpart held; the
    same men serve in both distributions, so being one of them is evidence.

    Claiming greedily is not enough on its own: one wrong early claim pushes the
    man it stole onto a second wreck and the error travels. So the greedy result
    is then refined by swapping any two assignments that score better crossed —
    which is what pulls سعد نبهان back onto the cell that spells him.
    """
    S = {}
    for i, g in enumerate(garbled_names):
        pool = prior.get(i) if prior else None
        row = {}
        for name in candidates:
            s = (score_with(cipher, g, name) if cipher else score(g, name))
            if pool and name in pool:
                s += bonus
            if s > 0.30:
                row[name] = s
        S[i] = row

    pairs = sorted(((s, i, n) for i, row in S.items() for n, s in row.items()),
                   key=lambda x: (-x[0], x[1], x[2]))
    out, used_g, used_c = {}, set(), set()
    for s, i, name in pairs:
        if i in used_g or name in used_c:
            continue
        out[i] = name
        used_g.add(i)
        used_c.add(name)

    def val(i, n):
        return S[i].get(n, 0.0)

    idx = sorted(out)
    for _ in range(6):
        improved = False
        for a in range(len(idx)):
            for b in range(a + 1, len(idx)):
                i, j = idx[a], idx[b]
                x, y = out[i], out[j]
                if val(i, x) + val(j, y) < val(i, y) + val(j, x) - 1e-9:
                    out[i], out[j] = y, x
                    improved = True
        if not improved:
            break
    return {i: (n, min(val(i, n), 1.0)) for i, n in out.items()}


def arafat_pool_by_supervisor():
    """Who each عرفات مركز held, keyed by the man who ran it.

    منى is the same distribution redrawn: مركز 11 of عرفات becomes منى's 11 and
    15, and 10 and 12 are run together. Matching supervisors is what lets one
    file vouch for the other.
    """
    import extract as ex
    from names import key_of
    out = {}
    for c in ex.arafat_centers():
        k = roster._alias(key_of(c['supervisor']))
        out[k] = [m for cm in c['camps'] for m in cm['members']]
    return out


# The bodies 3172 allots tent space to. منى allots to the same ones, and their
# names are wrecked exactly as the people's are, so they are recognised the same
# way — against this list rather than against the roster.
BODIES = [
    'الإدارة الصحية', 'الإدارة الدينية', 'إدارة الكتلة الطبية',
    'إدارة الكتلة الدينية', 'أعضاء اللجنة الاعتبارية', 'الهيئة الرقابية',
    'أعضاء التوعية والإعلام', 'لجنة الشكاوى والصلح',
    'أعضاء لجنة الشكاوى والصلح', 'عضو وزارة السياحة', 'عضو وزارة داخلية',
]


def solve():
    r = roster.build()
    names = [p['name'] for p in r.all()]
    centers = parse()

    flat, where, owners = [], [], []
    for c in centers:
        for cm in c['camps']:
            # A cell that reads as a BODY better than as any man is an
            # allocation, not a member: it stays on the camp and gets no account.
            keep = []
            for m in cm['members']:
                best_body = max((score(m, b) for b in BODIES), default=0)
                best_person = max((score(m, n) for n in names), default=0)
                if best_body > best_person and best_body > 0.5:
                    cm['bodies'].append(m)
                else:
                    keep.append(m)
            cm['members'] = keep
            for m in keep:
                flat.append(m)
                where.append((c['no'], 'مخيم ' + str(cm['no'])))
                owners.append(c['supervisors'])
        if c.get('coasters'):
            for m in c['coasters']['members']:
                flat.append(m)
                where.append((c['no'], 'كوسترات'))
                owners.append(c['supervisors'])

    # Pass 1: the plain scorer, to find anchors the cipher can be learned from.
    from names import key_of
    first = resolve(flat, names)
    anchors = [(flat[i], nm) for i, (nm, s) in first.items() if s >= 0.66]
    cipher = learn_cipher(anchors)

    # Pass 2: cipher-aware, with عرفات vouching for who belongs where.
    pools = arafat_pool_by_supervisor()
    prior = {}
    for i, sups in enumerate(owners):
        p = []
        for s in sups:
            p += pools.get(roster._alias(key_of(s)), [])
        # منى 15 is carved out of عرفات 11, which أحمد سرميني ran.
        if not p:
            p = [m for v in pools.values() for m in v]
        prior[i] = set(p)
    got = resolve(flat, names, cipher=cipher, prior=prior)
    return centers, flat, where, got, cipher, anchors


if __name__ == '__main__':
    centers, flat, where, got, cipher, anchors = solve()
    print(f'anchors used to learn the cipher: {len(anchors)}')
    show = {g: sorted(v) for g, v in sorted(cipher.items()) if len(v) <= 3}
    print('learned readings (unambiguous ones):')
    print('   ' + '  '.join(f'{g}->{"".join(v)}' for g, v in list(show.items())[:28]))
    print()
    print(f'garbled member cells: {len(flat)}  matched: {len(got)}\n')
    low = 0
    for i, g in enumerate(flat):
        name, s = got.get(i, ('—', 0.0))
        flag = '' if s >= CONFIDENT else '   << LOW'
        if s < CONFIDENT:
            low += 1
        print(f'  {where[i][0]:>6} {where[i][1]:<10} {g:<34} -> {name:<32} {s:.2f}{flag}')
    print(f'\nlow-confidence: {low}/{len(flat)}')
    print('\ncenters:')
    for c in centers:
        print(f"  المركز {c['no']}  مشرف: {', '.join(c['supervisors'])}  "
              f"camps={[(x['no'], x['tents'], len(x['members'])) for x in c['camps']]}"
              f"  coasters={len(c.get('coasters', {}).get('members', []))}")
