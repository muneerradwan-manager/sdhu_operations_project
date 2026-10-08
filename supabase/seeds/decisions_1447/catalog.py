# -*- coding: utf-8 -*-
"""Catalog changes the official decisions force, all of them data.

Three things the decisions say that the catalog did not yet:

  * a برج houses MORE THAN ONE تكتل — 'القصواء/الإجابة', and
    'الضياء/ارتقاء/البراق'. 0051 tied a tower to one cluster and made it unique,
    which cannot hold four of the twenty towers in 3142. The تكتل becomes a rung
    of the tree below the برج instead: several fit under one tower, each still
    appears once in the file, and the editor already draws whatever depth a type
    declares. No new table, and no column that means 'the first of them'.

  * a مخيم carries رقم الخيمة — 3172 writes 'رقم المخيم: 16 / رقم الخيمة: 154'
    and never writes a الطاقة الاستيعابية, which the catalog demanded. So the
    tent number is added and the capacity stops being required: a file cannot be
    entered at all against a required field the source document does not have.

  * مخيم 16 allots space to BODIES — 'الإدارة الصحية', 'أعضاء اللجنة الاعتبارية'
    — beside its named members. They are real allocations and not people, so
    they sit on the camp rather than being invented as accounts.

And one file the catalog had no type for at all: لجنة دراسة الخدمات المقدمة
لحجاج مستوى 5 نجوم (3197).
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sbx


def ensure_cluster_level():
    """التكتل, as a rung under البرج."""
    t = sbx.select('module_types', 'select=id&code=eq.makkah_sectors_towers')[0]
    sets = {s['code']: s['id'] for s in sbx.select('reference_sets', 'select=id,code')}
    levels = sbx.select('module_type_levels',
                        f"select=*&module_type_id=eq.{t['id']}")
    have = {l['code']: l for l in levels}
    if 'cluster' not in have:
        sbx.insert('module_type_levels', [{
            'module_type_id': t['id'], 'code': 'cluster',
            'name_ar': 'التكتل', 'name_en': 'Cluster',
            'depth': 3, 'reference_set_id': sets['clusters'],
        }])
        print('  + level: التكتل (depth 3)')
    # The tower no longer names a cluster of its own.
    tower = have.get('tower')
    if tower and tower.get('secondary_reference_set_id'):
        sbx.update('module_type_levels', f"id=eq.{tower['id']}",
                   {'secondary_reference_set_id': None})
        print('  ~ tower level no longer ties to a single cluster')


def ensure_camp_fields():
    """رقم الخيمة on a camp, the bodies allotted to it, capacity optional."""
    for code in ('arafat_camp_assignment', 'mina_camp_assignment'):
        t = sbx.select('module_types', f'select=id&code=eq.{code}')
        if not t:
            continue
        t = t[0]
        lv = sbx.select('module_type_levels',
                        f"select=id,code&module_type_id=eq.{t['id']}")
        camp = next((l for l in lv if l['code'] == 'camp'), None)
        if not camp:
            continue
        fields = sbx.select('module_type_fields',
                            f"select=*&module_type_id=eq.{t['id']}")
        have = {f['key']: f for f in fields if f.get('level_id') == camp['id']}

        cap = have.get('capacity')
        if cap and cap['is_required']:
            sbx.update('module_type_fields', f"id=eq.{cap['id']}",
                       {'is_required': False})
            print(f'  ~ {code}: capacity no longer required')

        add = []
        if 'tents' not in have:
            add.append({'module_type_id': t['id'], 'level_id': camp['id'],
                        'key': 'tents', 'label_ar': 'رقم الخيمة',
                        'label_en': 'Tent number', 'kind': 'text',
                        'is_required': False, 'sort_order': 1})
        if 'bodies' not in have:
            add.append({'module_type_id': t['id'], 'level_id': camp['id'],
                        'key': 'bodies', 'label_ar': 'جهات مخصّصة',
                        'label_en': 'Allotted bodies', 'kind': 'textarea',
                        'is_required': False, 'sort_order': 4})
        if add:
            sbx.insert('module_type_fields', add)
            print(f'  + {code}: {", ".join(f["key"] for f in add)}')


def ensure_madinah_departures():
    """فريق متابعة ترحيل وسفر الحجاج، ومحاسب المكتب — 3190.

    A further team of the office 3179 already formed, and its accountant. It is
    signed by that office's own director and staffed from the same people, so it
    belongs in the Madinah file rather than opening a second one for the same
    office in the same season.

    Unlike every other role in this type, these two carry duties: 3190 writes
    them out (0057 seeded none because 3179 wrote none). So they take the menu
    the rest of the catalog uses, and the other roles are left alone.
    """
    t = sbx.select('module_types', 'select=id&code=eq.madinah_admin_office')
    if not t:
        return
    tid = t[0]['id']
    have = {r['code'] for r in sbx.select(
        'module_type_roles', f'select=code&module_type_id=eq.{tid}')}
    add = [
        ('departures_supervisor', 'مشرف فريق متابعة ترحيل وسفر الحجاج',
         'Departures follow-up supervisor',
         'يقود متابعة ترحيل الحجاج من المدينة المنورة وسفرهم، ويوزّع المهام على '
         'الفريق ويرفع تقاريره إلى إدارة المكتب.',
         'Leads the follow-up of pilgrim departures from Madinah, hands the '
         'duties out and files the team\'s reports.', False, 11),
        ('departures_member', 'عضو فريق متابعة ترحيل وسفر الحجاج',
         'Departures follow-up member',
         'يتولى ما يُسند إليه من متابعة الترحيل ميدانياً، في الفنادق ومقار '
         'السكن وبالتنسيق مع فريق المطار.',
         'Carries whatever departure duties are handed to him, on the ground '
         'and with the airport team.', True, 12),
        ('accountant', 'محاسب المكتب الإداري',
         'Office accountant',
         'يتولى محاسبة المكتب الإداري في المدينة المنورة.',
         'Keeps the accounts of the Madinah administrative office.', False, 13),
    ]
    rows = [{'module_type_id': tid, 'code': c, 'name_ar': ar, 'name_en': en,
             'description_ar': dar, 'description_en': den,
             'allows_multiple': multi, 'is_required': False,
             # The accountant has no duty list of his own in the decision.
             'tasks_are_assigned': c != 'accountant', 'sort_order': so}
            for c, ar, en, dar, den, multi, so in add if c not in have]
    if rows:
        sbx.insert('module_type_roles', rows)
        print('  + madinah:', ', '.join(r['code'] for r in rows))

    groups = {g['code']: g for g in sbx.select(
        'module_type_task_groups', f'select=*&module_type_id=eq.{tid}')}
    if 'departures' not in groups:
        grp = sbx.insert('module_type_task_groups', [{
            'module_type_id': tid, 'code': 'departures',
            'name_ar': 'متابعة ترحيل وسفر الحجاج',
            'name_en': 'Departures follow-up', 'sort_order': 1,
        }])[0]
        sbx.insert('module_type_tasks', [
            {'module_type_id': tid, 'group_id': grp['id'], 'sort_order': i,
             'title_ar': ar, 'title_en': en}
            for i, (ar, en) in enumerate([
                ('متابعة عملية ترحيل الحجاج من المدينة، والتنسيق المستمر مع '
                 'فريق مكتب الخدمة الميدانية',
                 'Follow the departure of the pilgrims from Madinah, in constant '
                 'coordination with the field service office team'),
                ('التواجد المباشر والإشراف الميداني على عمليات ترحيل الحجاج من '
                 'الفنادق ومقار سكنهم في المدينة المنورة',
                 'Be present for and supervise the departures from the hotels '
                 'and residences in Madinah'),
                ('رفع إشعار الترحيل الفوري إلى فريق المطار فور مغادرة الحجاج '
                 'للفندق، مع استمرار التواصل والتنسيق معهم لضمان سلاسة الاستقبال',
                 'Notify the airport team the moment a group leaves its hotel, '
                 'and stay in contact so the reception runs smoothly'),
                ('إعداد وإرسال تقارير يومية مفصلة ترفع للإدارة مباشرة توضّح مسار '
                 'عمليات الترحيل وأي تحديات يتم رصدها',
                 'File a detailed daily report to the administration on how the '
                 'departures are going and anything that got in the way'),
            ], start=1)
        ])
        print('  + madinah: 4 departure duties')

    # The type's own description enumerates its teams, so it has to learn them.
    row = sbx.select('module_types',
                     'select=description_ar&code=eq.madinah_admin_office')[0]
    if 'ترحيل' not in (row.get('description_ar') or ''):
        sbx.update('module_types', 'code=eq.madinah_admin_office', {
            'description_ar':
                'تشكيل الفرق واللجان العاملة في بعثة الحج السورية ضمن المكتب '
                'الإداري في المدينة المنورة: تسكين الحجاج، وشركات الخدمة '
                'بأدلائها، والمطار، والطيران المركزي، وشحن الحقائب ومتابعتها، '
                'ومتابعة ترحيل وسفر الحجاج، ومنسق عمل المكتب، ومنسق سفر '
                'البعثات والإداريين والفرادى، ومحاسب المكتب.',
            'description_en':
                'The teams and committees of the Syrian Hajj Mission inside the '
                'Madinah administrative office: housing the pilgrims, the '
                'service companies and their guides, the airport, central '
                'aviation, baggage forwarding, the follow-up of pilgrim '
                'departures, the office coordinator, the coordinator for the '
                'travel of missions, administrators and individuals, and the '
                'office accountant.',
        })
        print('  ~ madinah: description now names the departures team')


FIVE_STAR = 'five_star_services_review'


def ensure_mina_two_supervisors():
    """منى runs مركز 10 and مركز 12 together, under two مشرفين.

    3173 heads that table 'مشرفو المراكز: المقداد مهلهل / صبحي مصطفى اصطيف' —
    plural, and two men. The role allowed one, which would have meant dropping
    a supervisor named in the decision.
    """
    t = sbx.select('module_types', 'select=id&code=eq.mina_camp_assignment')
    if not t:
        return
    r = sbx.select('module_type_roles',
                   f"select=id,allows_multiple&module_type_id=eq.{t[0]['id']}"
                   '&code=eq.center_supervisor')
    if r and not r[0]['allows_multiple']:
        sbx.update('module_type_roles', f"id=eq.{r[0]['id']}",
                   {'allows_multiple': True})
        print('  ~ mina: a مركز may carry more than one مشرف')


def ensure_five_star_type():
    """لجنة دراسة الخدمات المقدمة لحجاج مستوى 5 نجوم — 3197.

    A committee, not an office: a رئيس and its أعضاء, held once for the file,
    with the two duties the decision itself states. It runs fifteen days from
    the date it was issued rather than to an event, which is why its end
    condition says so plainly.
    """
    got = sbx.select('module_types', f'select=id&code=eq.{FIVE_STAR}')
    if got:
        return got[0]['id']
    t = sbx.insert('module_types', [{
        'code': FIVE_STAR,
        'name_ar': 'لجنة دراسة الخدمات المقدمة لحجاج مستوى (5 نجوم)',
        'name_en': 'Five-star pilgrim services review committee',
        'description_ar':
            'لجنة تدرس الخدمات المقدَّمة لحجاج مستوى (5 نجوم) وتتحقق من مطابقتها '
            'للعقود المبرمة، وتقدّر قيمة ما لم يُستلم من خدمات تمهيداً لاقتراح '
            'التعويض المالي للحجاج المتضررين.',
        'description_en':
            'Studies the services delivered to five-star pilgrims against the '
            'signed contracts, and prices what was not delivered so that '
            'compensation can be proposed for the pilgrims affected.',
        'start_condition_ar': 'يبدأ عمل اللجنة من تاريخ صدور القرار',
        'start_condition_en': 'Begins on the date the decision was issued',
        'end_condition_ar':
            'ينتهي العمل بعد خمسة عشر يوماً برفع التقرير الختامي والتوصيات إلى '
            'إدارة الحج والعمرة',
        'end_condition_en':
            'Ends after fifteen days, when the final report and recommendations '
            'reach the Hajj and Umrah Administration',
        'sort_order': 15,
    }])[0]
    sbx.insert('module_type_fields', [{
        'module_type_id': t['id'], 'key': 'official_pdf',
        'label_ar': 'الملف الرسمي (PDF)', 'label_en': 'Official PDF',
        'kind': 'pdf', 'is_required': False, 'sort_order': 1,
    }])
    # Duties belong to the FILE and are handed out per member (the shape every
    # type has carried since 0028), so both roles take their share from one menu.
    sbx.insert('module_type_roles', [
        {'module_type_id': t['id'], 'code': 'chair', 'name_ar': 'رئيس اللجنة',
         'name_en': 'Committee chair', 'allows_multiple': False,
         'is_required': True, 'tasks_are_assigned': True, 'sort_order': 1,
         'description_ar': 'يرأس اللجنة ويوجّه عملها ويرفع تقريرها الختامي '
                           'والتوصيات إلى إدارة الحج والعمرة.',
         'description_en': 'Chairs the committee and files its closing report '
                           'and recommendations.'},
        {'module_type_id': t['id'], 'code': 'member', 'name_ar': 'عضو',
         'name_en': 'Member', 'allows_multiple': True,
         'is_required': False, 'tasks_are_assigned': True, 'sort_order': 2,
         'description_ar': 'يشارك في الدراسة الميدانية والمالية للخدمات '
                           'المقدَّمة ويوثّق ما يرصده من قصور.',
         'description_en': 'Takes part in the field and financial study and '
                           'documents what falls short.'},
    ])
    grp = sbx.insert('module_type_task_groups', [{
        'module_type_id': t['id'], 'code': 'duties',
        'name_ar': 'مهام اللجنة', 'name_en': 'Committee duties', 'sort_order': 1,
    }])[0]
    # The three duties of المادة (2), plus the report المادة (3) asks for.
    sbx.insert('module_type_tasks', [
        {'module_type_id': t['id'], 'group_id': grp['id'], 'sort_order': i,
         'title_ar': ar, 'title_en': en}
        for i, (ar, en) in enumerate([
            ('دراسة ومتابعة كفاية الخدمات المقدَّمة للحجاج والتحقق من مطابقتها '
             'للمواصفات والعقود المبرمة',
             'Study the services delivered to the pilgrims and check them '
             'against the specifications and the signed contracts'),
            ('تقييم جودة الخدمات المقدَّمة على أرض الواقع مقابل المبالغ المالية '
             'الإجمالية المدفوعة من الحجاج، وتحديد أي قصور أو خلل في التنفيذ',
             'Assess the quality actually delivered against the total paid by '
             'the pilgrims, and identify any shortfall in delivery'),
            ('إعداد دراسة مالية دقيقة ومستفيضة لتحديد قيمة التعويض المقترح '
             'للحجاج المتضررين بناءً على فارق الجودة والخدمات غير المستلمة',
             'Produce a detailed financial study setting the compensation to be '
             'proposed for the pilgrims affected'),
            ('إرسال التقرير الختامي والتوصيات ذات الصلة إلى إدارة الحج والعمرة',
             'Send the closing report and its recommendations to the Hajj and '
             'Umrah Administration'),
        ], start=1)
    ])
    print('  + module type:', FIVE_STAR)
    return t['id']


def ensure_employee_permissions():
    """employees.edit and employees.delete.

    The section had view / create / suspend / external / documents: a record
    could be opened, made and frozen, but never corrected or removed. Both are
    children of `employees`, so an admin granting the section still grants each
    action deliberately.
    """
    perms = {p['code']: p for p in sbx.select('permissions')}
    parent = perms.get('employees')
    if not parent:
        return
    add = []
    if 'employees.edit' not in perms:
        add.append({'code': 'employees.edit', 'description': 'Edit employee records',
                    'parent_id': parent['id'], 'sort_order': 6})
    if 'employees.delete' not in perms:
        add.append({'code': 'employees.delete', 'description': 'Delete employee records',
                    'parent_id': parent['id'], 'sort_order': 7})
    if add:
        sbx.insert('permissions', add)
        print('  + permissions:', ', '.join(p['code'] for p in add))


def main():
    print('catalog changes:')
    ensure_cluster_level()
    ensure_camp_fields()
    ensure_mina_two_supervisors()
    ensure_madinah_departures()
    ensure_five_star_type()
    ensure_employee_permissions()
    print('done.')


if __name__ == '__main__':
    main()
