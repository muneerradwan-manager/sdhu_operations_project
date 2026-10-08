"""Fill the empty lam-alef ligatures in the PDF copies of itfQomra.

    python tool/fill_pdf_font_ligatures.py assets/fonts/pdf/*.ttf

Run this over `assets/fonts/pdf/` whenever those files are rebuilt from the
OTFs in `assets/fonts/itfQomra/`. `test/pdf_font_test.dart` fails if you forget.

Requires `fonttools` (pip install fonttools). Nothing in the app or the build
runs it — the patched TTFs are committed, and this is the recipe for making
them again.

WHY
---
itfQomra declares U+FEF5..U+FEFC — the eight lam-alef presentation forms — in
its cmap and leaves every one of them with zero contours. On screen that is
invisible: HarfBuzz never asks for the legacy presentation block, it joins lam
and alef through the font's own `init`/`fina` forms. The `pdf` package has no
OpenType shaper at all; it maps Arabic straight onto the presentation forms, so
it asks for precisely the eight glyphs that were never drawn.

The result is not a blank either. An empty glyph has `loca[i] == loca[i+1]`,
and `TtfParser.readGlyph` reads from that offset anyway, landing inside
whichever glyph is stored next — so «الإلكتروني» came out as «الɑلكتروني», with
a Latin letter in the middle of an Arabic word, in every exported PDF.

Each ligature is rebuilt below from the two joined forms the font does draw,
arranged the way the renderer would have arranged them: the alef on the left,
the lam on the right, the lam pushed over by the alef's advance so the alef's
connecting tail runs under it. The result is not the hand-drawn ligature a type
designer would cut — it is lam and alef set touching — but it is the same two
letters this font already draws that way on screen, and it is a word rather
than a hole.
"""

import sys

from fontTools.misc.transform import Offset
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

# target codepoint -> (alef part, lam part).
#
# The ISOLATED ligature takes the initial lam — nothing joins it from the right
# — and the FINAL one takes the medial lam, which carries the tail back to the
# letter before it.
# isolated presentation form -> the base letter whose glyph IS that shape.
#
# These are not the font's fault. The `pdf` package does not read isolated forms
# out of the cmap at all — it aliases them itself, in `basicToIsolatedMappings`
# in `pdf/src/pdf/font/bidi_utils.dart`, mapping each base letter's glyph onto
# the isolated codepoint. That table has one wrong line:
#
#     0x064A: 0xFEEF, // ي
#
# U+FEEF is the isolated ى (alef maqsura, U+0649). The isolated ي is U+FEF1.
# So the package hands ي's glyph to ى — «شورى» prints «شوري», a different word —
# and leaves U+FEF1 with no glyph at all, so a ي standing alone is simply not
# drawn: «الحموي» prints «الحمو», «إداري» prints «إدار», «هادي» prints «هاد».
# A letter of a man's name silently disappearing is not a thing to leave in an
# official sheet, and it happens to every name ending in ي after one of the
# letters that does not join forward — ا د ذ ر ز و.
#
# Written into the font's own cmap as REAL entries, which is what makes them
# win: the package's aliases are laid down while it walks the base letters, and
# a real entry at U+FEEF or U+FEF1 is reached later in the same ascending pass
# and overwrites the wrong one.
ISOLATED = {
    0xFEEF: 0x0649,  # ى  — the package aliases this to ي's glyph
    0xFEF1: 0x064A,  # ي  — the package aliases this to nothing at all
}

LIGATURES = {
    0xFEF5: ("uniFE82", "uniFEDF"),  # lam + alef madda,       isolated
    0xFEF6: ("uniFE82", "uniFEE0"),  # lam + alef madda,       final
    0xFEF7: ("uniFE84", "uniFEDF"),  # lam + alef hamza above, isolated
    0xFEF8: ("uniFE84", "uniFEE0"),  # lam + alef hamza above, final
    0xFEF9: ("uniFE88", "uniFEDF"),  # lam + alef hamza below, isolated
    0xFEFA: ("uniFE88", "uniFEE0"),  # lam + alef hamza below, final
    0xFEFB: ("uniFE8E", "uniFEDF"),  # lam + alef,             isolated
    0xFEFC: ("uniFE8E", "uniFEE0"),  # lam + alef,             final
}


def fill(path: str) -> None:
    font = TTFont(path)
    glyphs = font.getGlyphSet()
    glyf = font["glyf"]
    hmtx = font["hmtx"]
    cmap = font.getBestCmap()

    for code, (alef, lam) in LIGATURES.items():
        target = cmap.get(code)
        if target is None:
            raise SystemExit(f"{path}: U+{code:04X} is not in the cmap")
        for part in (alef, lam):
            if part not in glyphs:
                raise SystemExit(f"{path}: {part} is missing")
            if glyf[part].numberOfContours <= 0:
                raise SystemExit(f"{path}: {part} is itself empty")

        alef_width = hmtx[alef][0]
        lam_width = hmtx[lam][0]

        pen = TTGlyphPen(glyphs)
        # Decomposed to plain contours rather than left as components: a simple
        # glyph is the one shape every PDF reader agrees on.
        for name, dx in ((alef, 0), (lam, alef_width)):
            recorder = DecomposingRecordingPen(glyphs)
            glyphs[name].draw(recorder)
            recorder.replay(TransformPen(pen, Offset(dx, 0)))

        built = pen.glyph()
        built.recalcBounds(glyf)
        glyf[target] = built
        hmtx[target] = (alef_width + lam_width, built.xMin)

    for code, base in ISOLATED.items():
        glyph = cmap.get(base)
        if glyph is None:
            raise SystemExit(f"{path}: base U+{base:04X} is not in the cmap")
        # Into every Unicode subtable, because the reader walks all of them.
        for table in font["cmap"].tables:
            if table.platformID in (0, 3):
                table.cmap[code] = glyph

    font.save(path)
    print(f"filled {path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    for argument in sys.argv[1:]:
        fill(argument)
