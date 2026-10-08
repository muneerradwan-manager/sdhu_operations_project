# -*- coding: utf-8 -*-
"""Screenshots for دليل الإدارة, on a desktop-sized window.

Run: .venv/bin/python cap_management.py   (starts the management/ folder afresh)

Ordered as the season runs — the app's own «الخريطة التشغيلية». Forms are
opened and typed into to show them; nothing here presses a button that saves,
sends, approves, assigns or deletes. The data on screen is rewritten by anon.py.
"""
import shutil, traceback
from cap import Cap, DESKTOP, ROOT

OUT = "management"
shutil.rmtree(ROOT / OUT, ignore_errors=True)
(ROOT / "state-desktop.json").unlink(missing_ok=True)
c = Cap(OUT, DESKTOP, state="state-desktop.json")
c.login()


def step(fn):
    try:
        fn()
    except Exception as e:
        print("  !! step failed:", fn.__name__, e)
        traceback.print_exc(limit=1)


# ── the frame ─────────────────────────────────────────────────────────
def frame():
    c.go("/"); c.shot("home", "الواجهة على شاشة واسعة: القائمة الثابتة إلى اليمين والخريطة التشغيلية في الوسط",
                      hl=["الخريطة التشغيلية", "الإعدادات"])
    # The roadmap is ONE semantics node, so it is scrolled by distance:
    # phase 2 sits ~1700px down at this window size (measured).
    c.scroll(1300, x=400, wait=0.8); c.scroll(400, x=400, wait=0.8); c.ready()
    c.shot("roadmap-build", "مرحلة «بناء العمل» في الخريطة التشغيلية وخطواتها")


# ── phase 1: setting the ground ───────────────────────────────────────
def seasons():
    c.go("/seasons"); c.shot("seasons", "المواسم: الموسم الحالي والمواسم السابقة", hl=["الموسم الحالي"])
    # The season CARD, not the "1448 هـ" in the menu header — clicking that
    # one folds the side menu for every screen after it.
    card = next(n for n in c.nodes() if "1448" in n["t"] and n["x"] < 900)
    c.click_xy(card["x"] + card["w"] / 2, card["y"] + card["h"] / 2, wait=2); c.ready()
    c.shot("season-open", "صفحة الموسم الحالي ومشاركوه")


def reference():
    c.go("/reference-data"); c.shot("reference", "البيانات المرجعية: الأماكن وتقسيمات الملفات والبعثة")
    c.click_text("الفنادق", wait=2); c.ready()
    c.shot("reference-hotels", "قائمة الفنادق")
    c.go("/reference-data"); c.click_text("الوصف الوظيفي", wait=2); c.ready()
    c.shot("reference-jobs", "قائمة الوصف الوظيفي")


def approvals():
    c.go("/approvals"); c.shot("approvals", "اعتماد الحسابات: التسجيلات المنتظرة")


def employees():
    c.go("/employees"); c.shot("employees", "الموظفون: الدائمون والخارجيون، مع البحث والفلاتر",
                               hl=["الموظفون الدائمون", "الموظفون الخارجيون"])
    nodes = [n for n in c.nodes() if n["role"] == "button" and n["y"] > 160 and n["x"] < 900 and "\n" in n["t"]]
    if nodes:
        n = nodes[0]; c.click_xy(n["x"] + n["w"] / 2, n["y"] + n["h"] / 2, wait=2); c.ready()
        c.shot("employee-open", "صفحة موظف")
        c.scroll(600, x=400); c.ready(); c.shot("employee-open-2", "بقية صفحة الموظف")
    c.go("/employees"); c.click_text("الموظفون الخارجيون", wait=2); c.ready()
    c.shot("employees-external", "الموظفون الخارجيون")


def permissions():
    c.go("/permissions"); c.shot("permissions", "الصلاحيات: مجموعات الصلاحيات وما يفتحه كلٌّ منها")
    c.scroll(700, x=400); c.ready(); c.shot("permissions-2", "بقية مجموعات الصلاحيات")


# ── phase 2: building the work ───────────────────────────────────────
def modules():
    c.go("/modules/manage"); c.shot("modules-manage", "إدارة الملفات التشغيلية", hl=["ملف جديد"])
    c.click_text("ملف جديد", wait=2); c.ready()
    c.shot("module-new", "إنشاء ملف تشغيلي جديد")
    c.scroll(600, x=400); c.ready(); c.shot("module-new-2", "بقية نموذج الملف الجديد")


def tasks():
    c.go("/tasks/manage"); c.shot("tasks-manage", "لوحة المهام: ما أسندتَه إلى الآخرين", hl=["إسناد مهمة"])
    c.click_text("إسناد مهمة", wait=2); c.ready()
    c.shot("task-assign", "إسناد مهمة إلى موظف")


def forms():
    c.go("/evaluations/forms"); c.shot("forms", "نماذج التقييم", hl=["نموذج جديد"])
    c.click_text("نموذج جديد", wait=2); c.ready()
    c.shot("form-new", "كتابة نموذج تقييم جديد")


def circulars():
    c.go("/reports/manage"); c.shot("circulars-manage", "إدارة القرارات والتعميمات", hl=["مستند جديد"])
    c.click_text("مستند جديد", wait=2); c.ready()
    c.shot("circular-new", "إدخال قرار أو تعميم جديد")


def broadcast():
    c.go("/notifications"); c.shot("notifications", "الإشعارات، وزر إرسال إشعار", hl=["إرسال إشعار"])
    c.click_text("إرسال إشعار", wait=2); c.ready()
    c.shot("notify-new", "إرسال إشعار إلى أشخاص أو ملف أو البعثة كلها")


def travel():
    c.go("/travel"); c.shot("travel", "رحلات الموسم: القدوم والتنقّل الداخلي والعودة", hl=["رحلة جديدة"])
    try:
        c.click_text("مطار دمشق", wait=2); c.ready(); c.shot("trip-open", "تفاصيل رحلة")
    except LookupError:
        pass
    c.go("/travel"); c.click_text("رحلة جديدة", wait=2); c.ready()
    c.shot("trip-new", "تسجيل رحلة جديدة")


# ── phase 4: watching ─────────────────────────────────────────────────
def dashboard():
    c.go("/dashboard"); c.shot("dashboard", "لوحة المؤشرات")
    c.scroll(650, x=400); c.ready(); c.shot("dashboard-2", "بقية لوحة المؤشرات: الأشخاص والملفات")


def watch():
    c.go("/map"); c.shot("map", "خريطة الموسم")
    c.go("/presence"); c.shot("presence", "سجل الدوام: من حضر، وأين، ومتى")
    c.go("/incidents"); c.shot("incidents", "البلاغات العاجلة كما تصل إلى غرفة العمليات", hl=["أتولّاه", "إظهار المغلقة"])
    c.go("/complaints/manage"); c.shot("complaints-manage", "سجل الشكاوى")
    c.go("/audit-log"); c.shot("audit", "سجل الأحداث: من فعل ماذا ومتى")


# ── phase 5: closing the year ─────────────────────────────────────────
def close_year():
    c.go("/evaluations/manage"); c.shot("evaluations-manage", "سجل التقييمات وعلاماتها")
    c.go("/export"); c.shot("export", "تصدير البيانات: اختر الجدول أولاً")
    c.click_text("الموظفون والمشاركون", wait=2); c.ready()
    c.shot("export-columns", "اختيار الأعمدة وصيغة الملف للتصدير")


for f in (frame, seasons, reference, approvals, employees, permissions, modules, tasks, forms, circulars,
          broadcast, travel, dashboard, watch, close_year):
    step(f)
c.close()
print("done:", len(c.manifest), "shots")
