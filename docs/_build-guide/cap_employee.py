# -*- coding: utf-8 -*-
"""Screenshots for دليل الموظف, on a phone-sized window.

Run: .venv/bin/python cap_employee.py   (starts the employee/ folder afresh)

Forms are opened and typed into to show them; nothing here presses a button
that saves or sends. The data on screen is rewritten by anon.py.
"""
import shutil, traceback
from cap import Cap, PHONE, ROOT

OUT = "employee"
shutil.rmtree(ROOT / OUT, ignore_errors=True)


def step(fn):
    try:
        fn()
    except Exception as e:
        print("  !! step failed:", fn.__name__, e)
        traceback.print_exc(limit=1)


# ── signed out: login and registration ─────────────────────────────────
(ROOT / "state-guest.json").unlink(missing_ok=True)
g = Cap(OUT, PHONE, state="state-guest.json")


def login_screen():
    g.open("/login", wait=5); g.ready()
    g.shot("login", "شاشة تسجيل الدخول", hl=["البريد الإلكتروني", "كلمة المرور", "تسجيل الدخول"])


def login_filled():
    g.fill("البريد الإلكتروني", "user01@example.com"); g.fill("كلمة المرور", "Example!123")
    g.shot("login-filled", "البريد الإلكتروني وكلمة المرور قبل الضغط على «تسجيل الدخول»")


def register():
    g.open("/login", wait=4); g.ready()
    g.click_text("إنشاء حساب", exact=True, wait=3); g.ready()
    g.shot("register", "شاشة إنشاء حساب جديد", hl=["البريد الإلكتروني", "كلمة المرور", "تأكيد كلمة المرور"])


def login_settings():
    g.open("/login", wait=4); g.ready()
    g.click_text("الإعدادات", exact=True, wait=2); g.ready()
    g.shot("login-settings", "إعدادات اللغة والمظهر قبل الدخول")


for f in (login_screen, login_filled, register, login_settings):
    step(f)
g.close()

# ── signed in ──────────────────────────────────────────────────────────
(ROOT / "state-phone.json").unlink(missing_ok=True)
c = Cap(OUT, PHONE, state="state-phone.json")
c.login()


def home():
    c.go("/"); c.shot("home", "الشاشة الرئيسية: مواقيت الصلاة والخريطة التشغيلية", hl=["مواقيت الصلاة", "القائمة", "الإشعارات"])
    # The whole roadmap is ONE semantics node, so it cannot be scrolled to by
    # text; phase 3 sits ~4350px down on a phone (measured).
    c.scroll(2600, wait=0.8); c.scroll(1750, wait=0.8); c.ready()
    c.shot("home-run", "مرحلة «تشغيل الموسم» في الخريطة التشغيلية: خطواتها مفتوحة للجميع")


def drawer():
    c.go("/"); c.click_text("القائمة", exact=True, wait=2); c.ready()
    c.shot("drawer", "القائمة الجانبية: أقسام التطبيق بحسب صلاحياتك")
    c.scroll(700, x=150); c.ready()
    c.shot("drawer-2", "بقية القائمة الجانبية")


def notifications():
    c.go("/notifications"); c.shot("notifications", "الإشعارات وفلاترها", hl=["الكل"])


def profile():
    c.go("/my-profile"); c.shot("profile", "ملفي الشخصي", hl=["تعديل الملف", "تغيير كلمة المرور", "تغيير البريد الإلكتروني"])
    c.scroll(800); c.ready(); c.shot("profile-2", "المعلومات الشخصية وبيانات التواصل في الملف")
    c.go("/my-profile"); c.click_text("تعديل الملف", wait=2); c.ready()
    c.shot("profile-edit", "تعديل الملف الشخصي", hl=["الصورة الشخصية"])
    c.scroll(700); c.ready()
    c.shot("profile-edit-2", "أرقام الهاتف والوثائق في تعديل الملف")
    c.go("/my-profile"); c.click_text("تغيير كلمة المرور", wait=2); c.ready()
    c.shot("password", "تغيير كلمة المرور")


def settings():
    c.go("/settings"); c.shot("settings", "الإعدادات: الحساب واللغة والمظهر", hl=["إضافة حساب آخر", "اللغة", "المظهر"])
    c.scroll(900); c.ready(); c.shot("settings-2", "بقية الإعدادات")


def modules():
    c.go("/modules"); c.shot("modules", "الملفات التشغيلية المسندة إليك")


def tasks():
    c.go("/tasks"); c.shot("tasks", "مهامي وفلاترها", hl=["اليوم", "مهمة جديدة"])
    c.click_text("مهمة جديدة", wait=2); c.ready()
    c.shot("task-new", "نافذة مهمة جديدة")


def checkin():
    c.go("/check-in/mine"); c.shot("checkins", "سجلّ حضوري")
    c.go("/check-in"); c.shot("checkin-scan", "شاشة مسح رمز المكان")


def incident():
    c.go("/incident"); c.shot("incident", "بلاغ عاجل", hl=["ما الذي حدث؟"])
    c.fill("ما الذي حدث؟", "تعطّلت حافلة المجموعة الثالثة عند مدخل مخيّم منى، والحجاج ينتظرون منذ نصف ساعة.")
    c.ready(); c.shot("incident-filled", "بلاغ مكتوب قبل الإرسال", hl=["عن ماذا؟", "إرفاق صورة", "أرسل البلاغ"])
    c.click_text("عن ماذا؟", wait=2); c.ready()
    c.shot("incident-about", "ربط البلاغ بملف أو مهمة أو مكان")
    c.go("/my-incidents"); c.shot("my-incidents", "بلاغاتي وحالة كلٍّ منها")


def reports():
    c.go("/reports"); c.shot("reports", "القرارات والتعميمات")


def complaints():
    c.go("/complaints"); c.shot("complaints", "شكاواي")
    c.click_text("تقديم شكوى", wait=2); c.ready()
    c.shot("complaint-new", "تقديم شكوى جديدة")


def evaluations():
    c.go("/evaluations"); c.shot("evaluations", "التقييمات المكلَّف بها")
    c.click_text("توزيع أعضاء", wait=3); c.ready()
    c.shot("evaluation-open", "فتح تقييم من القائمة")


def journey():
    c.go("/my-journey"); c.shot("journey", "مساري: رحلات القدوم والتنقّل والعودة")


def outbox():
    c.go("/outbox"); c.shot("outbox", "بانتظار الإرسال: ما كُتب دون اتصال")


for f in (home, drawer, notifications, profile, settings, modules, tasks, checkin, incident, reports,
          complaints, evaluations, journey, outbox):
    step(f)
c.close()
print("done:", len(c.manifest), "shots")
