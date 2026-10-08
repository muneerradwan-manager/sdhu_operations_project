import '../../../core/l10n/localized_name.dart';

/// The Arabic (and English) the log speaks.
///
/// Table and column names are code, not content: they live in neither the ARB
/// files (they are not app chrome) nor the database (they ARE the database).
/// So the dictionary that turns `module_node_members.profile_id` into
/// "عضو قطاع — الموظف" lives here, beside the feature that reads it, as
/// [LocalizedName]s resolved against the active locale.
///
/// Unknown names fall back to themselves: a table added by a future migration
/// shows up raw rather than invisibly, which is the reminder to add its label.
class AuditLabels {
  const AuditLabels._();

  /// The filter's idea of a section: one label over the handful of tables the
  /// reader thinks of as one thing. Order is display order.
  static const groups = <AuditEntityGroup>[
    AuditEntityGroup(
      key: 'accounts',
      name: LocalizedName(ar: 'الحسابات والدخول', en: 'Accounts & sign-ins'),
      tables: ['auth'],
    ),
    AuditEntityGroup(
      key: 'employees',
      name: LocalizedName(ar: 'الموظفون', en: 'Employees'),
      tables: ['profiles', 'job_titles'],
    ),
    AuditEntityGroup(
      key: 'permissions',
      name: LocalizedName(ar: 'الصلاحيات', en: 'Permissions'),
      tables: ['user_permissions', 'permissions', 'permission_prerequisites'],
    ),
    AuditEntityGroup(
      key: 'seasons',
      name: LocalizedName(ar: 'المواسم', en: 'Seasons'),
      tables: ['seasons', 'season_participants'],
    ),
    AuditEntityGroup(
      key: 'modules',
      name: LocalizedName(ar: 'الملفات التشغيلية', en: 'Operational files'),
      tables: [
        'modules',
        'module_members',
        'module_nodes',
        'module_node_members',
        'module_assigned_tasks',
        'module_tasks',
        'module_task_status',
        'module_task_attachments',
        'module_ratings',
      ],
    ),
    AuditEntityGroup(
      key: 'module_reports',
      name: LocalizedName(ar: 'تقارير الملفات', en: 'File reports'),
      tables: ['module_reports', 'module_report_attachments'],
    ),
    // Standalone since 0105 — no relation to the operational files.
    //
    // Six tables, not the two this listed until now. 0117 and 0118 turned a
    // task from a value one party wrote into a THREAD — comments, events,
    // batches, steps — and every one of them takes the audit trigger in its own
    // migration. Naming only the first two here meant the log recorded the
    // whole conversation and the filter could reach none of it.
    AuditEntityGroup(
      key: 'personal_tasks',
      name: LocalizedName(ar: 'المهام', en: 'Tasks'),
      tables: [
        'personal_tasks',
        'personal_task_attachments',
        'personal_task_comments',
        'personal_task_events',
        'personal_task_batches',
        'personal_task_steps',
      ],
    ),
    // 0084. Audited since the day it was created and unreachable from this
    // filter for just as long — a whole section of the app with no section
    // here. The redacting trigger keeps the marks out of the log; what is
    // recorded is that a sheet was opened, assigned, filled or deleted, and
    // that is exactly what an office needs to be able to ask about.
    AuditEntityGroup(
      key: 'evaluations',
      name: LocalizedName(ar: 'التقييمات', en: 'Evaluations'),
      tables: [
        'evaluations',
        'evaluation_answers',
        'evaluation_templates',
        'evaluation_stages',
        'evaluation_questions',
        'evaluation_options',
      ],
    ),
    // 0098 + 0114 + 0122. The arrivals themselves went unlogged until 0122 —
    // see that migration for why an attendance register is the last thing that
    // should be quietly correctable.
    AuditEntityGroup(
      key: 'checkin',
      name: LocalizedName(ar: 'تسجيل الوصول', en: 'Check-in'),
      tables: ['place_check_ins', 'place_codes', 'place_code_policy'],
    ),
    // 0088, logged since 0121 — which also gave the register its delete.
    AuditEntityGroup(
      key: 'incidents',
      name: LocalizedName(ar: 'البلاغات العاجلة', en: 'Urgent reports'),
      tables: ['incidents', 'incident_attachments'],
    ),
    // 0129. Logged from the day the tables existed, and it matters more here
    // than in most places: half of "what was planned, what changed" — who moved
    // this man off that flight, and when — is answerable only from the log.
    AuditEntityGroup(
      key: 'travel',
      name: LocalizedName(ar: 'السفر والتنقّل', en: 'Travel'),
      tables: ['trips', 'journey_legs', 'journey_stays'],
    ),
    AuditEntityGroup(
      key: 'reference',
      name: LocalizedName(ar: 'البيانات المرجعية', en: 'Master data'),
      tables: [
        'reference_sets',
        'reference_set_fields',
        'reference_items',
        'module_types',
        'module_type_fields',
        'module_type_roles',
        'module_type_tasks',
        'module_type_levels',
        'module_type_task_groups',
        // 0115, and unlogged until 0122 — the only `module_type_*` table that
        // was not, which is what made it easy to miss.
        'module_type_teams',
      ],
    ),
    AuditEntityGroup(
      key: 'reports',
      name: LocalizedName(ar: 'القرارات', en: 'Decisions'),
      tables: [
        'reports',
        'report_types',
        'report_type_fields',
        'report_type_columns',
        'report_attachments',
        // 0086, unlogged until 0122. Not a decision but the record BEHIND one:
        // what the nightly pass decided was late, and how far up it carried it.
        // It belongs where a reader asking "why was my superior told" looks.
        'report_misses',
      ],
    ),
    AuditEntityGroup(
      key: 'notifications',
      name: LocalizedName(ar: 'الإشعارات', en: 'Notifications'),
      tables: ['notifications', 'notification_attachments'],
    ),
    AuditEntityGroup(
      key: 'complaints',
      name: LocalizedName(ar: 'الشكاوى', en: 'Complaints'),
      tables: ['complaints', 'complaint_replies', 'complaint_attachments'],
    ),
    AuditEntityGroup(
      key: 'storage',
      name: LocalizedName(ar: 'الملفات المرفوعة', en: 'Uploaded files'),
      tables: ['storage'],
    ),
  ];

  /// What one row of each table IS, in the singular the card's subtitle needs.
  static const _tables = <String, LocalizedName>{
    'auth': LocalizedName(ar: 'الحساب والدخول', en: 'Account & sign-in'),
    'profiles': LocalizedName(ar: 'موظف', en: 'Employee'),
    // The table the job descriptions lived in until 0085 moved them into the
    // catalog. Named here for the entries written while it existed.
    'job_titles': LocalizedName(ar: 'وصف وظيفي', en: 'Job description'),
    'permissions': LocalizedName(ar: 'تعريف صلاحية', en: 'Permission'),
    'user_permissions': LocalizedName(
      ar: 'صلاحية ممنوحة',
      en: 'Granted permission',
    ),
    'permission_prerequisites': LocalizedName(
      ar: 'متطلب صلاحية',
      en: 'Permission prerequisite',
    ),
    'seasons': LocalizedName(ar: 'موسم', en: 'Season'),
    'season_participants': LocalizedName(
      ar: 'مشارك في الموسم',
      en: 'Season participant',
    ),
    'modules': LocalizedName(ar: 'ملف تشغيلي', en: 'Operational file'),
    'module_members': LocalizedName(ar: 'عضو ملف', en: 'File member'),
    'module_nodes': LocalizedName(
      ar: 'عنصر في شجرة الملف',
      en: 'File tree item',
    ),
    'module_node_members': LocalizedName(
      ar: 'إسناد على قطاع',
      en: 'Sector assignment',
    ),
    'module_assigned_tasks': LocalizedName(
      ar: 'مهمة مسندة',
      en: 'Assigned task',
    ),
    'module_tasks': LocalizedName(ar: 'مهمة ملف', en: 'File duty'),
    'module_task_status': LocalizedName(
      ar: 'حالة مهمة',
      en: 'Duty state',
    ),
    'module_task_attachments': LocalizedName(
      ar: 'مرفق مهمة',
      en: 'Duty attachment',
    ),
    'module_ratings': LocalizedName(ar: 'تقييم', en: 'Rating'),
    'personal_tasks': LocalizedName(ar: 'مهمة', en: 'Task'),
    'personal_task_attachments': LocalizedName(
      ar: 'مرفق مهمة',
      en: 'Task attachment',
    ),
    'personal_task_comments': LocalizedName(
      ar: 'تعليق على مهمة',
      en: 'Task comment',
    ),
    'personal_task_events': LocalizedName(ar: 'حركة مهمة', en: 'Task event'),
    'personal_task_batches': LocalizedName(ar: 'دفعة مهام', en: 'Task batch'),
    'personal_task_steps': LocalizedName(ar: 'خطوة مهمة', en: 'Task step'),
    'evaluations': LocalizedName(ar: 'ورقة تقييم', en: 'Evaluation sheet'),
    'evaluation_answers': LocalizedName(ar: 'إجابة تقييم', en: 'Evaluation answer'),
    'evaluation_templates': LocalizedName(
      ar: 'نموذج تقييم',
      en: 'Evaluation form',
    ),
    'evaluation_stages': LocalizedName(
      ar: 'مرحلة تقييم',
      en: 'Evaluation stage',
    ),
    'evaluation_questions': LocalizedName(ar: 'سؤال تقييم', en: 'Evaluation question'),
    'evaluation_options': LocalizedName(ar: 'خيار إجابة', en: 'Answer option'),
    'place_check_ins': LocalizedName(ar: 'تسجيل وصول', en: 'Check-in'),
    'place_codes': LocalizedName(ar: 'رمز مكان', en: 'Place code'),
    'place_code_policy': LocalizedName(
      ar: 'سياسة رموز الأماكن',
      en: 'Place code policy',
    ),
    'incidents': LocalizedName(ar: 'بلاغ عاجل', en: 'Urgent report'),
    'incident_attachments': LocalizedName(
      ar: 'مرفق بلاغ',
      en: 'Report attachment',
    ),
    'report_misses': LocalizedName(ar: 'تقرير متأخر', en: 'Late report'),
    'trips': LocalizedName(ar: 'رحلة', en: 'Trip'),
    'journey_legs': LocalizedName(ar: 'حركة تنقّل', en: 'Movement'),
    'journey_stays': LocalizedName(ar: 'إقامة', en: 'Stay'),
    'module_type_teams': LocalizedName(ar: 'فريق نوع ملف', en: 'File type team'),
    'module_reports': LocalizedName(ar: 'تقرير ملف', en: 'File report'),
    'module_report_attachments': LocalizedName(
      ar: 'مرفق تقرير ملف',
      en: 'File report attachment',
    ),
    'reference_sets': LocalizedName(
      ar: 'مجموعة بيانات مرجعية',
      en: 'Master data set',
    ),
    'reference_set_fields': LocalizedName(
      ar: 'حقل بيانات مرجعية',
      en: 'Master data field',
    ),
    'reference_items': LocalizedName(
      ar: 'عنصر بيانات مرجعية',
      en: 'Master data item',
    ),
    'module_types': LocalizedName(ar: 'نوع ملف تشغيلي', en: 'File type'),
    'module_type_fields': LocalizedName(
      ar: 'حقل نوع ملف',
      en: 'File type field',
    ),
    'module_type_roles': LocalizedName(ar: 'دور نوع ملف', en: 'File type role'),
    'module_type_tasks': LocalizedName(ar: 'مهمة دور', en: 'Role task'),
    'module_type_levels': LocalizedName(
      ar: 'مستوى نوع ملف',
      en: 'File type level',
    ),
    'module_type_task_groups': LocalizedName(
      ar: 'مجموعة مهام',
      en: 'Task group',
    ),
    'reports': LocalizedName(ar: 'قرار', en: 'Decision'),
    'report_types': LocalizedName(ar: 'نوع قرار', en: 'Decision type'),
    'report_type_fields': LocalizedName(
      ar: 'حقل نوع قرار',
      en: 'Decision type field',
    ),
    'report_type_columns': LocalizedName(
      ar: 'عمود نوع قرار',
      en: 'Decision type column',
    ),
    'report_attachments': LocalizedName(ar: 'مرفق قرار', en: 'Decision attachment'),
    'notifications': LocalizedName(ar: 'إشعار', en: 'Notification'),
    'notification_attachments': LocalizedName(
      ar: 'مرفق إشعار',
      en: 'Notification attachment',
    ),
    'complaints': LocalizedName(ar: 'شكوى', en: 'Complaint'),
    'complaint_replies': LocalizedName(ar: 'ردّ على شكوى', en: 'Complaint reply'),
    'complaint_attachments': LocalizedName(
      ar: 'مرفق شكوى',
      en: 'Complaint attachment',
    ),
    'storage': LocalizedName(ar: 'ملف مرفوع', en: 'Uploaded file'),
  };

  /// The account acts the Edge Functions and the auth RPC file under `auth`.
  static const _authOps = <String, LocalizedName>{
    'create_user': LocalizedName(ar: 'إنشاء حساب', en: 'Account created'),
    'delete_user': LocalizedName(ar: 'حذف حساب', en: 'Account deleted'),
    'set_password': LocalizedName(
      ar: 'إعادة تعيين كلمة المرور',
      en: 'Password reset',
    ),
    'set_email': LocalizedName(
      ar: 'تغيير البريد الإلكتروني',
      en: 'Email changed',
    ),
  };

  /// Column labels, shared across tables: `name_ar` means the same thing on a
  /// module type as on a master-data item, so one dictionary serves them all.
  static const _fields = <String, LocalizedName>{
    // People
    'first_name': LocalizedName(ar: 'الاسم الأول', en: 'First name'),
    'father_name': LocalizedName(ar: 'اسم الأب', en: "Father's name"),
    'surname': LocalizedName(ar: 'الكنية', en: 'Surname'),
    'gender': LocalizedName(ar: 'الجنس', en: 'Gender'),
    // `mission_type` was the enum column, dropped in 0085. Kept because the log
    // is a record of what happened, and entries older than that name it.
    'mission_type': LocalizedName(ar: 'نوع البعثة', en: 'Mission'),
    'mission_type_id': LocalizedName(ar: 'نوع البعثة', en: 'Mission'),
    'job_title_id': LocalizedName(ar: 'الوصف الوظيفي', en: 'Job description'),
    'phone_sy': LocalizedName(ar: 'هاتف سوريا', en: 'Syrian phone'),
    'phone_sa': LocalizedName(ar: 'هاتف السعودية', en: 'Saudi phone'),
    'date_of_birth': LocalizedName(ar: 'تاريخ الميلاد', en: 'Date of birth'),
    'photo_url': LocalizedName(ar: 'الصورة الشخصية', en: 'Photo'),
    'email': LocalizedName(ar: 'البريد الإلكتروني', en: 'Email'),
    'city_id': LocalizedName(ar: 'المدينة', en: 'City'),
    'account_status': LocalizedName(ar: 'حالة الحساب', en: 'Account status'),
    'rejection_reason': LocalizedName(ar: 'سبب الرفض', en: 'Rejection reason'),
    'is_suspended': LocalizedName(ar: 'موقوف', en: 'Suspended'),
    'auto_suspended_at': LocalizedName(
      ar: 'وقت الإيقاف التلقائي',
      en: 'Auto-suspended at',
    ),
    'auto_suspend_forgiven_count': LocalizedName(
      ar: 'الشكاوى المسامَح بها',
      en: 'Forgiven complainants',
    ),
    'is_admin': LocalizedName(ar: 'مدير النظام', en: 'Administrator'),
    'is_external': LocalizedName(ar: 'من جهة خارجية', en: 'External'),
    'external_organization': LocalizedName(
      ar: 'الجهة الخارجية',
      en: 'Organization',
    ),
    // Dropped from profiles in 0138 — الوصف الوظيفي was already the man's post
    // at his own ministry. Kept here because the log rows that recorded it are
    // still on the shelf, and a history that renders a raw column name is a
    // history nobody reads.
    'external_title': LocalizedName(ar: 'الصفة الخارجية', en: 'External title'),
    // Naming
    'name': LocalizedName(ar: 'الاسم', en: 'Name'),
    'name_ar': LocalizedName(ar: 'الاسم بالعربية', en: 'Arabic name'),
    'name_en': LocalizedName(ar: 'الاسم بالإنكليزية', en: 'English name'),
    'title': LocalizedName(ar: 'العنوان', en: 'Title'),
    'body': LocalizedName(ar: 'النص', en: 'Body'),
    'label': LocalizedName(ar: 'التسمية', en: 'Label'),
    'code': LocalizedName(ar: 'الرمز', en: 'Code'),
    'description': LocalizedName(ar: 'الوصف', en: 'Description'),
    'number': LocalizedName(ar: 'الرقم', en: 'Number'),
    // Structure
    'sort_order': LocalizedName(ar: 'الترتيب', en: 'Order'),
    'is_active': LocalizedName(ar: 'مفعّل', en: 'Active'),
    'is_current': LocalizedName(ar: 'الموسم الحالي', en: 'Current season'),
    'is_published': LocalizedName(ar: 'منشور', en: 'Published'),
    'hijri_year': LocalizedName(ar: 'السنة الهجرية', en: 'Hijri year'),
    'gregorian_label': LocalizedName(
      ar: 'التسمية الميلادية',
      en: 'Gregorian label',
    ),
    'starts_on': LocalizedName(ar: 'تاريخ البداية', en: 'Starts on'),
    'ends_on': LocalizedName(ar: 'تاريخ النهاية', en: 'Ends on'),
    'period_start': LocalizedName(ar: 'بداية الفترة', en: 'Period start'),
    'period_end': LocalizedName(ar: 'نهاية الفترة', en: 'Period end'),
    'decision': LocalizedName(ar: 'القرار', en: 'Decision'),
    'capacity': LocalizedName(ar: 'السعة', en: 'Capacity'),
    'status': LocalizedName(ar: 'الحالة', en: 'Status'),
    'kind': LocalizedName(ar: 'النوع', en: 'Kind'),
    'data': LocalizedName(ar: 'البيانات', en: 'Data'),
    'content': LocalizedName(ar: 'المحتوى', en: 'Content'),
    'stars': LocalizedName(ar: 'النجوم', en: 'Stars'),
    // Relations
    'season_id': LocalizedName(ar: 'الموسم', en: 'Season'),
    'module_id': LocalizedName(ar: 'الملف التشغيلي', en: 'File'),
    'module_type_id': LocalizedName(ar: 'نوع الملف', en: 'File type'),
    'profile_id': LocalizedName(ar: 'الموظف', en: 'Employee'),
    'user_id': LocalizedName(ar: 'الموظف', en: 'Employee'),
    'permission_id': LocalizedName(ar: 'الصلاحية', en: 'Permission'),
    'requires_id': LocalizedName(ar: 'تتطلب', en: 'Requires'),
    'granted_by': LocalizedName(ar: 'مُنحت من', en: 'Granted by'),
    'assigned_by': LocalizedName(ar: 'أُسندت من', en: 'Assigned by'),
    'node_id': LocalizedName(ar: 'القطاع/العنصر', en: 'Node'),
    'role_id': LocalizedName(ar: 'الدور', en: 'Role'),
    'housing_item_id': LocalizedName(ar: 'السكن', en: 'Housing'),
    'task_id': LocalizedName(ar: 'المهمة', en: 'Task'),
    'type_task_id': LocalizedName(ar: 'مهمة من الكتالوج', en: 'Catalog duty'),
    'module_task_id': LocalizedName(ar: 'مهمة الملف', en: 'File duty'),
    'status_id': LocalizedName(ar: 'حالة المهمة', en: 'Duty state'),
    'scope': LocalizedName(ar: 'النطاق', en: 'Scope'),
    'state': LocalizedName(ar: 'الحالة', en: 'State'),
    'note': LocalizedName(ar: 'ملاحظة', en: 'Note'),
    'due_on': LocalizedName(ar: 'تاريخ الاستحقاق', en: 'Due on'),
    'updated_by': LocalizedName(ar: 'حدّثها', en: 'Updated by'),
    'title_ar': LocalizedName(ar: 'العنوان بالعربية', en: 'Arabic title'),
    'title_en': LocalizedName(ar: 'العنوان بالإنكليزية', en: 'English title'),
    'description_ar': LocalizedName(ar: 'الوصف بالعربية', en: 'Arabic description'),
    'description_en': LocalizedName(
      ar: 'الوصف بالإنكليزية',
      en: 'English description',
    ),
    'level_id': LocalizedName(ar: 'المستوى', en: 'Level'),
    'parent_id': LocalizedName(ar: 'العنصر الأب', en: 'Parent'),
    'set_id': LocalizedName(ar: 'المجموعة', en: 'Set'),
    'reference_set_id': LocalizedName(
      ar: 'المجموعة المرجعية',
      en: 'Reference set',
    ),
    'report_id': LocalizedName(ar: 'التقرير', en: 'Report'),
    'report_type_id': LocalizedName(ar: 'نوع التقرير', en: 'Report type'),
    'author_id': LocalizedName(ar: 'الكاتب', en: 'Author'),
    'created_by': LocalizedName(ar: 'أُنشئ من', en: 'Created by'),
    'rater_id': LocalizedName(ar: 'المُقيِّم', en: 'Rater'),
    'ratee_id': LocalizedName(ar: 'المُقيَّم', en: 'Rated'),
    'recipient_id': LocalizedName(ar: 'المستلم', en: 'Recipient'),
    'sender_id': LocalizedName(ar: 'المرسل', en: 'Sender'),
    'group_id': LocalizedName(ar: 'المجموعة', en: 'Group'),
    // Complaints. `complainant_id`, `author_id` and `body` are absent on
    // purpose: the trigger in 0079 strips them before the row is written, so a
    // label for them would be a label for something the log never carries.
    'complaint_id': LocalizedName(ar: 'الشكوى', en: 'Complaint'),
    'reply_id': LocalizedName(ar: 'الردّ', en: 'Reply'),
    'target_type': LocalizedName(ar: 'نوع المشتكى عليه', en: 'Target kind'),
    'target_label': LocalizedName(ar: 'المشتكى عليه', en: 'Target'),
    'target_profile_id': LocalizedName(ar: 'الموظف المشتكى عليه', en: 'Employee'),
    'target_module_id': LocalizedName(ar: 'الملف المشتكى عليه', en: 'File'),
    'target_report_id': LocalizedName(ar: 'التقرير المشتكى عليه', en: 'Report'),
    'target_item_id': LocalizedName(ar: 'العنصر المشتكى عليه', en: 'Item'),
    'locked_at': LocalizedName(ar: 'وقت إغلاق الردود', en: 'Locked at'),
    'locked_by': LocalizedName(ar: 'أغلق الردود', en: 'Locked by'),
    'dismissed_at': LocalizedName(ar: 'وقت الرفض', en: 'Dismissed at'),
    'dismissed_by': LocalizedName(ar: 'رفضها', en: 'Dismissed by'),
    'dismiss_reason': LocalizedName(ar: 'سبب الرفض', en: 'Dismiss reason'),
    'allows_multiple': LocalizedName(
      ar: 'يسمح بأكثر من شخص',
      en: 'Allows multiple',
    ),
    // Files
    'path': LocalizedName(ar: 'المسار', en: 'Path'),
    'bucket': LocalizedName(ar: 'الحاوية', en: 'Bucket'),
    'mime_type': LocalizedName(ar: 'نوع الملف', en: 'File type'),
    'size_bytes': LocalizedName(ar: 'الحجم (بايت)', en: 'Size (bytes)'),
    'recipients': LocalizedName(ar: 'عدد المستلمين', en: 'Recipients'),
    // Bookkeeping
    'created_at': LocalizedName(ar: 'تاريخ الإنشاء', en: 'Created at'),
    'updated_at': LocalizedName(ar: 'آخر تحديث', en: 'Updated at'),
    'read_at': LocalizedName(ar: 'وقت القراءة', en: 'Read at'),
    'is_season_scoped': LocalizedName(
      ar: 'مرتبطة بالموسم',
      en: 'Season scoped',
    ),
    'pinned_for_hijri_year': LocalizedName(
      ar: 'مثبّت لسنة هجرية',
      en: 'Pinned for Hijri year',
    ),
    'op': LocalizedName(ar: 'العملية', en: 'Operation'),
  };

  static LocalizedName table(String name) =>
      _tables[name] ?? LocalizedName(ar: name);

  static LocalizedName field(String name) =>
      _fields[name] ?? LocalizedName(ar: name);

  static LocalizedName? authOp(String? op) => op == null ? null : _authOps[op];
}

/// One entry of the entity filter: a label and the tables it stands for.
class AuditEntityGroup {
  const AuditEntityGroup({
    required this.key,
    required this.name,
    required this.tables,
  });

  final String key;
  final LocalizedName name;
  final List<String> tables;
}
