# -*- coding: utf-8 -*-
"""Publish one written report that exercises everything a report can carry.

    export SUPABASE_SERVICE_KEY=sb_secret_...
    python supabase/seeds/reports_1447/general_notice.py --apply

التعليمات العامة لحجاج البعثة is a real notice — the sort of thing the
Administration actually posts — and it is written here to use every part of the
form at once, so the whole of it can be looked at on one screen:

  * every header field the general type declares: subtitle, note, and the
    official document, which means a real file uploaded to the private bucket
    and a real attachment row beside it;
  * a reference number, since half of what gets published carries one;
  * all ten block kinds, several of them more than once;
  * BOTH sides of the responsive table — a four-column table that stays a grid
    at any width, and a nine-column one that folds into cards below a monitor;
  * a QR carrying a URL and another carrying plain text, which are drawn the
    same way but scan to different things;
  * a list long enough to see the numbering run past nine.

GENERAL, with no season: instructions of this kind are true until they are
rewritten, which is the case `season_id is null` exists for.

Rebuilt from scratch on each run, so it is safe to repeat.
"""
import mimetypes
import os
import re
import sys
from urllib.parse import quote

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'decisions_1447'))
import sbx  # noqa: E402

APPLY = '--apply' in sys.argv
TITLE = 'التعليمات العامة لحجاج بعثة الحج السورية'
NUMBER = '3201'

# The paper the notice would have been typed from. Any real file will do — this
# one is in the repo already, and uploading a genuine document is the only way
# to see the attachment row, the signed URL and the download actually work.
SOURCE = os.path.join('assets', 'docs', 'meals', 'توقيت الوجبات.docx')

BLOCKS = [
    ('heading', {'text': 'قبل التوجّه إلى المشاعر'}),
    ('paragraph', {'text':
        'تبدأ رحلة المشاعر بالتوجّه إلى منى يوم التروية، وتنتهي بالنفرة من '
        'منى بعد أيام التشريق. هذه التعليمات تُقرأ قبل المغادرة، ويحتفظ بها '
        'الحاج معه طوال الأيام الخمسة.'}),
    ('numbers', {'items': [
        'احمل بطاقة نسك وسوار المعصم طوال الوقت، ولا تنزعهما عند النوم.',
        'تأكد من رقم مخيمك ورقم خيمتك قبل مغادرة الفندق، واحفظهما.',
        'ضع حقيبة صغيرة فيها الدواء والماء والمظلّة، واترك الباقي في الفندق.',
        'اتفق مع مشرف برجك على نقطة لقاء إن انقطع الاتصال.',
        'احفظ رقم مشرف مخيمك في هاتفك قبل المغادرة.',
        'تأكد من شحن هاتفك، واحمل بطارية احتياطية إن توفّرت.',
        'خذ ما يكفيك من دوائك الشخصي لخمسة أيام كاملة.',
        'ارتدِ حذاءً مريحاً، وضع علامة على حذائك قبل دخول المسجد.',
        'اكتب اسمك ورقم مخيمك على ورقة في جيبك.',
        'لا تحمل مبالغ نقدية كبيرة، واستعمل الخزنة في الفندق.',
        'راجع مواعيد الوجبات أدناه قبل يوم التروية.',
    ]}),
    ('note', {'text':
        'من فقد سواره أو بطاقته يراجع مشرف المخيم فوراً — لا تنتظر حتى موعد '
        'التفويج.'}),

    ('divider', {}),
    ('heading', {'text': 'الإعاشة في المشاعر'}),
    ('subheading', {'text': 'ما يُقدَّم، ومتى'}),
    ('paragraph', {'text':
        'تُقدَّم الوجبات في المخيمات وفق الجدول أدناه. الوجبة الجافة تُسلَّم '
        'في العبوة، والساخنة تُقدَّم في وقتها ولا تُخزَّن.'}),
    # Four columns: stays a grid at every width. Written in the 0104 OBJECT
    # shape on purpose — this file's job is to exercise everything a document
    # can carry, and a seed that writes the legacy shape teaches the wrong one.
    # اليوم spans (the date prints once against its meals) and التوقيت is a
    # time range stored canonically; the reader renders the sentence.
    ('table', {
        'columns': [
            {'id': 'c0', 'label': 'اليوم', 'kind': 'text', 'span': True},
            {'id': 'c1', 'label': 'الوجبة', 'kind': 'text'},
            {'id': 'c2', 'label': 'نوعها', 'kind': 'text'},
            {'id': 'c3', 'label': 'التوقيت', 'kind': 'time_range'},
        ],
        'rows': [
            ['8 ذي الحجة - تروية', 'غداء', 'جافة', '13:00-17:00'],
            ['8 ذي الحجة - تروية', 'عشاء', 'جافة', '19:00-22:00'],
            ['9 ذي الحجة - عرفات', 'فطور', 'جافة', '06:00-09:00'],
            ['9 ذي الحجة - عرفات', 'غداء', 'ساخنة', '13:00-16:00'],
            ['10 ذي الحجة - تشريق', 'عشاء', 'جافة', '19:00-22:00'],
        ],
    }),
    ('subheading', {'text': 'أعداد الوجبات حسب التكتل'}),
    ('paragraph', {'text':
        'الأرقام أدناه تقديرية وللاسترشاد فقط، والمعتمد ما ينشره فريق الإعاشة '
        'المركزية.'}),
    # Nine columns: folds into a card per row below a monitor.
    ('table', {
        'columns': ['اليوم', 'الوجبة', 'الذهبي', 'قباء', 'شذا مكة',
                    'الحمد', 'عطاء', 'النخبة', 'المجموع'],
        'rows': [
            ['8 ذي الحجة', 'غداء', '250', '160', '160', '250', '250', '260', '1330'],
            ['8 ذي الحجة', 'عشاء', '250', '160', '160', '250', '250', '260', '1330'],
            ['9 ذي الحجة', 'فطور', '1010', '650', '1150', '1048', '1010', '730', '5598'],
            ['9 ذي الحجة', 'غداء', '1010', '650', '1150', '1048', '1010', '730', '5598'],
        ],
    }),
    ('paragraph', {'text':
        'التفاصيل الكاملة لكل يوم ومكوّنات كل وجبة منشورة في تقريري «مواعيد '
        'تقديم الوجبات» و«مكونات الوجبات».'}),

    ('divider', {}),
    ('heading', {'text': 'عند الحاجة'}),
    ('bullets', {'items': [
        'مشرف المخيم — أول من يُراجَع في كل ما يخصّ السكن والإعاشة.',
        'النقطة الطبية داخل المخيم، وهي مفتوحة على مدار الساعة.',
        'مشرف القطاع، لما لا يُحلّ في المخيم.',
        'غرفة العمليات المشتركة، للحالات الطارئة وحدها.',
        'مكتب المطوّف، لما يخصّ الحافلات والحقائب.',
    ]}),
    ('url', {
        'url': 'https://syrianhajj.org',
        'label': 'موقع بعثة الحج السورية',
    }),
    ('url', {
        'url': 'mailto:diwan@syrianhajj.org',
        'label': 'الديوان العام — للمراسلات الرسمية',
    }),
    # A code that carries a link.
    ('qr', {
        'value': 'https://syrianhajj.org',
        'label': 'امسح للوصول إلى الموقع ورقم الطوارئ',
    }),
    # And one that carries plain text rather than a link — drawn the same way,
    # scanned to something a phone will not try to open.
    ('qr', {
        'value': 'بعثة الحج السورية — غرفة العمليات: 0500000000',
        'label': 'رقم غرفة العمليات، للمسح دون إنترنت',
    }),
    ('note', {'text':
        'الشكاوى تُقدَّم عبر صندوق الشكاوى في الفندق أو النموذج الإلكتروني، '
        'وتُدرس جميعها — بما فيها ما يُقدَّم بعد العودة.'}),
    ('divider', {}),
    ('paragraph', {'text':
        'صدرت هذه التعليمات عن المكتب الإداري في بعثة الحج السورية، ويُعمل بها '
        'حتى صدور ما يعدّلها.'}),
]


def upload_source(report_id):
    """Put the real document in the private bucket, under the report's folder.

    The path convention the storage policy reads is {report_id}/{file}, so the
    folder IS the permission — anyone who may read the report may read what
    hangs off it.
    """
    if not os.path.exists(SOURCE):
        print(f'  (source document not found at {SOURCE} — skipping)')
        return None
    name = os.path.basename(SOURCE)
    # Storage refuses a key with non-ASCII in it, and almost every document
    # here is named in Arabic. Same rule as storageKey() in
    # lib/core/supabase/storage_key.dart: the KEY is stripped to what storage
    # accepts, and the real name is kept in the row beside it — which is what
    # gets shown and downloaded. The key is plumbing; nobody reads it.
    stem, dot, ext = name.rpartition('.')
    safe = re.sub(r'_+', '_',
                  re.sub(r'[^A-Za-z0-9._-]', '_', stem or name)).strip('_.-')
    if not safe:
        safe = 'document'
    key = f'{safe}.{ext}' if dot else safe
    path = f'{report_id}/{key}'
    body = open(SOURCE, 'rb').read()
    mime = (mimetypes.guess_type(name)[0]
            or 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')

    import urllib.error
    import urllib.request
    req = urllib.request.Request(
        # The bucket is part of the path: /object/{bucket}/{key}.
        f'{sbx.BASE}/storage/v1/object/reports/{quote(path)}',
        data=body,
        method='POST',
        headers={
            'apikey': sbx.KEY,
            'Authorization': f'Bearer {sbx.KEY}',
            'Content-Type': mime,
            'x-upsert': 'true',
        },
    )
    try:
        urllib.request.urlopen(req).read()
    except urllib.error.HTTPError as e:
        # Said out loud rather than swallowed: a report whose document silently
        # failed to upload looks exactly like one that never had a document.
        print(f'  upload failed: {e.code} {e.read().decode()[:200]}')
        return None
    return {'path': path, 'name': name, 'mime': mime, 'size': len(body)}


def main():
    types = {t['code']: t for t in sbx.select('report_types')}
    t = types.get('general')
    if t is None:
        raise SystemExit('the `general` report type is not there — run 0069')

    print(TITLE)
    print(f'  number: {NUMBER} | season: (none — general) | published')
    print(f'  header: subtitle, note, official document')
    print(f'  {len(BLOCKS)} blocks:')
    for kind, data in BLOCKS:
        summary = (
            data.get('text')
            or data.get('label')
            or (f"{len(data.get('items', []))} items" if data.get('items') else '')
            or (f"{len(data.get('columns', []))} cols × "
                f"{len(data.get('rows', []))} rows"
                if data.get('columns') else '—')
        )
        print(f'    {kind:11} {str(summary)[:56]}')

    if not APPLY:
        print('\nDRY RUN — nothing written. Re-run with --apply.')
        return

    for old in sbx.select(
        'reports',
        f"select=id&report_type_id=eq.{t['id']}&title=eq.{quote(TITLE)}",
    ):
        sbx.delete('reports', f"id=eq.{old['id']}")

    report = sbx.insert('reports', [{
        'report_type_id': t['id'],
        'season_id': None,
        'title': TITLE,
        'number': NUMBER,
        'data': {
            'subtitle': 'تُقرأ قبل التوجّه إلى المشاعر',
            'note': 'يُرجى من مشرفي الأبراج توزيعها على الحجاج قبل يوم التروية.',
        },
        'is_published': True,
    }])[0]

    sbx.insert('report_blocks', [
        {'report_id': report['id'], 'kind': kind, 'data': data, 'sort_order': i}
        for i, (kind, data) in enumerate(BLOCKS, 1)
    ])

    uploaded = upload_source(report['id'])
    if uploaded:
        # Both: the header FIELD points at it as the official document, and the
        # attachment row makes it downloadable through the shared widget. They
        # are two different affordances over one file.
        sbx.update('reports', f"id=eq.{report['id']}", {
            'data': {
                'subtitle': 'تُقرأ قبل التوجّه إلى المشاعر',
                'note': 'يُرجى من مشرفي الأبراج توزيعها على الحجاج قبل يوم التروية.',
                'official_pdf': {
                    'path': uploaded['path'],
                    'name': uploaded['name'],
                },
            },
        })
        sbx.insert('report_attachments', [{
            'report_id': report['id'],
            'kind': 'file',
            'path': uploaded['path'],
            'name': uploaded['name'],
            'mime_type': uploaded['mime'],
            'size_bytes': uploaded['size'],
            'sort_order': 1,
        }])
        print(f"  uploaded {uploaded['name']} ({uploaded['size']} bytes)")

    print(f"\npublished — {len(BLOCKS)} blocks")


if __name__ == '__main__':
    main()
