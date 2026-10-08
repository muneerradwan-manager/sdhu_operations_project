# -*- coding: utf-8 -*-
"""Capture helper for the guides: drives the PUBLISHED web build with Playwright.

Flutter draws on a canvas, so there is no DOM to read until semantics are on.
`Cap.open()` switches them on; after that every label is an `flt-semantics`
node with a real bounding box, which is what makes two things possible:
clicking by visible text, and finding where personal data sits on screen so
`blur.py` can cover it.

Every shot saves, next to the PNG, the text and box of every semantics node on
screen at that moment (`shots/<n>-<key>.json`). Nothing is blurred here: raw
shots stay in the gitignored shots/ folder, and only `blur.py`'s output goes
into a guide.

The login comes from SDHU Projects/keys/guide-admin.env, outside the repo.

This app talks to the LIVE database. Capture scripts open screens and fill
forms; they never press a button that saves.
"""
import json, os, re, sys, time
from pathlib import Path
from playwright.sync_api import sync_playwright

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).parent
BASE = os.environ.get("CAP_BASE", "https://muneerradwan-manager.github.io/sdhu_operations_project/")
KEYS = ROOT.parents[2] / "keys" / "guide-admin.env"

PHONE = dict(width=412, height=915, scale=2)
DESKTOP = dict(width=1280, height=800, scale=1.5)


def creds():
    env = dict(l.split("=", 1) for l in KEYS.read_text("utf-8").splitlines() if "=" in l)
    return env["ADMIN_EMAIL"].strip(), env["ADMIN_PASSWORD"].strip()


# Every wait goes through page.wait_for_timeout, never time.sleep: in the sync
# API, intercepted requests (anon.py) are only served while the script is
# inside a Playwright call, and a time.sleep would freeze the app's network.
class Cap:
    def __init__(self, outdir, size=PHONE, state=None, anon=True):
        self.out = ROOT / outdir
        (self.out / "shots").mkdir(parents=True, exist_ok=True)
        self.man_path = self.out / "manifest.json"
        self.manifest = json.loads(self.man_path.read_text("utf-8")) if self.man_path.exists() else []
        self.state = ROOT / (state or f"state-{outdir}.json")
        self.pw = sync_playwright().start()
        self.browser = self.pw.chromium.launch(channel="chrome", headless=True)
        kw = dict(viewport={"width": size["width"], "height": size["height"]},
                  device_scale_factor=size["scale"], locale="ar", timezone_id="Asia/Riyadh")
        if self.state.exists():
            kw["storage_state"] = str(self.state)
        self.ctx = self.browser.new_context(**kw)
        self.anon = None
        if anon:
            from anon import Anon
            self.anon = Anon(*creds())
            self.anon.install(self.ctx)
        self.page = self.ctx.new_page()

    # ── navigation ──────────────────────────────────────────────────────
    def open(self, route="/", wait=5.0):
        """Load the app at a route (hash routing) and switch semantics on."""
        self.page.goto(BASE + "#" + route, wait_until="networkidle")
        for _ in range(40):
            if self.page.locator("flutter-view, flt-glass-pane").count():
                break
            self.page.wait_for_timeout((0.5) * 1000)
        self.page.wait_for_timeout((wait) * 1000)
        self.semantics()
        return self

    def go(self, route, wait=2.0):
        """Change route inside the running app, without reloading it.
        Escape first: a drawer, sheet or dialog left open by the previous step
        would otherwise sit over the next screen."""
        for _ in range(3):
            self.page.keyboard.press("Escape")
            self.page.wait_for_timeout(300)
        if self.page.url.split("#")[-1] == route:
            # Same address: setting it again changes nothing, and the screen
            # would keep whatever scroll or state the last step left on it.
            self.page.evaluate("() => { window.location.hash = '/outbox' }")
            self.page.wait_for_timeout(1200)
        self.page.evaluate("r => { window.location.hash = r }", route)
        self.page.wait_for_timeout((wait) * 1000)
        self.semantics()
        self.ready()
        return self

    def ready(self, quiet=2, timeout=40):
        """Wait until what is on screen stops changing: data loaded, skeletons
        gone, animations done. `quiet` consecutive identical polls a second
        apart count as settled."""
        last, same, t0 = None, 0, time.time()
        while time.time() - t0 < timeout:
            # digits masked: a ticking countdown is not "still loading"
            cur = tuple(sorted(re.sub(r"[\d\u0660-\u0669:]+", "#", n["t"]) for n in self.nodes()))
            same = same + 1 if cur == last else 0
            if same >= quiet and cur:
                return True
            last = cur
            self.page.wait_for_timeout((1.0) * 1000)
        print("  (ready: timed out, capturing anyway)")
        return False

    def semantics(self):
        ph = self.page.locator("flt-semantics-placeholder")
        if ph.count():
            ph.first.dispatch_event("click")
            self.page.wait_for_timeout((1.0) * 1000)
        # The page is dir=rtl, so the browser anchors Flutter's (invisible)
        # semantics overlay to the RIGHT edge and every box comes back shifted
        # sideways. The overlay draws nothing — Flutter paints on its canvas —
        # so laying it out LTR changes no pixel and makes the boxes true.
        self.page.evaluate("""() => {
          if (document.getElementById('__ltr')) return;
          const s = document.createElement('style'); s.id = '__ltr';
          s.textContent = 'flt-semantics-host { left: 0 !important; } flt-semantics-host, flt-semantics-host * { direction: ltr !important; }';
          document.head.append(s);
        }""")

    def settle(self, s=1.0):
        self.page.wait_for_timeout((s) * 1000)

    # ── interaction ────────────────────────────────────────────────────
    def nodes(self):
        """Every labelled semantics node on screen: text + box in CSS pixels."""
        return self.page.evaluate("""() => {
          const out = [];
          for (const el of document.querySelectorAll('flt-semantics, flt-semantics-container, input, textarea')) {
            const r = el.getBoundingClientRect();
            if (r.width < 2 || r.height < 2) continue;
            if (r.bottom < 0 || r.top > innerHeight || r.right < 0 || r.left > innerWidth) continue;
            let t = (el.getAttribute('aria-label') || '');
            if (!t && el.tagName !== 'FLT-SEMANTICS-CONTAINER') {
              // own text only (text nodes and the <span> Flutter wraps them in),
              // not the text of nested semantics nodes
              t = Array.from(el.childNodes)
                .filter(n => n.nodeType === 3 || (n.nodeType === 1 && n.tagName === 'SPAN'))
                .map(n => n.textContent).join(' ');
            }
            if (el.value) t = (t + ' ' + el.value).trim();
            t = t.trim();
            if (!t) continue;
            out.push({t, x: r.left, y: r.top, w: r.width, h: r.height,
                      role: el.getAttribute('role') || el.tagName.toLowerCase()});
          }
          return out;
        }""")

    def find(self, text, exact=False, nth=0):
        hits = [n for n in self.nodes() if (n["t"] == text if exact else text in n["t"])]
        if len(hits) <= nth:
            raise LookupError(f"no node with text {text!r}")
        return hits[nth]

    def click_text(self, text, exact=False, nth=0, wait=1.5):
        n = self.find(text, exact, nth)
        self.page.mouse.click(n["x"] + n["w"] / 2, n["y"] + n["h"] / 2)
        self.page.wait_for_timeout((wait) * 1000)
        self.semantics()
        return n

    def click_xy(self, x, y, wait=1.5):
        self.page.mouse.click(x, y)
        self.page.wait_for_timeout((wait) * 1000)
        self.semantics()

    def fill(self, label, value, nth=0, wait=0.4, clear=True):
        """Focus the field whose visible label contains `label`, then type into it."""
        self.click_text(label, nth=nth, wait=0.6)
        if clear:
            self.page.keyboard.press("Meta+A"); self.page.keyboard.press("Backspace")
        self.page.keyboard.type(value, delay=15)
        self.page.wait_for_timeout((wait) * 1000)

    def scroll(self, dy, x=None, y=None, wait=1.0):
        vp = self.page.viewport_size
        self.page.mouse.move(x or vp["width"] / 2, y or vp["height"] / 2)
        self.page.mouse.wheel(0, dy)
        self.page.wait_for_timeout((wait) * 1000)
        self.semantics()

    def scroll_to_text(self, text, top=90, step=450, tries=25):
        """Scroll until `text` sits near the top of the screen."""
        for _ in range(tries):
            try:
                n = self.find(text)
                if n["y"] <= top + 60:
                    break
                self.scroll(min(step, n["y"] - top), wait=0.6)
                if abs(self.find(text)["y"] - n["y"]) < 4:
                    break           # cannot scroll further
            except LookupError:
                self.scroll(step, wait=0.6)
        self.ready()

    def back(self, wait=1.5):
        self.page.go_back(); self.page.wait_for_timeout((wait) * 1000); self.semantics()

    # ── session ────────────────────────────────────────────────────────
    def login(self, email=None, password=None):
        e, p = creds()
        self.open("/login", wait=6)
        self.ready()
        if "/login" not in self.page.url:
            return self          # the saved session is still good
        self.fill("البريد الإلكتروني", email or e)
        self.fill("كلمة المرور", password or p)
        self.click_text("تسجيل الدخول", exact=True, wait=2)
        t0 = time.time()
        while "/login" in self.page.url and time.time() - t0 < 60:
            self.page.wait_for_timeout((1) * 1000)
        if "/login" in self.page.url:
            raise RuntimeError("login did not complete")
        self.page.wait_for_timeout((3) * 1000)
        self.ctx.storage_state(path=str(self.state))
        # Reload: the login form's hidden inputs (with the address typed in
        # them) otherwise linger in the DOM for the rest of the session.
        self.open("/", wait=4)
        self.ready()
        return self

    # ── capture ───────────────────────────────────────────────────────
    def shot(self, key, caption, hl=None, full=False, blur_extra=None, keep=None):
        """hl: list of texts (or (x,y,w,h) boxes) to frame in red and number.
        blur_extra: boxes that blur.py must cover besides the detected ones.
        keep: texts blur.py must NOT cover (e.g. a label that looks like a name)."""
        n = len(self.manifest) + 1
        stem = f"{n:03d}-{key}"
        marks = []
        for i, h in enumerate(hl or [], 1):
            box = h if isinstance(h, (tuple, list)) else None
            if box is None:
                nd = self.find(h)
                box = (nd["x"], nd["y"], nd["w"], nd["h"])
            marks.append(box)
        if marks:
            self.page.evaluate("""ms => {
              ms.forEach((m, i) => {
                const d = document.createElement('div'); d.className = '__hl';
                Object.assign(d.style, {position:'fixed', left:(m[0]-4)+'px', top:(m[1]-4)+'px',
                  width:(m[2]+8)+'px', height:(m[3]+8)+'px', border:'3px solid #E0245E', borderRadius:'10px',
                  zIndex: 99999, pointerEvents:'none'});
                const b = document.createElement('div'); b.className = '__hl'; b.textContent = i + 1;
                Object.assign(b.style, {position:'fixed', left:(m[0]+m[2]-10)+'px', top:(m[1]-16)+'px',
                  width:'24px', height:'24px', lineHeight:'24px', textAlign:'center', borderRadius:'12px',
                  background:'#E0245E', color:'#fff', font:'bold 14px sans-serif', zIndex: 100000,
                  pointerEvents:'none'});
                document.body.append(d, b);
              });
            }""", marks)
        # Park the pointer on the empty left margin: left over an item (or the
        # date in the menu header) it raises a hover tooltip that would end up
        # in the picture.
        vp0 = self.page.viewport_size
        self.page.mouse.move(3, vp0["height"] / 2)
        self.page.wait_for_timeout(700)
        nodes = self.nodes()
        if self.anon:
            leak = self.anon.leaks([n["t"] for n in nodes])
            if leak:
                print(f"  !! {stem}: real data still on screen: {leak}")
        self.page.screenshot(path=str(self.out / "shots" / f"{stem}.png"), full_page=full)
        self.page.evaluate("() => document.querySelectorAll('.__hl').forEach(e => e.remove())")
        vp = self.page.viewport_size
        (self.out / "shots" / f"{stem}.json").write_text(json.dumps(
            {"vp": vp, "nodes": nodes, "blur_extra": blur_extra or [], "keep": keep or []},
            ensure_ascii=False), "utf-8")
        self.manifest.append({"key": key, "file": f"{stem}.png", "caption": caption})
        self.man_path.write_text(json.dumps(self.manifest, ensure_ascii=False, indent=1), "utf-8")
        print("shot", stem)
        return stem

    def peek(self, name="peek"):
        """A throwaway screenshot plus the on-screen texts, for finding the way."""
        p = self.out / "shots" / f"_{name}.png"
        self.page.screenshot(path=str(p))
        return p, [n["t"] for n in self.nodes()]

    def close(self):
        if self.anon:
            self.anon.dump_ascii(self.out / "ascii_seen.txt")
        try:
            self.ctx.storage_state(path=str(self.state))
        finally:
            self.browser.close(); self.pw.stop()
