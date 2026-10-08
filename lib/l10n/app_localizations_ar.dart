// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'إدارة الحج والعمرة';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonSubmit => 'إرسال';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonConnectionErrorTitle => 'تعذّر الاتصال بالخادم';

  @override
  String get commonConnectionErrorBody =>
      'تحقق من اتصالك بالإنترنت وحاول مجدداً.';

  @override
  String get commonGenericError => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get commonLogout => 'تسجيل الخروج';

  @override
  String get commonLoggingOut => 'جارٍ تسجيل الخروج…';

  @override
  String get commonRequired => 'مطلوب';

  @override
  String get commonLoading => 'جارٍ التحميل…';

  @override
  String get commonOptional => 'اختياري';

  @override
  String get commonNext => 'التالي';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonDone => 'إنهاء';

  @override
  String get commonCopied => 'تم النسخ';

  @override
  String get profileEmail => 'البريد الإلكتروني';

  @override
  String get commonMore => 'المزيد';

  @override
  String get moduleNotifyMembers => 'إشعار جميع أعضاء الملف';

  @override
  String get employeeNotify => 'إرسال إشعار';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get commonSettings => 'الإعدادات';

  @override
  String get commonToday => 'اليوم';

  @override
  String get commonYesterday => 'أمس';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageSystem => 'حسب النظام';

  @override
  String get settingsNotifications => 'إشعارات هذا الجهاز';

  @override
  String get settingsNotificationsHint =>
      'إيقافها يوقف تنبيه الجهاز فقط — الإشعارات تبقى تصلك داخل التطبيق';

  @override
  String get settingsLogoutConfirm =>
      'تسجيل الخروج من هذا الجهاز؟ سيُزال الحساب من قائمة التبديل السريع، وستحتاج كلمة المرور للدخول به مرة أخرى.';

  @override
  String get settingsSolidSurfaces => 'أسطح معتمة';

  @override
  String get settingsSolidSurfacesHint =>
      'بلا شفافية ولا ضبابية — أوضح تحت الشمس، وأخفّ على الأجهزة البطيئة';

  @override
  String get settingsTheme => 'المظهر';

  @override
  String get settingsGroupDevice => 'هذا الجهاز';

  @override
  String get settingsSwitchAccount => 'التبديل إلى حساب آخر';

  @override
  String get themeSystem => 'حسب النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get authLoginTitle => 'مرحباً بعودتك';

  @override
  String get authLoginSubtitle => 'سجّل الدخول للمتابعة';

  @override
  String get authRegisterTitle => 'إنشاء حساب';

  @override
  String get authRegisterSubtitle => 'سجّل ببريدك الإلكتروني للبدء';

  @override
  String get authEmail => 'البريد الإلكتروني';

  @override
  String get authPassword => 'كلمة المرور';

  @override
  String get authConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get authSignIn => 'تسجيل الدخول';

  @override
  String get authSignUp => 'إنشاء حساب';

  @override
  String get authOrContinueWith => 'أو';

  @override
  String get authGoogle => 'المتابعة عبر Google';

  @override
  String get authHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get authNoAccount => 'ليس لديك حساب؟';

  @override
  String get authInvalidEmail => 'أدخل بريداً إلكترونياً صحيحاً';

  @override
  String get authPasswordTooShort => 'يجب أن تكون كلمة المرور 8 أحرف على الأقل';

  @override
  String get authPasswordMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get authVerifyTitle => 'أدخل رمز التحقّق';

  @override
  String authVerifySubtitle(String email) {
    return 'أرسلنا رمز التحقّق إلى $email';
  }

  @override
  String get authVerifyAction => 'تأكيد';

  @override
  String get authVerifyResend => 'إعادة الإرسال';

  @override
  String authVerifyResendIn(int seconds) {
    return 'إعادة الإرسال بعد $seconds ثانية';
  }

  @override
  String get authVerifyResent => 'أُرسل رمز جديد';

  @override
  String get authVerifyWrongCode => 'الرمز غير صحيح أو انتهت صلاحيته';

  @override
  String get authVerifyChangeEmail => 'تغيير البريد';

  @override
  String get authVerifyJunkHint => 'لم يصل؟ انظر في البريد غير المرغوب فيه';

  @override
  String get authVerifyUnconfirmed =>
      'هذا الحساب لم يُؤكَّد بعد. أرسلنا رمزاً جديداً.';

  @override
  String get accountsTitle => 'الحسابات';

  @override
  String get accountsSaved => 'الدخول السريع';

  @override
  String get accountsSavedHint =>
      'حسابات محفوظة على هذا الجهاز — اضغط للدخول دون كلمة مرور';

  @override
  String get accountsCurrent => 'الحساب الحالي';

  @override
  String get accountsAdd => 'إضافة حساب آخر';

  @override
  String get accountsAddTitle => 'إضافة حساب';

  @override
  String get accountsAddSubtitle =>
      'سجّل الدخول بحساب آخر — حسابك الحالي يبقى محفوظاً للعودة إليه';

  @override
  String get accountsSwitching => 'جارٍ تبديل الحساب…';

  @override
  String get accountsRemove => 'إزالة من هذا الجهاز';

  @override
  String accountsRemoveConfirm(String name) {
    return 'إزالة $name من قائمة هذا الجهاز؟ ستحتاج كلمة المرور للدخول به مجدداً.';
  }

  @override
  String get accountsExpired =>
      'انتهت صلاحية جلسة هذا الحساب على هذا الجهاز. سجّل الدخول به من جديد.';

  @override
  String get profileCompleteTitle => 'أكمل ملفك الشخصي';

  @override
  String get profileCompleteSubtitle => 'املأ بياناتك لإرسالها للاعتماد';

  @override
  String get profileFirstName => 'الاسم الأول';

  @override
  String get profileSurname => 'الكنية';

  @override
  String get profileFatherName => 'اسم الأب';

  @override
  String get profilePhoto => 'الصورة الشخصية';

  @override
  String get profileJobTitle => 'الوصف الوظيفي';

  @override
  String get profileCity => 'المدينة';

  @override
  String get profileGender => 'الجنس';

  @override
  String get profileDateOfBirth => 'تاريخ الميلاد';

  @override
  String get profileMissionType => 'نوع البعثة';

  @override
  String get profilePhoneSy => 'رقم الهاتف السوري';

  @override
  String get profilePhoneSa => 'رقم الهاتف السعودي';

  @override
  String get profilePassportPhoto => 'صورة جواز السفر';

  @override
  String get profileVisaPhoto => 'صورة التأشيرة';

  @override
  String get profileNusukPhoto => 'صورة بطاقة نسك';

  @override
  String get profileDocumentsSection => 'المستندات (اختياري)';

  @override
  String get profilePickImage => 'اختر صورة';

  @override
  String get profileChangeImage => 'تغيير';

  @override
  String get profileSelectDate => 'اختر التاريخ';

  @override
  String get profileSubmitForApproval => 'إرسال للاعتماد';

  @override
  String get profileCamera => 'الكاميرا';

  @override
  String get profileGallery => 'معرض الصور';

  @override
  String get genderMale => 'ذكر';

  @override
  String get genderFemale => 'أنثى';

  @override
  String get statusPendingTitle => 'قيد الانتظار';

  @override
  String get statusPendingMessage =>
      'حسابك قيد المراجعة. ستحصل على صلاحية الدخول بمجرد اعتماده من قبل المدير.';

  @override
  String get statusRejectedTitle => 'لم يتم اعتماد الحساب';

  @override
  String get statusRejectedMessage => 'لم تتم الموافقة على حسابك.';

  @override
  String statusRejectedReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get statusEditAndResubmit => 'تعديل وإعادة الإرسال';

  @override
  String get statusSuspendedTitle => 'الحساب موقوف';

  @override
  String get statusSuspendedMessage =>
      'تم إيقاف حسابك. يرجى التواصل مع المدير.';

  @override
  String get homeTitle => 'الرئيسية';

  @override
  String homeWelcome(String name) {
    return 'مرحباً، $name';
  }

  @override
  String homeHijriDate(String date) {
    return '$date هـ';
  }

  @override
  String homeGregorianDate(String date) {
    return '$date م';
  }

  @override
  String profileTitleBadgeSuffix(String badge) {
    return '($badge)';
  }

  @override
  String get homeAdminSection => 'الإدارة';

  @override
  String get homeGeneralSection => 'عام';

  @override
  String get homeAdminGroupFiles => 'الملفات والقرارات والتعميمات';

  @override
  String get homeAdminGroupPeople => 'الأشخاص والصلاحيات';

  @override
  String get homeAdminGroupSeason => 'الموسم والمراجع';

  @override
  String get homeAdminGroupOversight => 'الإشراف والسجلات';

  @override
  String get navApprovals => 'اعتماد الحسابات';

  @override
  String get navApprovalsSubtitle => 'مراجعة طلبات التسجيل المعلّقة';

  @override
  String get approvalQueueTitle => 'الحسابات قيد الانتظار';

  @override
  String get approvalEmpty => 'لا توجد حسابات بانتظار الاعتماد';

  @override
  String approvalPendingCount(int count) {
    return '$count قيد الانتظار';
  }

  @override
  String get approvalDetailTitle => 'مراجعة الحساب';

  @override
  String get approvalApprove => 'اعتماد';

  @override
  String get approvalReject => 'رفض';

  @override
  String get approvalRejectReasonTitle => 'سبب الرفض';

  @override
  String get approvalRejectReasonHint => 'اختياري — يظهر لمقدّم الطلب';

  @override
  String get approvalApproved => 'تم اعتماد الحساب';

  @override
  String get approvalRejected => 'تم رفض الحساب';

  @override
  String get profileSectionPersonal => 'المعلومات الشخصية';

  @override
  String get profileSectionContact => 'معلومات التواصل';

  @override
  String get contactWhatsApp => 'مراسلة عبر واتساب';

  @override
  String get profileSectionDocuments => 'المستندات';

  @override
  String get profileBadgeExternal => 'خارجي';

  @override
  String get profileBadgeAdmin => 'مدير';

  @override
  String get profileFieldNotProvided => 'غير مرفق';

  @override
  String get profileNoPhone => '—';

  @override
  String get navPermissions => 'الصلاحيات';

  @override
  String get navPermissionsSubtitle => 'منح الصلاحيات للموظفين';

  @override
  String get permissionsEmployeesTitle => 'الموظفون';

  @override
  String get permissionEditorTitle => 'الصلاحيات';

  @override
  String get permissionAssignIntro =>
      'اختر الصلاحيات المطلوبة، ثم أسندها لعدة موظفين دفعة واحدة. صلاحيات شخص بعينه تُعدَّل من صفحته في دليل الموظفين.';

  @override
  String permissionAssignSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صلاحية مختارة',
      many: '$count صلاحيةً مختارةً',
      few: '$count صلاحيات مختارة',
      two: 'صلاحيتان مختارتان',
      one: 'صلاحية واحدة مختارة',
      zero: 'لم تختر أي صلاحية بعد',
    );
    return '$_temp0';
  }

  @override
  String get permissionAssignAction => 'إسناد إلى موظفين';

  @override
  String get permissionAssignPickEmployees => 'اختر الموظفين';

  @override
  String permissionAssignDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُسندت الصلاحيات لـ$count موظف',
      many: 'أُسندت الصلاحيات لـ$count موظفاً',
      few: 'أُسندت الصلاحيات لـ$count موظفين',
      two: 'أُسندت الصلاحيات لموظفين',
      one: 'أُسندت الصلاحيات لموظف واحد',
    );
    return '$_temp0';
  }

  @override
  String get permissionAssignNothingNew =>
      'لا جديد يُضاف — المختارون يملكون هذه الصلاحيات أصلاً';

  @override
  String get employeesEmpty => 'لا يوجد موظفون بعد';

  @override
  String get permissionSaved => 'تم تحديث الصلاحيات';

  @override
  String permissionGrantedCount(int count, int total) {
    return '$count من $total صلاحية';
  }

  @override
  String get commonSearch => 'بحث';

  @override
  String get commonClearAll => 'إلغاء التحديد';

  @override
  String pickerSelectedCount(int count) {
    return '$count مُحدَّد';
  }

  @override
  String get commonSelectAll => 'تحديد الكل';

  @override
  String get permAllGranted => 'صلاحيات كاملة (مدير)';

  @override
  String get perm_employees => 'الموظفون';

  @override
  String get perm_approvals => 'اعتماد الحسابات';

  @override
  String get perm_seasons => 'المواسم';

  @override
  String get perm_permissions => 'الصلاحيات';

  @override
  String get permEmployeesView => 'عرض الموظفين وتفاصيلهم';

  @override
  String get permEmployeesCreate => 'إضافة موظف';

  @override
  String get permEmployeesEdit => 'تعديل بيانات الموظفين';

  @override
  String get permEmployeesDelete => 'حذف الموظفين';

  @override
  String get permEmployeesPassword => 'إعادة تعيين كلمة مرور موظف';

  @override
  String get permEmployeesEmail => 'تغيير البريد الإلكتروني لموظف';

  @override
  String get permEmployeesSuspend => 'إيقاف الحسابات وتفعيلها';

  @override
  String get permEmployeesExternal => 'إدارة الصفة الخارجية';

  @override
  String get permEmployeesDocuments => 'عرض مستندات الموظفين';

  @override
  String get permApprovalsView => 'عرض طلبات التسجيل';

  @override
  String get permApprovalsDecide => 'قبول الطلبات ورفضها';

  @override
  String get permSeasonsView => 'عرض المواسم';

  @override
  String get permSeasonsSwitch => 'تعيين الموسم الحالي';

  @override
  String get permSeasonsParticipantsView => 'عرض مشاركي المواسم';

  @override
  String get permSeasonsParticipantsManage => 'إضافة المشاركين وسحبهم';

  @override
  String get permPermissionsView => 'عرض الصلاحيات الممنوحة';

  @override
  String get permPermissionsManage => 'منح الصلاحيات وسحبها';

  @override
  String get perm_reference => 'البيانات المرجعية';

  @override
  String get permReferenceView => 'عرض البيانات المرجعية';

  @override
  String get permReferenceEdit => 'إضافة البيانات المرجعية وتعديلها';

  @override
  String get permReferenceDelete => 'حذف البيانات المرجعية';

  @override
  String get permReferenceImport => 'نسخ البيانات من موسم آخر';

  @override
  String get perm_reports => 'القرارات والتعميمات';

  @override
  String get permReportsViewAll =>
      'عرض كل القرارات والتعميمات بما فيها المسودات';

  @override
  String get permReportsCreate => 'إنشاء القرارات والتعميمات';

  @override
  String get permReportsEdit => 'تعديل القرارات والتعميمات';

  @override
  String get permReportsDelete => 'حذف القرارات والتعميمات';

  @override
  String get permReportsPublish => 'نشر القرارات والتعميمات وإلغاء نشرها';

  @override
  String get perm_notifications => 'الإشعارات';

  @override
  String get permNotificationsSend => 'إرسال إشعار لموظف';

  @override
  String get permNotificationsBroadcastModule => 'إرسال إشعار لأعضاء ملف';

  @override
  String get permNotificationsBroadcastAll => 'إرسال إشعار عام للجميع';

  @override
  String get perm_audit => 'سجل الأحداث';

  @override
  String get permAuditView => 'قراءة سجل من فعل ماذا';

  @override
  String get perm_complaints => 'الشكاوى';

  @override
  String get permComplaintsView => 'عرض جميع الشكاوى المقدَّمة';

  @override
  String get permComplaintsReply => 'المشاركة في نقاش أي شكوى';

  @override
  String get permComplaintsLock => 'إغلاق الشكوى أمام الردود';

  @override
  String get permComplaintsDismiss => 'رفض الشكوى باعتبارها غير صحيحة';

  @override
  String get permComplaintsDelete => 'حذف الشكاوى';

  @override
  String get perm_evaluations => 'التقييمات';

  @override
  String get permEvaluationsView => 'عرض جميع التقييمات ودرجاتها';

  @override
  String get permEvaluationsTemplates => 'إنشاء نماذج التقييم وتعديلها';

  @override
  String get permEvaluationsAssign => 'فتح تقييم وتسمية من يملؤه';

  @override
  String get permEvaluationsDelete => 'حذف التقييمات';

  @override
  String get perm_incidents => 'البلاغات العاجلة';

  @override
  String get permIncidentsReceive => 'استقبال البلاغات العاجلة وقراءتها';

  @override
  String get permIncidentsHandle => 'تولّي بلاغ عاجل وإغلاقه';

  @override
  String get permIncidentsDelete => 'حذف البلاغات العاجلة من السجل';

  @override
  String get perm_checkin => 'تسجيل الوصول';

  @override
  String get permCheckinBoard => 'قراءة سجل دوام الجميع';

  @override
  String get permCheckinCodes => 'عرض رموز الأماكن وطباعتها ومشاركتها';

  @override
  String get permCheckinRotate => 'تجديد رمز مكان — يُبطل كل نسخة مطبوعة منه';

  @override
  String get perm_export => 'تصدير البيانات';

  @override
  String get permExportData =>
      'تصدير أي نوع من البيانات، بما لا يستطيع فتحه على الشاشة';

  @override
  String get perm_map => 'خريطة الموسم';

  @override
  String get permMapView => 'فتح خريطة الموسم';

  @override
  String get perm_tasks => 'المهام';

  @override
  String get permTasksAssign => 'إسناد مهام إلى الآخرين';

  @override
  String get permTasksViewAll => 'رؤية كل المهام المُسندة في البعثة';

  @override
  String permissionRequires(String names) {
    return 'يتطلب: $names';
  }

  @override
  String get permissionDenied => 'لا تملك الصلاحية اللازمة لهذا الإجراء';

  @override
  String get navNotifications => 'الإشعارات';

  @override
  String get notificationTargetGone => 'لم يعد هذا الملف متاحاً';

  @override
  String get notificationsEmpty => 'لا توجد إشعارات بعد';

  @override
  String get notificationSend => 'إرسال إشعار';

  @override
  String get notificationFilterAll => 'الكل';

  @override
  String get notificationFilterMessages => 'إشعارات';

  @override
  String get notificationFilterIncidents => 'بلاغات عاجلة';

  @override
  String notificationFilterCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get notificationOpenIncident => 'فتح البلاغ';

  @override
  String get notificationOpenModule => 'فتح الملف التشغيلي';

  @override
  String get notificationsEmptyIncidents => 'لا بلاغات عاجلة في الوارد';

  @override
  String get notificationsEmptyMessages => 'لا إشعارات';

  @override
  String get notificationTitleField => 'العنوان';

  @override
  String get notificationBodyField => 'الرسالة';

  @override
  String get notificationSent => 'تم إرسال الإشعار';

  @override
  String get notificationMarkAllRead => 'تعليم الكل كمقروء';

  @override
  String get notificationAudience => 'المرسل إليهم';

  @override
  String get notificationAudienceAll => 'الجميع';

  @override
  String get notificationAudienceModule => 'أعضاء ملف تشغيلي';

  @override
  String get notificationChooseModule => 'اختر الملف';

  @override
  String get notificationBroadcastHint =>
      'يصل الإشعار إلى كل من يحمل دوراً في الملف';

  @override
  String get notificationAttach => 'إرفاق';

  @override
  String get notificationAttachPhoto => 'صورة';

  @override
  String get notificationAttachCamera => 'التقاط صورة';

  @override
  String get notificationAttachVideo => 'فيديو';

  @override
  String get notificationAttachAudio => 'ملف صوتي';

  @override
  String get notificationAttachFile => 'ملف';

  @override
  String notificationAttachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرفقاً',
      few: '$count مرفقات',
      two: 'مرفقان',
      one: 'مرفق واحد',
    );
    return '$_temp0';
  }

  @override
  String attachmentTooLarge(String limit) {
    return 'الملف أكبر من الحدّ المسموح ($limit). اختر ملفاً أصغر.';
  }

  @override
  String get attachmentImage => 'صورة';

  @override
  String get attachmentVideo => 'فيديو';

  @override
  String get attachmentAudio => 'صوت';

  @override
  String get attachmentFile => 'ملف';

  @override
  String get attachmentDownload => 'تحميل';

  @override
  String get attachmentOpenFailed => 'تعذّر فتح المرفق';

  @override
  String get modulesSearchHint => 'ابحث في الملفات';

  @override
  String get modulesNoMatches => 'لا يوجد ملف مطابق';

  @override
  String get reportScanCode => 'امسح الرمز';

  @override
  String get reportCellEntryGone => 'لم يعد هذا الخيار موجوداً';

  @override
  String get reportTimeFrom => 'من';

  @override
  String get reportTimeTo => 'إلى';

  @override
  String reportTimeRange(String from, String to) {
    return 'من الساعة $from إلى الساعة $to';
  }

  @override
  String get reportAddTag => 'أضف عنصراً';

  @override
  String get reportSubtitle => 'عنوان فرعي';

  @override
  String get reportShape => 'شكل المستند';

  @override
  String get reportKindDecision => 'قرار';

  @override
  String get reportKindCircular => 'تعميم';

  @override
  String get reportNumber => 'الرقم';

  @override
  String reportNumberBadge(String number) {
    return 'رقم $number';
  }

  @override
  String get reportContentSection => 'المحتوى';

  @override
  String get reportContentHint =>
      'ابنِ المستند من العناصر أدناه — عنوان، نصّ، قائمة، جدول، رابط، رمز للمسح. تظهر بالترتيب الذي تضيفها به.';

  @override
  String get reportNoBlocks => 'لم يُضف شيء بعد';

  @override
  String get blockHeading => 'عنوان';

  @override
  String get blockSubheading => 'عنوان فرعي';

  @override
  String get blockParagraph => 'فقرة';

  @override
  String get blockBullets => 'قائمة نقاط';

  @override
  String get blockNumbers => 'قائمة مرقّمة';

  @override
  String get blockTable => 'جدول';

  @override
  String get blockUrl => 'رابط';

  @override
  String get blockQr => 'رمز QR';

  @override
  String get blockNote => 'ملاحظة';

  @override
  String get blockDivider => 'فاصل';

  @override
  String get blockMoveUp => 'تحريك للأعلى';

  @override
  String get blockMoveDown => 'تحريك للأسفل';

  @override
  String get blockTextShort => 'النص';

  @override
  String get blockTextLong => 'النص';

  @override
  String get blockItems => 'العناصر';

  @override
  String get blockItemsHint => 'عنصر في كل سطر';

  @override
  String get blockLabel => 'التسمية';

  @override
  String get blockQrValue => 'ما يحمله الرمز';

  @override
  String get blockQrHint => 'غالباً رابط';

  @override
  String get blockColumnLabel => 'العنوان';

  @override
  String get blockColumnKind => 'نوع العمود';

  @override
  String get blockColumnKindText => 'نصّ';

  @override
  String get blockColumnKindNumber => 'رقم';

  @override
  String get blockColumnKindDate => 'تاريخ';

  @override
  String get blockColumnKindTime => 'وقت';

  @override
  String get blockColumnKindTimeRange => 'مدة زمنية';

  @override
  String get blockColumnKindReference => 'من البيانات المرجعية';

  @override
  String get blockColumnKindTags => 'قائمة عناصر';

  @override
  String get blockColumnSet => 'القائمة';

  @override
  String get blockColumnSpan => 'دمج المتكرر';

  @override
  String blockColumnRetypeWarning(int count) {
    return 'ستُفرَّغ $count من الخلايا التي لا يمكن تحويلها';
  }

  @override
  String get blockAddItem => 'أضف عنصراً';

  @override
  String get blockAddColumn => 'أضف عموداً';

  @override
  String get blockTableNeedsColumns => 'سمِّ الأعمدة أولاً، ثم أضف الصفوف';

  @override
  String get reportNew => 'مستند جديد';

  @override
  String get reportEdit => 'تعديل المستند';

  @override
  String get reportSaved => 'تم الحفظ';

  @override
  String get reportIdentity => 'ما هذا المستند';

  @override
  String get reportTitle => 'العنوان';

  @override
  String get reportScopeHint =>
      'المستند العام يبقى سارياً مهما كان الموسم الجاري';

  @override
  String get reportOncePerSeason =>
      'هذا الشكل يُنشأ مرة واحدة فقط خلال الموسم، وهو منشأ من قبل — عدّل الموجود بدلاً من إنشاء آخر';

  @override
  String get reportPublished => 'منشور';

  @override
  String get reportPublishedHint =>
      'غير المنشور لا يراه إلا من يدير القرارات والتعميمات';

  @override
  String get reportAddRow => 'إضافة صف';

  @override
  String get reportNoRows => 'لا توجد صفوف بعد';

  @override
  String get reportsManageEmpty => 'لا توجد قرارات ولا تعميمات بعد';

  @override
  String reportDeleteConfirm(String title) {
    return 'حذف $title؟ لا يمكن التراجع.';
  }

  @override
  String get reportDeleted => 'تم الحذف';

  @override
  String reportRowsSection(int count) {
    return 'الصفوف ($count)';
  }

  @override
  String reportRowNumber(int number) {
    return 'الصف $number';
  }

  @override
  String get navReportsManage => 'إدارة القرارات والتعميمات';

  @override
  String get navReportsManageSubtitle =>
      'إدخال القرارات والتعميمات وتعديلها ونشرها';

  @override
  String get navReports => 'القرارات والتعميمات';

  @override
  String get navReportsSubtitle => 'ما تصدره الإدارة وتنشره على البعثة';

  @override
  String get reportsEmpty => 'لم يُنشر شيء بعد';

  @override
  String get reportsNoMatches => 'لا يوجد مطابق';

  @override
  String get reportsSearchHint => 'ابحث في القرارات والتعميمات';

  @override
  String get reportsScopeAll => 'الكل';

  @override
  String get reportsScopeSeasonal => 'هذا الموسم';

  @override
  String get reportsScopeGeneral => 'عام';

  @override
  String get reportsDraft => 'غير منشور';

  @override
  String get reportMissing => 'لم يعد هذا المستند متاحاً';

  @override
  String get reportAboutSection => 'عن هذا المستند';

  @override
  String get reportKind => 'النوع';

  @override
  String get reportScope => 'يسري على';

  @override
  String get reportAbout => 'ما يتناوله';

  @override
  String get reportSource => 'المستند الأصلي';

  @override
  String get reportQrFailed => 'تعذّر رسم هذا الرمز';

  @override
  String reportUpdated(String date) {
    return 'آخر تحديث $date';
  }

  @override
  String get navSeasons => 'المواسم';

  @override
  String get navSeasonsSubtitle => 'الموسم الحالي والأرشيف';

  @override
  String get seasonsTitle => 'المواسم';

  @override
  String get seasonCurrentLabel => 'الموسم الحالي';

  @override
  String get seasonUpcomingLabel => 'المواسم القادمة';

  @override
  String get seasonArchiveLabel => 'المواسم السابقة';

  @override
  String seasonHijriYear(int year) {
    return '$year هـ';
  }

  @override
  String get seasonBadgeCurrent => 'حالي';

  @override
  String get seasonParticipantsTitle => 'المشاركون';

  @override
  String seasonParticipantsCount(int count) {
    return '$count مشارك';
  }

  @override
  String get seasonManageParticipants => 'إدارة المشاركين';

  @override
  String get seasonNoParticipants => 'لا يوجد مشاركون في هذا الموسم بعد';

  @override
  String get seasonSetCurrent => 'تعيين كموسم حالي';

  @override
  String get seasonSetCurrentDone => 'تم تحديث الموسم الحالي';

  @override
  String get seasonArchiveEmpty => 'لا توجد مواسم سابقة';

  @override
  String get seasonSelectParticipants => 'اختيار المشاركين';

  @override
  String get seasonParticipantsSaved => 'تم تحديث المشاركين';

  @override
  String get navEmployees => 'الموظفون';

  @override
  String get navEmployeesSubtitle => 'دليل الموظفين والخارجيين';

  @override
  String get employeesPermanentSection => 'الموظفون الدائمون';

  @override
  String get employeesExternalSection => 'الموظفون الخارجيون';

  @override
  String get employeesFilterSuspended => 'الموقوفون فقط';

  @override
  String get employeesExternalEmpty => 'لا يوجد موظفون خارجيون';

  @override
  String get employeeDetailTitle => 'الموظف';

  @override
  String get modulePickerOnlyFree => 'غير المسندين فقط';

  @override
  String get moduleRosterSearchHint => 'ابحث بالاسم أو الصفة';

  @override
  String get moduleRosterAllRoles => 'كل الصفات';

  @override
  String get moduleRosterClear => 'إلغاء التصفية';

  @override
  String moduleRosterShowing(int showing, int total) {
    return 'يُعرض $showing من $total';
  }

  @override
  String get moduleRosterNoMatch => 'لا أحد في هذا الملف يطابق البحث';

  @override
  String referenceChildCount(String list) {
    return 'عدد $list المسندة';
  }

  @override
  String referenceOfCapacity(int total, int capacity) {
    return '$total من أصل $capacity';
  }

  @override
  String referenceOverCapacity(int excess) {
    return 'تجاوز الحد الأقصى بمقدار $excess';
  }

  @override
  String get placeOccupants => 'الشاغلون';

  @override
  String placeOccupantsBreakdown(int pilgrims, int staff) {
    return '$pilgrims حاجّ، $staff من الكوادر';
  }

  @override
  String get placeOccupantsStaff => 'الكوادر المُسكَّنون';

  @override
  String get placeOccupantsPilgrims => 'الحجاج';

  @override
  String get employeePermissionsSection => 'الصلاحيات الممنوحة';

  @override
  String get employeePermissionsEmpty => 'لا توجد صلاحيات ممنوحة';

  @override
  String get employeePermissionsAdmin =>
      'مدير — يملك جميع الصلاحيات دون الحاجة إلى منحها.';

  @override
  String get employeePermissionsEdit => 'تعديل الصلاحيات';

  @override
  String get employeeEditDetailsTitle => 'تعديل بيانات الموظف';

  @override
  String get employeeEditSaved => 'تم تحديث بيانات الموظف';

  @override
  String get employeeEdit => 'تعديل البيانات';

  @override
  String get employeeDelete => 'حذف الموظف';

  @override
  String get employeeDeleteConfirmTitle => 'حذف هذا الموظف؟';

  @override
  String employeeDeleteConfirmBody(String name) {
    return 'سيُحذف $name نهائياً مع حسابه وكل إسناداته. لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get employeeDeleted => 'تم حذف الموظف';

  @override
  String get employeeDeleteAdminBlocked =>
      'لا يمكن حذف مدير. أزل صفة الإدارة عنه أولاً.';

  @override
  String get employeePassword => 'تغيير كلمة المرور';

  @override
  String employeePasswordTitle(String name) {
    return 'كلمة مرور جديدة لـ $name';
  }

  @override
  String get employeePasswordHint =>
      'سيدخل الموظف بكلمة المرور الجديدة في المرة القادمة. أبلغه بها بنفسك — لا تُرسل إليه رسالة.';

  @override
  String get employeePasswordNew => 'كلمة المرور الجديدة';

  @override
  String get employeePasswordConfirm => 'تأكيد كلمة المرور';

  @override
  String get employeePasswordChanged => 'تم تغيير كلمة المرور';

  @override
  String get employeePasswordAdminBlocked =>
      'لا يمكن تغيير كلمة مرور مدير إلا من مدير آخر.';

  @override
  String get employeeEmail => 'تغيير البريد الإلكتروني';

  @override
  String employeeEmailTitle(String name) {
    return 'بريد إلكتروني جديد لـ $name';
  }

  @override
  String get employeeEmailHint =>
      'سيدخل الموظف بالبريد الإلكتروني الجديد من الآن فصاعداً. أبلغه به بنفسك — لا تُرسل رسالة إلى أي من العنوانين.';

  @override
  String get employeeEmailNew => 'البريد الإلكتروني الجديد';

  @override
  String get employeeEmailChanged => 'تم تغيير البريد الإلكتروني';

  @override
  String get employeeEmailAdminBlocked =>
      'لا يمكن تغيير البريد الإلكتروني لمدير إلا من مدير آخر.';

  @override
  String get employeeEmailTaken =>
      'هذا البريد الإلكتروني مستخدم من قبل حساب آخر.';

  @override
  String get myProfileChangeEmail => 'تغيير البريد الإلكتروني';

  @override
  String get myProfileNewEmail => 'البريد الإلكتروني الجديد';

  @override
  String get myProfileEmailChanged =>
      'تم تغيير البريد الإلكتروني. ستدخل بالعنوان الجديد من الآن فصاعداً.';

  @override
  String get employeeEditExternalTitle => 'الصفة الخارجية';

  @override
  String get employeeIsExternal => 'موظف خارجي';

  @override
  String get employeeIsExternalHint =>
      'من جهة حكومية أخرى — ليس من الموظفين الدائمين';

  @override
  String get employeeOrganization => 'الجهة / الوزارة';

  @override
  String get employeeExternalSaved => 'تم تحديث بيانات الموظف';

  @override
  String get employeeSectionOrganization => 'الجهة';

  @override
  String get employeeSeasonsSection => 'المواسم التي شارك بها';

  @override
  String get employeeSeasonsEmpty => 'لم يشارك في أي موسم بعد';

  @override
  String get employeeSeasonBadgeCurrent => 'حالي';

  @override
  String get employeeModulesSection => 'الملفات التشغيلية المُسندة إليه';

  @override
  String get employeeModulesEmpty => 'لم يُسند إلى أي ملف تشغيلي';

  @override
  String get navMyProfile => 'ملفي الشخصي';

  @override
  String get navMyProfileSubtitle => 'عرض وتعديل بياناتك';

  @override
  String get myProfileEdit => 'تعديل الملف';

  @override
  String get myProfileChangePassword => 'تغيير كلمة المرور';

  @override
  String get myProfileNewPassword => 'كلمة المرور الجديدة';

  @override
  String get myProfileConfirmPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get myProfilePasswordChanged => 'تم تغيير كلمة المرور';

  @override
  String get myProfileSaved => 'تم تحديث الملف';

  @override
  String get myProfileEditTitle => 'تعديل الملف';

  @override
  String get createEmployeeTitle => 'إنشاء موظف';

  @override
  String get createEmployeeCreated => 'تم إنشاء الموظف';

  @override
  String get createEmployeeAccountSection => 'بيانات الحساب';

  @override
  String get createEmployeeSubmit => 'إنشاء الحساب';

  @override
  String get commonDelete => 'حذف';

  @override
  String get perm_modules => 'الملفات التشغيلية';

  @override
  String get permModulesViewAll => 'عرض كل الملفات بما فيها المسودات';

  @override
  String get permModulesCreate => 'إنشاء ملف تشغيلي';

  @override
  String get permModulesEdit => 'تعديل الملف وهيكله';

  @override
  String get permModulesDelete => 'حذف ملف تشغيلي';

  @override
  String get permModulesActivate => 'تفعيل الملفات وإيقافها';

  @override
  String get permModulesMembers => 'إسناد الأعضاء والمهام';

  @override
  String get permModulesTasks => 'كتابة مهام الملف وتحديث أي حالة';

  @override
  String get permModulesReports => 'عرض تقارير أعضاء الملفات';

  @override
  String get navModules => 'الملفات التشغيلية';

  @override
  String get navModulesSubtitle => 'الملفات المسندة إليك، وأدوارك ومهامك فيها';

  @override
  String get navReferenceData => 'البيانات المرجعية';

  @override
  String get navReferenceDataSubtitle => 'الفنادق والتكتلات والقوائم الأخرى';

  @override
  String get modulesManageTitle => 'إدارة الملفات التشغيلية';

  @override
  String get modulesEmptyMine => 'لم تُسند إليك ملفات في هذا الموسم';

  @override
  String get navModulesManage => 'إدارة الملفات التشغيلية';

  @override
  String get navModulesManageSubtitle => 'كل ملفات الموسم، وإنشاء ملف جديد';

  @override
  String get modulesTitle => 'الملفات التشغيلية';

  @override
  String get modulesEmpty => 'لم يتم إسناد أي ملف إليك بعد';

  @override
  String get modulesEmptyManager => 'لم يتم إنشاء أي ملف بعد';

  @override
  String get moduleActiveSection => 'الملفات المفعّلة';

  @override
  String get moduleDraftSection => 'المسودات';

  @override
  String get moduleBadgeDraft => 'غير مفعّل';

  @override
  String get moduleNew => 'ملف جديد';

  @override
  String get moduleChooseType => 'اختر نوع الملف';

  @override
  String get moduleNoTypes => 'لم يتم تعريف أي نوع ملف بعد';

  @override
  String get moduleAllTypesUsed => 'تم إنشاء جميع أنواع الملفات في هذا الموسم';

  @override
  String get moduleOnePerSeason =>
      'يُنشأ الملف مرة واحدة في الموسم، واسمه هو نوعه';

  @override
  String get moduleSeasonLabel => 'الموسم';

  @override
  String moduleDecisionBadge(String number) {
    return 'قرار $number';
  }

  @override
  String get moduleDecisionNumber => 'رقم القرار / الملف';

  @override
  String get moduleDecisionNumberHint => 'اختياري — يُضاف عند صدور القرار';

  @override
  String get moduleEndDate => 'تاريخ الانتهاء';

  @override
  String get moduleEndDateHint => 'اختياري — ينتهي الملف بنهاية هذا اليوم';

  @override
  String get moduleEndDateClear => 'بلا تاريخ انتهاء';

  @override
  String get moduleEndBeforeStart => 'تاريخ الانتهاء قبل تاريخ البدء';

  @override
  String get moduleStartDate => 'تاريخ بدء العمل';

  @override
  String get moduleStartNote => 'ملاحظة بداية العمل';

  @override
  String get moduleStartNoteHint => 'اختياري — ما يُقال عن بداية هذا الملف';

  @override
  String get moduleEndNote => 'ملاحظة نهاية العمل';

  @override
  String get moduleEndNoteHint => 'اختياري — ما يُقال عن نهاية هذا الملف';

  @override
  String get moduleReportCadence => 'التقارير';

  @override
  String get moduleReportCadenceHint => 'كم مرة يرفع أعضاء الملف تقريراً';

  @override
  String get cadenceNone => 'لا تقارير';

  @override
  String get cadenceDaily => 'تقرير يومي';

  @override
  String get cadenceWeekly => 'تقرير أسبوعي';

  @override
  String get cadenceOnce => 'تقرير لمرة واحدة';

  @override
  String get moduleRatingNone => 'لم يقيّمك أحد في هذا الملف بعد';

  @override
  String moduleRatingValue(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييماً',
      few: '$count تقييمات',
      two: 'تقييمان',
      one: 'تقييم واحد',
    );
    return '$average من 5 · $_temp0';
  }

  @override
  String get moduleRatingAnonymous =>
      'التقييم مجهول — يرى الزميل متوسطه وعدد من قيّموه، ولا يعرف من أعطى ماذا';

  @override
  String get moduleRatingSaved => 'تم حفظ التقييم';

  @override
  String get moduleRatingCleared => 'تم سحب التقييم';

  @override
  String get moduleReports => 'التقارير';

  @override
  String get moduleReportWrite => 'رفع تقرير';

  @override
  String get moduleReportEdit => 'تعديل تقريري';

  @override
  String get moduleReportNotes => 'ملاحظات';

  @override
  String get moduleReportNotesHint =>
      'اختياري — إن كان لديك ما تضيفه على المرفقات';

  @override
  String get moduleReportAttachHint =>
      'التقرير هو ما ترفعه: صور، ملفات، أو تسجيل صوتي';

  @override
  String get moduleReportNothingAttached => 'بلا مرفقات';

  @override
  String get moduleReportSaved => 'تم رفع التقرير';

  @override
  String get moduleReportsEmpty => 'لم تُرفع تقارير بعد';

  @override
  String moduleReportPeriodDay(String date) {
    return 'تقرير يوم $date';
  }

  @override
  String moduleReportPeriodWeek(String date) {
    return 'أسبوع $date';
  }

  @override
  String get moduleStartCondition => 'بداية العمل';

  @override
  String get moduleEndCondition => 'نهاية العمل';

  @override
  String get moduleStepInfo => 'الملف';

  @override
  String get moduleStepSectors => 'القطاعات';

  @override
  String get moduleStepTowers => 'الأبراج';

  @override
  String get moduleStepMembers => 'الفريق';

  @override
  String get moduleNodeName => 'الاسم';

  @override
  String moduleNodeAdd(String level) {
    return 'إضافة $level';
  }

  @override
  String moduleNodeEdit(String level) {
    return 'تعديل $level';
  }

  @override
  String moduleNodeDelete(String level) {
    return 'حذف $level';
  }

  @override
  String moduleNodeDeleteConfirm(String name) {
    return 'حذف «$name»؟ سيُحذف كل ما بداخله معه.';
  }

  @override
  String moduleNodeSuggestedName(String level, int number) {
    return '$level $number';
  }

  @override
  String get moduleSectorsImport => 'استيراد القطاعات';

  @override
  String get moduleSectorsImportPick =>
      'انسخ القطاعات من ملف آخر في هذا الموسم — الاسم والمشرف والمعاون. النسخ مستقلة: حذف قطاع هنا لا يمسّ الملف الآخر.';

  @override
  String moduleSectorsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم استيراد $count قطاعاً',
      few: 'تم استيراد $count قطاعات',
      two: 'تم استيراد قطاعين',
      one: 'تم استيراد قطاع واحد',
      zero: 'لا قطاعات جديدة',
    );
    return '$_temp0';
  }

  @override
  String get moduleSectorsImportFailed => 'تعذّر استيراد القطاعات';

  @override
  String get moduleSectorsImportNoSources =>
      'لا يوجد ملف آخر في هذا الموسم فيه قطاعات';

  @override
  String get moduleNoNodes => 'لم يُضف شيء بعد';

  @override
  String get moduleSectorsFirst => 'أضف القطاعات أولاً، ثم وزّع الفنادق عليها';

  @override
  String get moduleBuildTree => 'إضافة القطاعات والأبراج';

  @override
  String get moduleNoLevels => 'لم تُعرّف بنية هذا النوع من الملفات بعد';

  @override
  String get moduleSectionWhen => 'مدة العمل';

  @override
  String get moduleSectionPaperwork => 'القرار والتقارير';

  @override
  String get moduleSectionTypeFields => 'بيانات هذا النوع';

  @override
  String get moduleNotesShow => 'أضف ملاحظة على البداية أو النهاية';

  @override
  String get moduleNotesHide => 'إخفاء الملاحظتين';

  @override
  String get moduleSectionInfo => 'معلومات الملف';

  @override
  String get moduleSectionTasks => 'دوري في الملف';

  @override
  String moduleSectionTasksOf(String name) {
    return '$name — الدور';
  }

  @override
  String get moduleJobDescription => 'الوصف الوظيفي';

  @override
  String get moduleTasksSection => 'المهام';

  @override
  String get moduleTasksFile => 'مهام الملف';

  @override
  String get moduleTasksFileHint =>
      'تخصّ الملف كاملاً — يتقاسمها أعضاؤه فيما بينهم';

  @override
  String get moduleTasksRole => 'مهام الدور';

  @override
  String moduleTasksRoleOf(String name) {
    return 'مهام $name';
  }

  @override
  String get moduleTasksRoleHint =>
      'مرتبطة بالدور لا بالشخص — تبقى كما هي إذا تغيّر من يشغله';

  @override
  String get moduleTasksNone => 'لم تُكتب مهام على هذا الملف بعد';

  @override
  String get taskStateNotStarted => 'لم تبدأ';

  @override
  String get taskStateInProgress => 'قيد التنفيذ';

  @override
  String get taskStateBlocked => 'متعثّرة';

  @override
  String get taskStateSubmitted => 'بانتظار القبول';

  @override
  String get taskStateDone => 'منجزة';

  @override
  String get taskStateReturned => 'مُعادة';

  @override
  String get taskStateCancelled => 'ملغاة';

  @override
  String moduleTaskDue(String date) {
    return 'الاستحقاق: $date';
  }

  @override
  String get moduleTaskAdd => 'إضافة مهمة';

  @override
  String get moduleTaskEdit => 'تعديل المهمة';

  @override
  String get moduleTaskDelete => 'حذف المهمة';

  @override
  String get moduleTaskDeleteConfirm => 'حذف هذه المهمة من قائمة الملف؟';

  @override
  String get moduleTaskScope => 'نطاق المهمة';

  @override
  String get moduleTaskScopeFile => 'مهمة ملف';

  @override
  String get moduleTaskScopeFileHint =>
      'للملف كاملاً — يتقاسمها الأعضاء فيما بينهم';

  @override
  String get moduleTaskScopeRole => 'مهمة دور';

  @override
  String get moduleTaskScopeRoleHint =>
      'ما يعنيه شغل هذا الدور، أياً كان من يشغله';

  @override
  String get moduleTaskRoleLabel => 'الدور';

  @override
  String get moduleTaskTitleLabel => 'عنوان المهمة';

  @override
  String get moduleTaskTitleEnLabel => 'العنوان بالإنكليزية';

  @override
  String get moduleTaskDescriptionLabel => 'الوصف';

  @override
  String get moduleTaskNoDue => 'بلا تاريخ';

  @override
  String get moduleTaskPickRole => 'اختر الدور';

  @override
  String get navTasks => 'مهامي';

  @override
  String get navTasksSubtitle => 'قائمتك الخاصة، وما أُسند إليك';

  @override
  String get tasksTitle => 'مهامي';

  @override
  String get tasksOwnSection => 'مهامي الخاصة';

  @override
  String get tasksOwnHint => 'كتبتها لنفسك — لك تعديلها وحذفها وتحريكها كاملاً';

  @override
  String get tasksAssignedSection => 'مُسندة إليّ';

  @override
  String get tasksAssignedHint => 'كُتبت لك — لا تملك عليها سوى تغيير حالتها';

  @override
  String get tasksIAssignedSection => 'أسندتُها لغيري';

  @override
  String get tasksIAssignedHint => 'ما كتبته على قوائم الآخرين، وتتابعه من هنا';

  @override
  String get tasksEmpty => 'لا مهام بعد';

  @override
  String get tasksEmptyHint => 'اكتب مهمتك الأولى بالزر في الأسفل';

  @override
  String get tasksNew => 'مهمة جديدة';

  @override
  String get tasksAssign => 'إسناد مهمة';

  @override
  String get navTasksManage => 'إسناد المهام';

  @override
  String get navTasksManageSubtitle =>
      'كتابة المهام على قوائم الآخرين ومتابعتها';

  @override
  String get tasksManageTitle => 'إسناد المهام';

  @override
  String get tasksManageEmpty => 'لم تُسند شيئاً بعد';

  @override
  String get tasksManageEmptyHint =>
      'أسنِد مهمة بالزر في الأسفل — يُبلَّغ صاحبها، ولا يملك عليها سوى تغيير حالتها';

  @override
  String get taskPickPerson => 'اختر الموظف';

  @override
  String taskAssignedBy(String name) {
    return 'أسندها: $name';
  }

  @override
  String taskAssignedTo(String name) {
    return 'إلى: $name';
  }

  @override
  String get taskTitleLabel => 'المهمة';

  @override
  String get taskDescriptionLabel => 'الوصف';

  @override
  String taskDue(String date) {
    return 'الاستحقاق: $date';
  }

  @override
  String get taskNoDue => 'بلا تاريخ';

  @override
  String get taskState => 'الحالة';

  @override
  String get taskNote => 'ملاحظة';

  @override
  String get taskNoteHint => 'ما الذي يستحق أن يُقال عنها؟';

  @override
  String get taskEvidence => 'دليل الإنجاز';

  @override
  String get taskUpdate => 'تحديث الحالة';

  @override
  String get taskStateSaved => 'تم تحديث الحالة';

  @override
  String get taskSaved => 'حُفظت المهمة';

  @override
  String get taskReadOnly =>
      'مهمة مُسندة إليك — تحرّكها وتعلّق عليها، ونصّها لكاتبها';

  @override
  String get taskEdit => 'تعديل المهمة';

  @override
  String get taskDelete => 'حذف المهمة';

  @override
  String get taskDeleteConfirm => 'حذف هذه المهمة؟ سيُحذف ما أُرفق بها معها.';

  @override
  String taskProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String taskKey(int seq) {
    return 'م-$seq';
  }

  @override
  String get taskMoveStart => 'ابدأ';

  @override
  String get taskMoveBlock => 'تعثّرت';

  @override
  String get taskMoveSubmit => 'أرسِل للقبول';

  @override
  String get taskMoveDone => 'أنجزتُها';

  @override
  String get taskMoveAccept => 'اقبَل';

  @override
  String get taskMoveReturn => 'أعِدها';

  @override
  String get taskMoveReopen => 'أعِد فتحها';

  @override
  String get taskMoveCancel => 'ألغِ المهمة';

  @override
  String get taskMoveRestore => 'أعِدها للقائمة';

  @override
  String get taskNoActions => 'لا إجراء متاح لك على هذه المهمة الآن';

  @override
  String get taskPriority => 'الأولوية';

  @override
  String get taskPriorityHigh => 'عاجلة';

  @override
  String get taskPriorityNormal => 'عادية';

  @override
  String get taskPriorityLow => 'منخفضة';

  @override
  String get taskKind => 'النوع';

  @override
  String get taskKindTask => 'مهمة';

  @override
  String get taskKindFollowUp => 'متابعة';

  @override
  String get taskKindRequest => 'طلب';

  @override
  String get taskViewToday => 'اليوم';

  @override
  String get taskViewWeek => 'الأسبوع';

  @override
  String get taskViewOverdue => 'متأخرة';

  @override
  String get taskViewOpen => 'الجارية';

  @override
  String get taskViewDone => 'المنجزة';

  @override
  String get taskViewAll => 'الكل';

  @override
  String taskLateDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'تأخّرت $days يوماً',
      few: 'تأخّرت $days أيام',
      two: 'تأخّرت يومين',
      one: 'تأخّرت يوماً',
    );
    return '$_temp0';
  }

  @override
  String get taskDueToday => 'تستحق اليوم';

  @override
  String get taskDueTomorrow => 'تستحق غداً';

  @override
  String get taskThread => 'ما جرى';

  @override
  String get taskThreadEmpty => 'لم يُقل شيء بعد';

  @override
  String get taskCommentHint => 'اكتب ما يستحق أن يُقال';

  @override
  String get taskCommentSend => 'أرسِل';

  @override
  String get taskCommentAdded => 'أُضيف التعليق';

  @override
  String get taskCommentRequired => 'هذه الحركة تحتاج سبباً مكتوباً';

  @override
  String get taskBySystem => 'النظام';

  @override
  String get taskEventCreated => 'أنشأ المهمة';

  @override
  String get taskEventAssigned => 'أسند المهمة';

  @override
  String taskEventStateTo(String state) {
    return 'نقلها إلى: $state';
  }

  @override
  String get taskEventReassigned => 'نقلها إلى شخص آخر';

  @override
  String taskEventDue(String date) {
    return 'غيّر الاستحقاق إلى $date';
  }

  @override
  String get taskEventDueCleared => 'أزال تاريخ الاستحقاق';

  @override
  String taskEventPriority(String priority) {
    return 'غيّر الأولوية إلى $priority';
  }

  @override
  String get taskEventEscalated => 'تنبيه بالتأخر';

  @override
  String get taskSteps => 'الخطوات';

  @override
  String taskStepsProgress(int done, int total) {
    return '$done من $total';
  }

  @override
  String get taskStepsEdit => 'تعديل الخطوات';

  @override
  String get taskStepAdd => 'أضف خطوة';

  @override
  String get taskStepHint => 'خطوة';

  @override
  String get taskStepsSaved => 'حُفظت الخطوات';

  @override
  String get taskStepsOwnerOnly => 'الخطوات يكتبها من أسند المهمة';

  @override
  String taskBatchOf(String title) {
    return 'ضمن: $title';
  }

  @override
  String taskBatchCarriers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخصاً',
      few: '$count أشخاص',
      two: 'شخصان',
      one: 'شخص واحد',
    );
    return '$_temp0';
  }

  @override
  String taskBatchAcceptReady(int count) {
    return 'اقبَل الجاهز ($count)';
  }

  @override
  String get taskBatchNudge => 'ذكّر المتبقّي';

  @override
  String taskBatchAccepted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قُبلت $count مهمة',
      few: 'قُبلت $count مهام',
      two: 'قُبلت مهمتان',
      one: 'قُبلت مهمة واحدة',
    );
    return '$_temp0';
  }

  @override
  String taskBatchNudged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُرسل التذكير لـ $count',
      two: 'أُرسل التذكير لاثنين',
      one: 'أُرسل التذكير لواحد',
    );
    return '$_temp0';
  }

  @override
  String get tasksBatchesEmpty => 'لا دفعات بعد';

  @override
  String get tasksBatchesEmptyHint =>
      'الدفعة تُكتب حين تُسند مهمة واحدة لأكثر من شخص';

  @override
  String get taskReassign => 'إعادة الإسناد';

  @override
  String get taskReassignHint =>
      'تنتقل المهمة بخيطها وأدلتها، وتعود إلى «لم تبدأ»';

  @override
  String get taskReassigned => 'نُقلت المهمة';

  @override
  String get taskCancel => 'إلغاء المهمة';

  @override
  String get taskCancelConfirm =>
      'إلغاء هذه المهمة؟ تبقى في السجل ويُبلَّغ صاحبها، ولا تُحذف.';

  @override
  String get taskCancelled => 'أُلغيت المهمة';

  @override
  String get taskGone => 'لم تعد هذه المهمة موجودة';

  @override
  String get taskGoneHint => 'ربما سُحبت أو حُذفت';

  @override
  String taskStartedAt(String date) {
    return 'بدأت: $date';
  }

  @override
  String taskSubmittedAt(String date) {
    return 'أُرسلت للقبول: $date';
  }

  @override
  String taskAcceptedAt(String date) {
    return 'قُبلت: $date';
  }

  @override
  String get tasksSearch => 'ابحث بالعنوان أو الرقم';

  @override
  String get tasksNoMatch => 'لا مهمة تطابق ما بحثتَ عنه';

  @override
  String get tasksClearFilters => 'أزل الفلاتر';

  @override
  String get tasksBoardTitle => 'لوحة المهام';

  @override
  String get tasksBoardView => 'حسب الحالة';

  @override
  String get tasksBatchesView => 'حسب المهمة';

  @override
  String get tasksPeopleView => 'حسب الشخص';

  @override
  String get tasksAssignTargetTitle => 'إلى من تُسند المهمة؟';

  @override
  String get tasksAssignToPeople => 'أشخاص';

  @override
  String get tasksAssignToPeopleHint =>
      'مهمة متتبّعة تظهر على قائمة كل شخص تختاره، ويردّها إليك للقبول';

  @override
  String get tasksAssignToFile => 'ملف تشغيلي';

  @override
  String get tasksAssignToFileHint =>
      'واجب يُكتب على الملف نفسه، يراه كل أعضائه ويتقاسمونه بينهم';

  @override
  String get tasksAssignToRole => 'دور في ملف';

  @override
  String get tasksAssignToRoleHint =>
      'واجب على منصب بعينه — مشرف البرج مثلاً — أياً كان شاغله';

  @override
  String get tasksAssignPickModule => 'اختر الملف';

  @override
  String get tasksAssignPickRole => 'اختر الدور';

  @override
  String get tasksAssignNoRoles => 'نوع هذا الملف بلا أدوار معرّفة';

  @override
  String get tasksAssignDutySaved => 'كُتب الواجب على الملف';

  @override
  String get tasksScopeMine => 'ما أسندتُه';

  @override
  String get tasksScopeAll => 'البعثة كلها';

  @override
  String get tasksReviewQueue => 'بانتظار قبولك';

  @override
  String get tasksReviewEmpty => 'لا شيء ينتظر قبولك';

  @override
  String get taskStatsOpen => 'عليّ';

  @override
  String get taskStatsOverdue => 'متأخرة';

  @override
  String get taskStatsReview => 'بانتظار قبولي';

  @override
  String get taskStatsDone => 'أنجزتُها';

  @override
  String get moduleTeamPick => 'اختيار الأعضاء';

  @override
  String moduleTeamPickFor(String role) {
    return 'اختيار: $role';
  }

  @override
  String get moduleNoTeamMembers => 'لم يُختر أعضاء هذا الفريق بعد';

  @override
  String get moduleNoRoles => 'لا توجد أدوار معرّفة لهذا النوع من الملفات بعد';

  @override
  String moduleMembersCount(int count) {
    return '$count عضواً';
  }

  @override
  String get moduleNoMembers => 'لم يُسند أي عضو هنا بعد';

  @override
  String get moduleRoleUnassigned => 'غير مُسند';

  @override
  String get moduleMemberHousing => 'السكن';

  @override
  String get moduleHousingUnset => 'لم يُحدَّد السكن';

  @override
  String get moduleHousedHere => 'يسكنون هنا';

  @override
  String get moduleSaved => 'تم الحفظ';

  @override
  String get moduleActivate => 'تفعيل الملف';

  @override
  String get moduleDeactivate => 'إلغاء تفعيل الملف';

  @override
  String get moduleActivated => 'تم تفعيل الملف — وصل الإشعار إلى الأعضاء';

  @override
  String get moduleDeactivated => 'تم إلغاء تفعيل الملف';

  @override
  String get moduleAttachPdf => 'إرفاق ملف PDF';

  @override
  String get moduleReplacePdf => 'استبدال الملف';

  @override
  String get moduleOpenPdf => 'فتح ملف PDF';

  @override
  String get moduleNoPdf => 'لا يوجد ملف مرفق';

  @override
  String get modulePdfOpenFailed => 'تعذّر فتح الملف';

  @override
  String get moduleDelete => 'حذف الملف';

  @override
  String get moduleDeleteConfirm =>
      'حذف هذا الملف؟ سيُحذف كل ما فيه — أعضاؤه ومهامهم المسندة ومرفقاته — معه.';

  @override
  String get moduleDeleted => 'تم حذف الملف';

  @override
  String get moduleNoCurrentSeason => 'حدّد الموسم الحالي قبل إنشاء الملفات';

  @override
  String get moduleNoParticipants => 'لا يوجد مشاركون في الموسم الحالي بعد';

  @override
  String get moduleContactSy => 'الرقم السوري';

  @override
  String get moduleContactSa => 'الرقم السعودي';

  @override
  String get modulePickerSearchHint => 'ابحث بالاسم أو الاختصاص الوظيفي';

  @override
  String get modulePickerAll => 'الجميع';

  @override
  String get modulePickerInternal => 'من البعثة';

  @override
  String get modulePickerExternal => 'من خارج البعثة';

  @override
  String get modulePickerNoMatches => 'لا أحد يطابق البحث';

  @override
  String get modulePickerFree => 'غير مُسند إلى أي ملف';

  @override
  String modulePickerAlreadyIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مُسند إلى $count ملفاً',
      few: 'مُسند إلى $count ملفات',
      two: 'مُسند إلى ملفين',
      one: 'مُسند إلى ملف واحد',
    );
    return '$_temp0';
  }

  @override
  String modulePickerConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تأكيد اختيار $count شخصاً',
      few: 'تأكيد اختيار $count أشخاص',
      two: 'تأكيد اختيار شخصين',
      one: 'تأكيد اختيار شخص واحد',
      zero: 'تأكيد بلا اختيار',
    );
    return '$_temp0';
  }

  @override
  String get referenceShelfPlaces => 'الأماكن';

  @override
  String get referenceShelfStructure => 'تقسيمات الملفات';

  @override
  String get referenceShelfMission => 'البعثة';

  @override
  String get referenceShelfReports => 'مدخلات التقارير';

  @override
  String get referenceShelfOther => 'أخرى';

  @override
  String get referenceDataTitle => 'البيانات المرجعية';

  @override
  String referenceItemsCount(int count) {
    return '$count عنصراً';
  }

  @override
  String get referenceImport => 'استيراد من موسم آخر';

  @override
  String get referenceImportPick =>
      'انسخ القائمة من موسم سابق. النسخ مستقلة — حذف عنصر هنا لا يمسّ الموسم الآخر.';

  @override
  String referenceImported(int count) {
    return 'تم استيراد $count عنصراً';
  }

  @override
  String get referenceImportFailed => 'تعذّر الاستيراد';

  @override
  String get referenceImportNoSeasons => 'لا توجد مواسم أخرى';

  @override
  String get referenceAddItem => 'إضافة عنصر';

  @override
  String get referenceItemName => 'الاسم (بالعربية)';

  @override
  String get referenceItemNameEn => 'الاسم (بالإنكليزية)';

  @override
  String get referenceItemSaved => 'تم حفظ العنصر';

  @override
  String get referenceItemDeleted => 'تم حذف العنصر';

  @override
  String get referenceDivisionAll => 'الكل';

  @override
  String get referenceDivisionNone => 'بلا تصنيف';

  @override
  String get referenceEmpty => 'لا توجد عناصر بعد';

  @override
  String referenceDeleteConfirm(String name) {
    return 'حذف «$name»؟';
  }

  @override
  String get referenceInUse => 'هذا العنصر مستخدم في أحد الملفات ولا يمكن حذفه';

  @override
  String get referenceDuplicate => 'يوجد عنصر بهذا الاسم في القائمة بالفعل';

  @override
  String get referenceDeleteAll => 'حذف الكل';

  @override
  String referenceDeleteAllConfirm(int count, String name) {
    return 'سيتم حذف $count عنصراً من «$name» نهائياً. لا يمكن التراجع عن هذا.';
  }

  @override
  String referenceDeleteAllDone(int count) {
    return 'تم حذف $count عنصراً';
  }

  @override
  String referenceDeleteAllPartial(int deleted, int kept) {
    return 'تم حذف $deleted عنصراً، وبقي $kept لأنها مستخدمة في ملفات أو قوائم أخرى';
  }

  @override
  String get referenceDeleteAllNone =>
      'لم يُحذف أي عنصر: جميعها مستخدمة في ملفات أو قوائم أخرى';

  @override
  String get referenceDeletingAll => 'جارٍ الحذف…';

  @override
  String get referenceOpenLink => 'فتح الرابط';

  @override
  String get locationPickerTitle => 'تحديد الموقع';

  @override
  String get locationPickOnMap => 'من الخريطة';

  @override
  String get locationUseCurrent => 'موقعي الحالي';

  @override
  String get locationOrPasteLink => 'أو الصق رابط الموقع';

  @override
  String get locationTapToPlace => 'اضغط على الخريطة لتحديد الموقع';

  @override
  String get locationConfirm => 'تأكيد هذا الموقع';

  @override
  String get locationCaptured => 'تم التقاط الموقع الحالي';

  @override
  String get locationPermissionDenied => 'لم يُسمح بالوصول إلى الموقع';

  @override
  String get locationServiceDisabled => 'خدمة الموقع مغلقة في الجهاز';

  @override
  String get locationFailed => 'تعذّر تحديد موقعك';

  @override
  String get locationOpenMap => 'فتح على الخريطة';

  @override
  String get referenceCall => 'اتصال';

  @override
  String get referenceLinkFailed => 'تعذّر فتح الرابط';

  @override
  String get referenceDetailsTitle => 'التفاصيل';

  @override
  String get profileSectionPermissions => 'الصلاحيات';

  @override
  String get profilePermissionsAdmin => 'مدير النظام — كل الصلاحيات';

  @override
  String get profilePermissionsNone => 'لا صلاحيات إدارية';

  @override
  String get profilePermissionsNoneHint =>
      'وهذا هو الحال المعتاد: الملفات التشغيلية تصلك بالإسناد لا بالصلاحية.';

  @override
  String profilePermissionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صلاحية',
      few: '$count صلاحيات',
      two: 'صلاحيتان',
      one: 'صلاحية واحدة',
    );
    return '$_temp0';
  }

  @override
  String get navAuditLog => 'سجل الأحداث';

  @override
  String get navAuditLogSubtitle => 'من فعل ماذا ومتى';

  @override
  String get auditEmptyTitle => 'لا أحداث بعد';

  @override
  String get auditEmptyBody => 'كل تغيير يجري في التطبيق يُسجَّل هنا.';

  @override
  String get auditPulseTitle => 'نبض السجلّ';

  @override
  String get auditPulseByAction => 'حسب نوع الحدث';

  @override
  String get auditPulseEmpty => 'لا أحداث في هذه المدّة';

  @override
  String auditPulseEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حدث',
      many: '$count حدثاً',
      few: '$count أحداث',
      two: 'حدثان',
      one: 'حدث واحد',
      zero: 'لا حدث',
    );
    return '$_temp0';
  }

  @override
  String auditPulseActors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخص',
      many: '$count شخصاً',
      few: '$count أشخاص',
      two: 'شخصان',
      one: 'شخص واحد',
      zero: 'لا فاعل',
    );
    return '$_temp0';
  }

  @override
  String get auditSearchHint => 'بحث باسم الشخص أو السجل…';

  @override
  String get auditActionInsert => 'إضافة';

  @override
  String get auditActionUpdate => 'تعديل';

  @override
  String get auditActionDelete => 'حذف';

  @override
  String get auditActionLogin => 'تسجيل دخول';

  @override
  String get auditActionLogout => 'تسجيل خروج';

  @override
  String get auditFilterAction => 'العملية';

  @override
  String get auditFilterEntity => 'القسم';

  @override
  String get auditFilterActor => 'الشخص';

  @override
  String get auditFilterSeason => 'الموسم';

  @override
  String get auditSeasonNone => 'بلا موسم';

  @override
  String auditSeasonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حدثاً',
      few: '$count أحداث',
      two: 'حدثان',
      one: 'حدث واحد',
      zero: 'لا أحداث',
    );
    return '$_temp0';
  }

  @override
  String get auditFilterDate => 'الفترة';

  @override
  String get auditClearFilters => 'مسح الفلاتر';

  @override
  String get auditSystem => 'النظام';

  @override
  String get auditDetails => 'تفاصيل الحدث';

  @override
  String get auditActor => 'قام به';

  @override
  String get auditChanges => 'ما الذي تغيّر';

  @override
  String get auditRecordData => 'بيانات السجل';

  @override
  String get auditDeletedData => 'السجل المحذوف';

  @override
  String auditRecipients(int count) {
    return '$count مستلم';
  }

  @override
  String get auditYes => 'نعم';

  @override
  String get auditNo => 'لا';

  @override
  String get auditNoDetails => 'لا تفاصيل إضافية لهذا الحدث.';

  @override
  String get navDashboard => 'لوحة المؤشرات';

  @override
  String get navDashboardSubtitle => 'الموسم كما يبدو من فوق';

  @override
  String get chartOther => 'أخرى';

  @override
  String get chartTotal => 'الإجمالي';

  @override
  String get dashboardTitle => 'لوحة المؤشرات';

  @override
  String get dashboardSeason => 'الموسم';

  @override
  String get dashboardNoSeason => 'لا يوجد موسم بعد';

  @override
  String get dashboardNothingToShow => 'لا توجد لديك صلاحية تُظهر أرقاماً هنا';

  @override
  String get dashboardSectionPeople => 'الأشخاص';

  @override
  String get dashboardSectionModules => 'الملفات التشغيلية';

  @override
  String get dashboardSectionWork => 'العمل';

  @override
  String get dashboardSectionQueue => 'طلبات الاعتماد';

  @override
  String get dashboardSectionCentralReports => 'القرارات';

  @override
  String get dashboardCentralPublished => 'منشور';

  @override
  String get dashboardCentralDrafts => 'مسودّات';

  @override
  String get dashboardCentralGeneral => 'عامة (كل المواسم)';

  @override
  String get dashboardCentralByType => 'حسب النوع';

  @override
  String get dashboardCentralSplit => 'المنشور والمسودّات';

  @override
  String get dashboardSectionNotifications => 'الإشعارات';

  @override
  String get dashboardNotifMessages30 => 'رسائل (٣٠ يوماً)';

  @override
  String get dashboardNotifRecipients => 'مستلمون';

  @override
  String get dashboardNotifReadShare => 'نسبة المقروء';

  @override
  String dashboardNotifReadOf(int read, int total) {
    return 'فُتحت $read من $total';
  }

  @override
  String get dashboardNotifTrend => 'رسائل آخر ٣٠ يوماً';

  @override
  String get dashboardNotifTrendEmpty => 'لا رسائل في آخر ٣٠ يوماً';

  @override
  String dashboardNotifAllTime(Object n) {
    return '$n رسالة منذ البداية';
  }

  @override
  String get dashboardNotSeasonScoped => 'لكل المواسم — لا يتبع الموسم المختار';

  @override
  String get dashboardSectionIncidents => 'البلاغات العاجلة';

  @override
  String get dashboardIncidentsOpen => 'بلاغات مفتوحة';

  @override
  String dashboardIncidentsInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$count قيد المعالجة',
      few: 'و$count قيد المعالجة',
      two: 'واثنان قيد المعالجة',
      one: 'وواحد قيد المعالجة',
      zero: 'لا شيء قيد المعالجة',
    );
    return '$_temp0';
  }

  @override
  String get dashboardIncidentsRecent => 'بلاغات آخر ٣٠ يوماً';

  @override
  String dashboardIncidentsAllTime(int count) {
    return '$count منذ البداية';
  }

  @override
  String get dashboardIncidentsAvgHandle => 'متوسط زمن التولّي';

  @override
  String get dashboardIncidentsAvgHandleCaption => 'من الرفع حتى يتولّاه أحد';

  @override
  String get dashboardIncidentsSplit => 'حالة البلاغات';

  @override
  String get dashboardIncidentsTrend => 'البلاغات يومياً';

  @override
  String get dashboardIncidentsTrendEmpty => 'لا بلاغات في هذه المدة';

  @override
  String get dashboardSectionCheckIn => 'تسجيل الوصول';

  @override
  String get dashboardCheckInToday => 'تسجيلات اليوم';

  @override
  String get dashboardCheckInPeople => 'من سجّلوا';

  @override
  String dashboardCheckInPlaces(int count) {
    return 'في $count مكاناً';
  }

  @override
  String get dashboardCheckInTotal => 'تسجيلات الموسم';

  @override
  String get dashboardCheckInTrend => 'التسجيلات يومياً';

  @override
  String get dashboardCheckInTrendEmpty => 'لا تسجيلات في هذه المدة';

  @override
  String get dashboardSectionTasks => 'المهام المُسندة';

  @override
  String get dashboardTasksOpen => 'مهام مفتوحة';

  @override
  String get dashboardTasksLate => 'متأخرة';

  @override
  String dashboardTasksEscalated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'صُعِّدت $count',
      few: 'صُعِّدت $count',
      two: 'صُعِّدت اثنتان',
      one: 'صُعِّدت واحدة',
      zero: 'لم يُصعَّد شيء',
    );
    return '$_temp0';
  }

  @override
  String get dashboardTasksAwaiting => 'بانتظار القبول';

  @override
  String get dashboardTasksAssignees => 'مُسنَد إليهم';

  @override
  String dashboardTasksAllTime(int count) {
    return '$count مهمة منذ البداية';
  }

  @override
  String get dashboardTasksByState => 'المهام حسب الحالة';

  @override
  String get dashboardTasksByPriority => 'المفتوحة حسب الأولوية';

  @override
  String get dashboardSectionEvaluations => 'التقييمات';

  @override
  String get dashboardEvalSubmitted => 'أوراق مُسلَّمة';

  @override
  String dashboardEvalOf(int count) {
    return 'من $count';
  }

  @override
  String get dashboardEvalLate => 'متأخرة';

  @override
  String dashboardEvalDrafts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مسوّدة',
      few: '$count مسوّدات',
      two: 'مسوّدتان',
      one: 'مسوّدة واحدة',
      zero: 'لا مسوّدات',
    );
    return '$_temp0';
  }

  @override
  String get dashboardEvalAverage => 'المتوسط';

  @override
  String get dashboardEvalAverageCaption => 'نسبةً إلى درجة كل نموذج';

  @override
  String get dashboardEvalEvaluators => 'المقيِّمون';

  @override
  String get dashboardSectionComplaints => 'الشكاوى';

  @override
  String get dashboardComplaintsOpen => 'شكاوى مفتوحة';

  @override
  String get dashboardComplaintsRecent => 'شكاوى آخر ٣٠ يوماً';

  @override
  String dashboardComplaintsAllTime(int count) {
    return '$count منذ البداية';
  }

  @override
  String get dashboardComplaintsDismissed => 'مرفوضة';

  @override
  String dashboardComplaintsLocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$count مغلقة',
      few: 'و$count مغلقة',
      two: 'ومغلقتان',
      one: 'ومغلقة واحدة',
      zero: 'لا شيء مغلق',
    );
    return '$_temp0';
  }

  @override
  String get dashboardComplaintsByTarget => 'الشكاوى حسب الجهة';

  @override
  String get dashboardSectionReference => 'البيانات المرجعية';

  @override
  String get dashboardRefSets => 'قوائم';

  @override
  String get dashboardRefItems => 'عناصر';

  @override
  String get dashboardRefActive => 'مفعّلة';

  @override
  String get dashboardRefSeasonSplit => 'موسمية وعامة';

  @override
  String get dashboardRefSeasonItems => 'لهذا الموسم';

  @override
  String get dashboardRefGeneralItems => 'عامة';

  @override
  String get dashboardRefBySet => 'العناصر في كل قائمة';

  @override
  String get dashboardSectionPermissions => 'الصلاحيات';

  @override
  String get dashboardPermAdmins => 'مديرو نظام';

  @override
  String get dashboardPermGrantees => 'موظفون بصلاحيات';

  @override
  String get dashboardPermGrants => 'منح ممنوحة';

  @override
  String get dashboardPermBySection => 'المنح حسب القسم';

  @override
  String get dashboardParticipants => 'مشاركو الموسم';

  @override
  String get dashboardWithdrawn => 'منسحب';

  @override
  String dashboardWithdrawnCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'وانسحب $count',
      one: 'وانسحب واحد',
      zero: 'لا أحد انسحب',
    );
    return '$_temp0';
  }

  @override
  String get dashboardInternalSplit => 'من البعثة ومن خارجها';

  @override
  String get dashboardInternal => 'من البعثة';

  @override
  String get dashboardExternal => 'من خارجها';

  @override
  String get dashboardUnknown => 'غير محدّد';

  @override
  String get dashboardByMission => 'حسب نوع البعثة';

  @override
  String get dashboardByGender => 'حسب الجنس';

  @override
  String get dashboardByJobTitle => 'أكثر المسمّيات الوظيفية';

  @override
  String get dashboardFiles => 'الملفات';

  @override
  String dashboardFilesCaption(int active, int draft) {
    return '$active مفعّل و$draft مسوّدة';
  }

  @override
  String get dashboardRunning => 'قيد التنفيذ';

  @override
  String get dashboardEnded => 'منتهية';

  @override
  String get dashboardNodes => 'القطاعات والأبراج';

  @override
  String get dashboardMembers => 'مسنَد إليهم ملف';

  @override
  String get dashboardUnstaffed => 'ملفات بلا أشخاص';

  @override
  String get dashboardUnstaffedCaption => 'لم يُسنَد إليها أحد بعد';

  @override
  String get dashboardByType => 'حسب نوع الملف';

  @override
  String get dashboardActiveDraft => 'المفعّل مقابل المسوّدة';

  @override
  String get dashboardReports => 'القرارات';

  @override
  String dashboardReportsCaption(int authors) {
    String _temp0 = intl.Intl.pluralLogic(
      authors,
      locale: localeName,
      other: 'من $authors كتّاب',
      one: 'من كاتب واحد',
      zero: 'لم يكتبها أحد',
    );
    return '$_temp0';
  }

  @override
  String get dashboardReportsTrend => 'القرارات خلال ٣٠ يوماً';

  @override
  String get dashboardReportsEmpty => 'لم تُرفَع تقارير في هذه المدّة';

  @override
  String get dashboardRatings => 'التقييمات';

  @override
  String get dashboardAverage => 'المتوسّط';

  @override
  String dashboardRatedPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عن $count أشخاص',
      one: 'عن شخص واحد',
      zero: 'لم يُقيَّم أحد',
    );
    return '$_temp0';
  }

  @override
  String get dashboardRatingDistribution => 'توزيع النجوم';

  @override
  String get dashboardPending => 'بانتظار الاعتماد';

  @override
  String get dashboardApproved => 'معتمد';

  @override
  String get dashboardRejected => 'مرفوض';

  @override
  String get dashboardIncomplete => 'لم يُكمل ملفه';

  @override
  String get prayerTimesTitle => 'مواقيت الصلاة';

  @override
  String get prayerFajr => 'الفجر';

  @override
  String get prayerSunrise => 'الشروق';

  @override
  String get prayerDhuhr => 'الظهر';

  @override
  String get prayerAsr => 'العصر';

  @override
  String get prayerMaghrib => 'المغرب';

  @override
  String get prayerIsha => 'العشاء';

  @override
  String get prayerNextLabel => 'الصلاة القادمة';

  @override
  String get prayerFajrEndsLabel => 'ينتهي وقت الفجر';

  @override
  String get prayerRemainingLabel => 'متبقٍ';

  @override
  String get prayerNowLabel => 'الآن';

  @override
  String get prayerAm => 'ص';

  @override
  String get prayerPm => 'م';

  @override
  String get prayerTomorrow => 'غداً';

  @override
  String get prayerSunriseGapNote => 'وقت الشروق — لا صلاة حتى الظهر';

  @override
  String get prayerLocating => 'جارٍ تحديد موقعك…';

  @override
  String get prayerApproximate => 'موقع تقريبي';

  @override
  String get prayerYourLocation => 'موقعك';

  @override
  String get prayerPlaceMakkah => 'مكة المكرمة';

  @override
  String get prayerPlaceMina => 'منى';

  @override
  String get prayerPlaceMuzdalifah => 'مزدلفة';

  @override
  String get prayerPlaceArafat => 'عرفات';

  @override
  String get prayerPlaceMadinah => 'المدينة المنورة';

  @override
  String get prayerPlaceJeddah => 'جدة';

  @override
  String get prayerAlertsTitle => 'تنبيهات الصلاة';

  @override
  String get prayerAlertsEnable => 'التنبيه لأوقات الصلاة';

  @override
  String get prayerAlertsHint =>
      'على هذا الجهاز وحده. تُحسب المواقيت داخل الجهاز من موقعه، ولا يُرسل شيء من الخادم.';

  @override
  String get prayerAlertsWhich => 'الصلوات المُنبَّه لها';

  @override
  String get prayerAlertsBefore => 'تنبيه قبل الأذان';

  @override
  String get prayerAlertsBeforeOff => 'بدون';

  @override
  String prayerAlertsMinutes(int count) {
    return '$count دقيقة';
  }

  @override
  String get prayerAlertsSilent => 'بلا صوت';

  @override
  String get prayerAlertsSilentHint => 'يظهر التنبيه ويهتز الجهاز كالمعتاد.';

  @override
  String get prayerAlertsBlocked =>
      'الإشعارات موقوفة لهذا التطبيق في إعدادات النظام.';

  @override
  String get prayerAlertsInexact =>
      'قد يؤخّر أندرويد التنبيه دقائق. اسمح بالمنبّهات الدقيقة ليصل كل أذان في وقته.';

  @override
  String get prayerAlertsGrantExact => 'السماح بالمنبّهات الدقيقة';

  @override
  String get prayerAlertsNeedLocation =>
      'حدِّد موقعك من بطاقة المواقيت أولاً — لا يُنبَّه لموقع تقريبي.';

  @override
  String get prayerAlertsUnsupported => 'تنبيهات الصلاة متاحة على أندرويد.';

  @override
  String prayerAlertNow(String prayer) {
    return 'حان الآن وقت $prayer';
  }

  @override
  String prayerAlertNowBody(String clock) {
    return 'الأذان الساعة $clock';
  }

  @override
  String prayerAlertBefore(String prayer, int count) {
    return '$prayer بعد $count دقيقة';
  }

  @override
  String prayerAlertBeforeBody(String clock) {
    return 'الأذان الساعة $clock';
  }

  @override
  String get navMyComplaints => 'الشكاوى';

  @override
  String get navMyComplaintsSubtitle => 'ما قدَّمتَه، وما ردّ به عليه';

  @override
  String get navComplaints => 'سجل الشكاوى';

  @override
  String get navComplaintsSubtitle => 'كل ما قُدِّم من شكاوى في البعثة';

  @override
  String get complaintsTitle => 'الشكاوى';

  @override
  String get complaintsMineTitle => 'شكاواي';

  @override
  String get complaintsAgainstMeTitle => 'الشكاوى المقدَّمة ضدي';

  @override
  String get complaintsNew => 'تقديم شكوى';

  @override
  String get complaintsEmpty => 'لم تقدّم أي شكوى';

  @override
  String get complaintsEmptyHint => 'قدّم شكواك الأولى بالزر في الأسفل';

  @override
  String get complaintsEmptyAll => 'لم تُقدَّم أي شكوى بعد';

  @override
  String get complaintsEmptyAllHint => 'ما يقدّمه الموظفون يظهر هنا فور تقديمه';

  @override
  String get complaintsAgainstMeEmpty => 'لم تُقدَّم أي شكوى ضدك';

  @override
  String get complaintsNoMatches => 'لا شكوى تطابق هذا';

  @override
  String get complaintsNoMatchesHint => 'وسّع البحث أو أزل عوامل التصفية';

  @override
  String get complaintsSearchHint => 'ابحث في الشكاوى';

  @override
  String get complaintsFilterAll => 'الكل';

  @override
  String get complaintsShowDismissed => 'إظهار المرفوضة';

  @override
  String get complaintTarget => 'الشكوى على';

  @override
  String get complaintTargetEmployee => 'موظف';

  @override
  String get complaintTargetModule => 'ملف تشغيلي';

  @override
  String get complaintTargetReport => 'قرار';

  @override
  String get complaintTargetHotel => 'فندق';

  @override
  String get complaintTargetCluster => 'تكتل';

  @override
  String get complaintTargetGroup => 'مجموعة';

  @override
  String get complaintTargetOther => 'شكوى أخرى';

  @override
  String get complaintTargetPick => 'اختر ما الشكوى عليه';

  @override
  String complaintTargetNone(String kind) {
    return 'لا يوجد $kind تستطيع الشكوى عليه: تظهر هنا الملفات التي أُسندت إليها ومن يعمل معك فيها. اختر «شكوى أخرى» واشرح الأمر بنصّ الشكوى.';
  }

  @override
  String complaintTargetPicked(String name) {
    return 'المُختار: $name';
  }

  @override
  String get complaintBody => 'ماذا حدث';

  @override
  String get complaintBodyHint => 'اشرح ما حدث بكلماتك';

  @override
  String get complaintBodyRequired => 'اكتب ما حدث';

  @override
  String get complaintTargetRequired => 'اختر ما الشكوى عليه';

  @override
  String get complaintSubmit => 'إرسال الشكوى';

  @override
  String get complaintSubmitted => 'تم تقديم شكواك';

  @override
  String get complaintAnonymousNote =>
      'سيقرأ الموظف المشتكى عليه نصّ الشكوى ومرفقاتها، ولن يُعرَّف بمن قدّمها.';

  @override
  String get complaintReply => 'ردّ';

  @override
  String get complaintReplyHint => 'اكتب ردّك';

  @override
  String get complaintReplySent => 'تم إرسال الردّ';

  @override
  String complaintReplyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ردّ',
      many: '$count ردّاً',
      few: '$count ردود',
      two: 'ردّان',
      one: 'ردّ واحد',
      zero: 'لا ردود',
    );
    return '$_temp0';
  }

  @override
  String get complaintRoleComplainant => 'مقدّم الشكوى';

  @override
  String get complaintRoleAccused => 'الموظف المشتكى عليه';

  @override
  String get complaintRoleManager => 'الرقابة';

  @override
  String get complaintLocked => 'أُغلقت هذه الشكوى أمام الردود';

  @override
  String get complaintLock => 'إغلاق الردود';

  @override
  String get complaintUnlock => 'إعادة فتح الردود';

  @override
  String get complaintDismissed => 'مرفوضة';

  @override
  String get complaintDismiss => 'رفض الشكوى';

  @override
  String get complaintUndismiss => 'إعادة الشكوى';

  @override
  String get complaintDismissReason => 'سبب الرفض (اختياري)';

  @override
  String get complaintDismissConfirm =>
      'الشكوى المرفوضة لا تُحتسب في الإيقاف التلقائي، وقد يُرفع بها إيقاف قائم. هل تُرفض؟';

  @override
  String get complaintDelete => 'حذف الشكوى';

  @override
  String get complaintDeleteConfirm =>
      'حذف هذه الشكوى وكل ما أُرفق بها؟ لا رجعة في ذلك.';

  @override
  String get complaintDeleted => 'حُذفت الشكوى';

  @override
  String get complaintWithdraw => 'سحب الشكوى';

  @override
  String get complaintMissing => 'لم تعد هذه الشكوى موجودة';

  @override
  String complaintFiledOn(String date) {
    return 'قُدِّمت $date';
  }

  @override
  String get complaintsSectionAgainst => 'الشكاوى على هذا الموظف';

  @override
  String complaintsAgainstCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شكوى',
      many: '$count شكوى',
      few: '$count شكاوى',
      two: 'شكويان',
      one: 'شكوى واحدة',
      zero: 'لا شيء',
    );
    return '$_temp0';
  }

  @override
  String complaintsDistinctComplainants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخص',
      many: '$count شخصاً',
      few: '$count أشخاص',
      two: 'شخصان',
      one: 'شخص واحد',
      zero: 'لا أحد',
    );
    return '$_temp0';
  }

  @override
  String get complaintsAutoSuspended => 'موقوف تلقائياً بسبب الشكاوى';

  @override
  String get complaintsAutoSuspendNear =>
      'مشتكٍ واحد آخر يوقف هذا الحساب تلقائياً';

  @override
  String complaintsDismissedCount(int count) {
    return '$count مرفوضة';
  }

  @override
  String get navEvaluations => 'التقييمات';

  @override
  String get navEvaluationsSubtitle => 'ما كُلِّفتَ بتقييمه';

  @override
  String get navEvaluationsManage => 'سجل التقييمات';

  @override
  String get navEvaluationsManageSubtitle => 'كل تقييم في البعثة وعلاماته';

  @override
  String get navEvaluationForms => 'إدارة التقييم';

  @override
  String get navEvaluationFormsSubtitle => 'نماذج التقييم وأسئلتها وعلاماتها';

  @override
  String get evaluationsTitle => 'سجل التقييمات';

  @override
  String get evaluationsMineTitle => 'التقييمات المكلَّف بها';

  @override
  String get evaluationsEmpty => 'لم تُكلَّف بأي تقييم بعد';

  @override
  String get evaluationsEmptyAll => 'لم يُفتح أي تقييم بعد';

  @override
  String get evaluationsNoMatches => 'لا نتائج مطابقة';

  @override
  String get evaluationsSearchHint => 'ابحث بالنموذج أو الجهة المُقيَّمة';

  @override
  String get evaluationsFilterAll => 'الكل';

  @override
  String get evaluationsNew => 'تقييم جديد';

  @override
  String evaluationsOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييم قيد التعبئة',
      many: '$count تقييماً قيد التعبئة',
      few: '$count تقييمات قيد التعبئة',
      two: 'تقييمان قيد التعبئة',
      one: 'تقييم واحد قيد التعبئة',
      zero: 'لا شيء قيد التعبئة',
    );
    return '$_temp0';
  }

  @override
  String evaluationsOverdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييم متأخر',
      many: '$count تقييماً متأخراً',
      few: '$count تقييمات متأخرة',
      two: 'تقييمان متأخران',
      one: 'تقييم واحد متأخر',
      zero: 'لا شيء متأخر',
    );
    return '$_temp0';
  }

  @override
  String get evaluationStatusDraft => 'قيد التعبئة';

  @override
  String get evaluationStatusSubmitted => 'مكتمل';

  @override
  String get evaluationOverdue => 'متأخر';

  @override
  String evaluationDueOn(String date) {
    return 'الموعد $date';
  }

  @override
  String evaluationOpenedOn(String date) {
    return 'فُتح في $date';
  }

  @override
  String evaluationSubmittedOn(String date) {
    return 'اكتمل في $date';
  }

  @override
  String get evaluationEvaluator => 'المُقيِّم';

  @override
  String get evaluationEvaluatorHidden => 'المُقيِّم غير معلن';

  @override
  String get evaluationSubject => 'الجهة المُقيَّمة';

  @override
  String get evaluationNote => 'ملاحظة الإدارة';

  @override
  String evaluationProgress(int answered, int total) {
    return '$answered من $total';
  }

  @override
  String evaluationScore(String score, String total) {
    return '$score من $total';
  }

  @override
  String evaluationPercent(String percent) {
    return '$percent٪';
  }

  @override
  String get evaluationTargetEmployee => 'موظف';

  @override
  String get evaluationTargetModule => 'ملف تشغيلي';

  @override
  String get evaluationTargetReport => 'قرار';

  @override
  String get evaluationTargetHotel => 'فندق';

  @override
  String get evaluationTargetCluster => 'تكتل';

  @override
  String get evaluationTargetGroup => 'مجموعة';

  @override
  String get evaluationTargetOther => 'أخرى';

  @override
  String get evaluationSheetTitle => 'التقييم';

  @override
  String evaluationStageOf(int index, int total) {
    return 'المرحلة $index من $total';
  }

  @override
  String evaluationStageScore(String score, String total) {
    return 'علامة المرحلة $score من $total';
  }

  @override
  String get evaluationQuestionRequired => 'إجباري';

  @override
  String get evaluationQuestionOptional => 'اختياري';

  @override
  String get evaluationQuestionUnanswered => 'لم تتم الإجابة';

  @override
  String get evaluationWriteHint => 'اكتب إجابتك';

  @override
  String get evaluationSaveDraft => 'حفظ';

  @override
  String get evaluationSubmit => 'اعتماد التقييم';

  @override
  String get evaluationSubmitted => 'اعتُمد التقييم';

  @override
  String get evaluationDraftSaved => 'حُفظت الإجابات';

  @override
  String get evaluationIncomplete => 'أجب عن كل الأسئلة الإجبارية أولاً';

  @override
  String get evaluationReopen => 'إعادة فتح';

  @override
  String get evaluationReopened => 'أُعيد فتح التقييم';

  @override
  String get evaluationReopenConfirm =>
      'يُعاد التقييم إلى قيد التعبئة وتبقى الإجابات كما هي. متابعة؟';

  @override
  String get evaluationNext => 'التالي';

  @override
  String get evaluationBack => 'السابق';

  @override
  String get evaluationLocked => 'هذا التقييم للاطّلاع فقط';

  @override
  String get evaluationDiscardChanges =>
      'هناك إجابات لم تُحفظ. الخروج دون حفظ؟';

  @override
  String get evaluationMissing => 'التقييم غير موجود';

  @override
  String get evaluationAlreadySubmitted => 'اعتُمد هذا التقييم من قبل';

  @override
  String get evaluationDelete => 'حذف التقييم';

  @override
  String get evaluationDeleteConfirm =>
      'يُحذف هذا التقييم وإجاباته نهائياً. متابعة؟';

  @override
  String get evaluationDeleted => 'حُذف التقييم';

  @override
  String get evaluationAssignTitle => 'فتح تقييم';

  @override
  String get evaluationAssignForm => 'النموذج';

  @override
  String get evaluationAssignPickForm => 'اختر نموذج التقييم';

  @override
  String get evaluationAssignNoForms =>
      'لا توجد نماذج مفعَّلة. أنشئ نموذجاً وفعِّله أولاً.';

  @override
  String get evaluationAssignSubject => 'الجهة المُقيَّمة';

  @override
  String get evaluationAssignPickSubject => 'اختر الجهة';

  @override
  String evaluationAssignSubjectPicked(String name) {
    return 'عن: $name';
  }

  @override
  String get evaluationAssignEvaluator => 'المُكلَّف بالتقييم';

  @override
  String get evaluationAssignPickEvaluator => 'اختر الموظف';

  @override
  String get evaluationAssignNoteHint =>
      'ما الذي تريد الانتباه إليه؟ (اختياري)';

  @override
  String get evaluationAssignDue => 'موعد التسليم (اختياري)';

  @override
  String get evaluationAssignDueClear => 'بلا موعد';

  @override
  String get evaluationAssignSubmit => 'فتح التقييم وإرساله';

  @override
  String get evaluationAssigned => 'فُتح التقييم وأُبلغ المُكلَّف به';

  @override
  String get evaluationAssignAnonymousNote =>
      'يرى الموظفُ المُقيَّم علامته ولا يعرف من قيَّمه.';

  @override
  String get evaluationFormsTitle => 'نماذج التقييم';

  @override
  String get evaluationFormsEmpty => 'لا نماذج تقييم بعد';

  @override
  String get evaluationFormsNew => 'نموذج جديد';

  @override
  String get evaluationFormsSearchHint => 'ابحث في النماذج';

  @override
  String get evaluationFormActive => 'مفعَّل';

  @override
  String get evaluationFormInactive => 'متوقف';

  @override
  String get evaluationFormActivate => 'تفعيل';

  @override
  String get evaluationFormDeactivate => 'إيقاف';

  @override
  String evaluationFormStages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرحلة',
      many: '$count مرحلة',
      few: '$count مراحل',
      two: 'مرحلتان',
      one: 'مرحلة واحدة',
    );
    return '$_temp0';
  }

  @override
  String evaluationFormQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سؤال',
      many: '$count سؤالاً',
      few: '$count أسئلة',
      two: 'سؤالان',
      one: 'سؤال واحد',
    );
    return '$_temp0';
  }

  @override
  String evaluationFormTotal(String total) {
    return 'من $total';
  }

  @override
  String evaluationFormInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييم مفتوح عليه',
      many: '$count تقييماً مفتوحاً عليه',
      few: '$count تقييمات مفتوحة عليه',
      two: 'تقييمان مفتوحان عليه',
      one: 'تقييم واحد مفتوح عليه',
    );
    return '$_temp0';
  }

  @override
  String get evaluationFormDelete => 'حذف النموذج';

  @override
  String get evaluationFormDeleteConfirm =>
      'يُحذف هذا النموذج بمراحله وأسئلته. متابعة؟';

  @override
  String get evaluationFormDeleted => 'حُذف النموذج';

  @override
  String get evaluationFormInUseDelete =>
      'لا يمكن حذف نموذج فُتح عليه تقييم. أوقفه بدل ذلك.';

  @override
  String get evaluationEditorNewTitle => 'نموذج تقييم جديد';

  @override
  String get evaluationEditorTitle => 'تعديل النموذج';

  @override
  String get evaluationEditorName => 'اسم النموذج';

  @override
  String get evaluationEditorNameHint =>
      'مثال: تقييم الملف التشغيلي — التروية والإعاشة';

  @override
  String get evaluationEditorDescription => 'وصف مختصر (اختياري)';

  @override
  String get evaluationEditorFor => 'يُقيِّم';

  @override
  String get evaluationEditorForLocked =>
      'لا يمكن تغيير نوع الجهة بعد فتح تقييمات على النموذج';

  @override
  String get evaluationEditorPublish => 'مفعَّل للاستخدام';

  @override
  String get evaluationEditorPublishHint =>
      'النموذج المتوقف لا يمكن فتح تقييم جديد عليه، وتبقى التقييمات المفتوحة تعمل';

  @override
  String get evaluationEditorStages => 'المراحل';

  @override
  String get evaluationEditorAddStage => 'إضافة مرحلة';

  @override
  String get evaluationEditorStageName => 'اسم المرحلة';

  @override
  String get evaluationEditorStageNameHint => 'مثال: فريق التروية';

  @override
  String get evaluationEditorStageDescription => 'وصف المرحلة (اختياري)';

  @override
  String get evaluationEditorRemoveStage => 'حذف المرحلة';

  @override
  String get evaluationEditorRemoveStageConfirm =>
      'تُحذف المرحلة بكل أسئلتها. متابعة؟';

  @override
  String get evaluationEditorAddChoice => 'سؤال بخيارات';

  @override
  String get evaluationEditorAddWritten => 'سؤال تحريري';

  @override
  String get evaluationEditorQuestionText => 'نص السؤال';

  @override
  String get evaluationEditorQuestionPoints => 'علامة السؤال';

  @override
  String get evaluationEditorRequired => 'إجباري';

  @override
  String get evaluationEditorAddOption => 'إضافة إجابة';

  @override
  String get evaluationEditorOptionText => 'نص الإجابة';

  @override
  String get evaluationEditorOptionPoints => 'العلامة';

  @override
  String get evaluationEditorNoQuestions => 'لا أسئلة في هذه المرحلة بعد';

  @override
  String get evaluationEditorWrittenNote =>
      'السؤال التحريري بلا علامة — لا للسؤال ولا لإجابته';

  @override
  String evaluationEditorUnreachable(String best, String points) {
    return 'أعلى إجابة تعطي $best بينما علامة السؤال $points';
  }

  @override
  String get evaluationEditorNeedsTwoOptions =>
      'السؤال بخيارات يحتاج إجابتين على الأقل';

  @override
  String evaluationEditorTotal(String total) {
    return 'مجموع علامات النموذج: $total';
  }

  @override
  String get evaluationEditorSave => 'حفظ النموذج';

  @override
  String get evaluationEditorSaved => 'حُفظ النموذج';

  @override
  String get evaluationEditorCannotPublish =>
      'أكمِل النموذج قبل تفعيله: لكل مرحلة اسم، ولكل سؤال نصّ، ولكل سؤال بخيارات إجابتان على الأقل';

  @override
  String get evaluationEditorMoveUp => 'تحريك للأعلى';

  @override
  String get evaluationEditorMoveDown => 'تحريك للأسفل';

  @override
  String get evaluationsAboutMeTitle => 'التقييمات الصادرة بحقي';

  @override
  String get evaluationsAboutMeEmpty => 'لم يصدر بحقك أي تقييم';

  @override
  String get evaluationsSectionAbout => 'تقييمات هذه الجهة';

  @override
  String evaluationsAboutCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييم',
      many: '$count تقييماً',
      few: '$count تقييمات',
      two: 'تقييمان',
      one: 'تقييم واحد',
      zero: 'لا تقييمات',
    );
    return '$_temp0';
  }

  @override
  String evaluationsAboutPending(int count) {
    return '$count قيد التعبئة';
  }

  @override
  String evaluationsAboutAverage(String percent) {
    return 'المعدل $percent٪';
  }

  @override
  String get evaluationsAboutAnonymousNote =>
      'تُعرض العلامات دون أسماء من كتبها.';

  @override
  String get evaluationErrorOptionTooHigh =>
      'علامة إحدى الإجابات أكبر من علامة سؤالها';

  @override
  String get evaluationErrorWrittenHasOptions =>
      'السؤال التحريري لا يقبل إجابات جاهزة';

  @override
  String get evaluationsOpenFromForms =>
      'تُفتح التقييمات من إدارة التقييم، على النموذج الذي ستُعبَّأ عليه';

  @override
  String evaluationAssignNoTargets(String kind) {
    return 'لا توجد جهات من نوع «$kind» يمكن فتح تقييم عنها';
  }

  @override
  String get evaluationAssignNoEvaluators => 'لا يوجد موظفون يمكن تكليفهم';

  @override
  String get evaluationFormMustBeActive =>
      'فعِّل النموذج أولاً ليمكن فتح تقييم عليه';

  @override
  String get evaluationEditorForHint =>
      'هنا تختار «نوع» الجهة فقط. أما الملف أو الموظف بعينه فيُختار عند فتح تقييم على هذا النموذج — من زرّ «تقييم جديد» على بطاقته بعد تفعيله.';

  @override
  String get evaluationAssignNoSeason =>
      'تعذّر تحديد الموسم الحالي، ولا يمكن اختيار المُكلَّف بدونه';

  @override
  String get evaluationAssignedShow => 'عرض';

  @override
  String get evaluationAssignSubjects => 'الجهات المُقيَّمة';

  @override
  String get evaluationAssignEvaluators => 'المُكلَّفون بالتقييم';

  @override
  String get evaluationAssignPickSubjects => 'اختر الجهات';

  @override
  String get evaluationAssignPickEvaluators => 'اختر الموظفين';

  @override
  String get evaluationAssignAddMore => 'إضافة';

  @override
  String evaluationAssignPlanned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سيُفتح $count تقييم',
      many: 'سيُفتح $count تقييماً',
      few: 'ستُفتح $count تقييمات',
      two: 'سيُفتح تقييمان',
      one: 'سيُفتح تقييم واحد',
      zero: 'لن يُفتح أي تقييم',
    );
    return '$_temp0';
  }

  @override
  String evaluationAssignCross(int targets, int evaluators) {
    return 'تقييم لكل جهة عند كل مُكلَّف — $targets × $evaluators';
  }

  @override
  String evaluationAssignedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فُتح $count تقييم وأُبلغ أصحابها',
      many: 'فُتح $count تقييماً وأُبلغ أصحابها',
      few: 'فُتحت $count تقييمات وأُبلغ أصحابها',
      two: 'فُتح تقييمان وأُبلغ أصحابهما',
      one: 'فُتح تقييم واحد وأُبلغ صاحبه',
    );
    return '$_temp0';
  }

  @override
  String get evaluationFormShowEvaluations => 'عرض التقييمات المفتوحة عليه';

  @override
  String evaluationSubjectEvaluators(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مُقيِّم',
      many: '$count مُقيِّماً',
      few: '$count مُقيِّمين',
      two: 'مُقيِّمان',
      one: 'مُقيِّم واحد',
      zero: 'بلا مُقيِّم',
    );
    return '$_temp0';
  }

  @override
  String get evaluationSubjectProgressLabel => 'سير التقييم';

  @override
  String get evaluationStatAverage => 'المعدل';

  @override
  String get evaluationStatBest => 'الأعلى';

  @override
  String get evaluationStatWorst => 'الأدنى';

  @override
  String get evaluationSubjectNoMarks => 'لا علامات بعد';

  @override
  String get commonOk => 'حسناً';

  @override
  String get locationResolved => 'تم استخراج الإحداثيات من الرابط';

  @override
  String get seasonMapOnlyThis => 'اضغط لإظهاره وحده';

  @override
  String get seasonMapShowAll => 'إظهار الكل';

  @override
  String get seasonMapNoTiles =>
      'تعذّر تحميل خلفية الخريطة — المواقع صحيحة، والصور وحدها لم تصل';

  @override
  String get seasonMapTitle => 'خريطة الموسم';

  @override
  String get seasonMapSubtitle =>
      'أماكن الموسم والبلاغات المفتوحة على خريطة واحدة';

  @override
  String get seasonMapManned => 'فيه أحد';

  @override
  String get seasonMapUnmanned => 'لم يسجّل أحد وصوله';

  @override
  String get seasonMapIncident => 'بلاغ مفتوح';

  @override
  String get seasonMapEmpty => 'بلا أعضاء';

  @override
  String get seasonMapPosted => 'مُسنَد إليه';

  @override
  String get seasonMapPresent => 'سجّل وصوله';

  @override
  String get seasonMapOpenIncidents => 'بلاغ مفتوح';

  @override
  String get seasonMapCopyCoordinates => 'نسخ الإحداثيات';

  @override
  String get seasonMapCoordinatesCopied => 'نُسخت الإحداثيات';

  @override
  String get seasonMapPlaces => 'الأماكن';

  @override
  String get seasonMapIncidents => 'البلاغات';

  @override
  String seasonMapCounts(int places, int incidents) {
    return '$places مكاناً · $incidents بلاغاً';
  }

  @override
  String get seasonMapEmptyState => 'لا مكان محدّد الموقع في هذا الموسم';

  @override
  String get seasonMapEmptyStateHint =>
      'يظهر المكان على الخريطة حين يُحدَّد موقعه في قائمة الفنادق أو المخيمات';

  @override
  String get incidentTitle => 'بلاغ عاجل';

  @override
  String get incidentHint =>
      'لما لا يحتمل الانتظار — عطل، حادث، انقطاع. يصل فوراً إلى غرفة العمليات.';

  @override
  String get incidentBodyHint => 'ما الذي حدث؟';

  @override
  String get incidentAttach => 'إرفاق صورة';

  @override
  String get incidentSend => 'أرسل البلاغ';

  @override
  String get incidentSending => 'جارٍ الإرسال…';

  @override
  String get incidentSent => 'وصل البلاغ إلى غرفة العمليات';

  @override
  String get incidentWhatIsAttached =>
      'يُرفق تلقائياً: اسمك، وموقعك، ووقت البلاغ';

  @override
  String get incidentAbout => 'عن ماذا؟ (اختياري)';

  @override
  String get incidentAboutKind => 'بمَ يتعلّق البلاغ؟';

  @override
  String get incidentAboutModule => 'ملف تشغيلي';

  @override
  String get incidentAboutEmployee => 'موظف';

  @override
  String get incidentAboutPage => 'صفحة في التطبيق';

  @override
  String get incidentAboutClear => 'بلا تحديد';

  @override
  String get incidentAboutNoModules => 'لا ملفات تشغيلية في الموسم الحالي';

  @override
  String get incidentAboutNoSeason => 'تعذّر تحديد الموسم الحالي';

  @override
  String incidentAboutLabel(String what) {
    return 'البلاغ عن: $what';
  }

  @override
  String get incidentOpenPage => 'افتح الصفحة';

  @override
  String get incidentOpenModule => 'افتح الملف التشغيلي';

  @override
  String get incidentNotInRegister => 'لم يعد هذا البلاغ في السجل';

  @override
  String get incidentsShowAll => 'عرض السجل كامل';

  @override
  String get incidentsOneReport => 'بلاغ واحد';

  @override
  String get incidentNotDeliveredTitle => 'لم يصل البلاغ';

  @override
  String get incidentNotDeliveredBody =>
      'لا توجد شبكة. حُفظ البلاغ على جهازك وسيُرسل تلقائياً عند عودتها — لكن **لم يُبلَّغ أحد بعد**. إن كان الأمر لا يحتمل، اتصل بغرفة العمليات هاتفياً الآن.';

  @override
  String get incidentsTitle => 'البلاغات العاجلة';

  @override
  String get incidentsEmpty => 'لا بلاغات مفتوحة';

  @override
  String get incidentsEmptyHint => 'يظهر هنا كل بلاغ عاجل فور وصوله';

  @override
  String get incidentsShowClosed => 'إظهار المغلقة';

  @override
  String get incidentStateOpen => 'مفتوح';

  @override
  String get incidentStateInProgress => 'قيد المعالجة';

  @override
  String get incidentStateClosed => 'مغلق';

  @override
  String get incidentTake => 'أتولّاه';

  @override
  String get incidentClose => 'إغلاق البلاغ';

  @override
  String get incidentReopen => 'إعادة فتحه';

  @override
  String get incidentResolutionHint => 'ماذا جرى؟ (اختياري)';

  @override
  String get incidentCall => 'اتصال';

  @override
  String get incidentOpenMap => 'الموقع';

  @override
  String incidentWaited(String duration) {
    return 'منتظر منذ $duration';
  }

  @override
  String incidentHandledBy(String name) {
    return 'تولّاه $name';
  }

  @override
  String incidentOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count بلاغاً مفتوحاً',
      few: '$count بلاغات مفتوحة',
      two: 'بلاغان مفتوحان',
      one: 'بلاغ واحد مفتوح',
      zero: 'لا بلاغات مفتوحة',
    );
    return '$_temp0';
  }

  @override
  String get attachmentPickFailed =>
      'تعذّر فتح المُنتقي. جرّب طريقة أخرى للإرفاق.';

  @override
  String get incidentDelete => 'حذف البلاغ';

  @override
  String get incidentDeleteConfirm =>
      'يُحذف البلاغ وما أُرفق به نهائياً، ويختفي من سجل الجميع. لا يمكن التراجع.';

  @override
  String get incidentDeleted => 'حُذف البلاغ';

  @override
  String get incidentsClear => 'تفريغ السجل';

  @override
  String get incidentsClearWhat => 'ما الذي يُحذف؟';

  @override
  String get incidentsClearClosed => 'المغلقة فقط';

  @override
  String get incidentsClearClosedHint =>
      'يبقى كل بلاغ مفتوح أو قيد المعالجة كما هو';

  @override
  String get incidentsClearAll => 'كل البلاغات';

  @override
  String get incidentsClearAllHint =>
      'بما فيها المفتوحة — تختفي من شاشة كل من يتابع السجل الآن';

  @override
  String incidentsCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حُذف $count بلاغاً',
      few: 'حُذفت $count بلاغات',
      two: 'حُذف بلاغان',
      one: 'حُذف بلاغ واحد',
      zero: 'لم يُحذف شيء',
    );
    return '$_temp0';
  }

  @override
  String get incidentAlarmTitle => 'بلاغ عاجل';

  @override
  String get incidentAlarmOpen => 'افتح السجل';

  @override
  String get incidentAlarmDismiss => 'إغلاق';

  @override
  String incidentAlarmMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$count بلاغاً آخر',
      few: 'و$count بلاغات أخرى',
      two: 'وبلاغان آخران',
      one: 'وبلاغ آخر',
    );
    return '$_temp0';
  }

  @override
  String get navMyIncidentsSubtitle => 'ما رفعته من بلاغات عاجلة، وحالتها الآن';

  @override
  String get myIncidentsTitle => 'بلاغاتي';

  @override
  String get myIncidentsEmpty => 'لم ترفع أي بلاغ عاجل بعد';

  @override
  String get myIncidentsEmptyHint =>
      'بلاغاتك العاجلة تظهر هنا فور رفعها، مع حالتها الآن';

  @override
  String durationMinutes(int count) {
    return '$count د';
  }

  @override
  String durationHours(int count) {
    return '$count س';
  }

  @override
  String get checkInScanTitle => 'امسح رمز المكان';

  @override
  String get checkInScanHint => 'وجّه الكاميرا إلى الرمز الملصق على المكان';

  @override
  String get checkInTorch => 'الإضاءة';

  @override
  String get checkInNoCamera => 'تعذّر فتح الكاميرا — قد تكون الصلاحية مرفوضة';

  @override
  String get checkInNoCameraHint =>
      'تسجيل الوصول يحتاج مسح الرمز وتفعيل الموقع معاً، فلا سبيل إليه بلا كاميرا';

  @override
  String get checkInTitle => 'تسجيل الوصول';

  @override
  String get checkInAction => 'سجّل وصولي';

  @override
  String get checkInSubtitle =>
      'امسح الرمز الملصق على الفندق أو المخيم وأنت واقف عنده';

  @override
  String get checkInPhoneOnly =>
      'تسجيل الوصول من الهاتف وحده — يحتاج كاميرا تمسح رمز المكان وأنت واقف عنده. سجلّك أدناه مقروء من أي جهاز.';

  @override
  String get checkInScan => 'مسح الرمز';

  @override
  String get checkInNoteHint => 'ملاحظة (اختياري)';

  @override
  String get checkInDone => 'سُجّل وصولك';

  @override
  String checkInDoneAt(String place, String metres) {
    return 'سُجّل وصولك — $place، على بعد $metres م';
  }

  @override
  String get checkInQueued => 'حُفظ على الجهاز — سيُسجَّل عند عودة الشبكة';

  @override
  String checkInDistance(String metres) {
    return 'على بعد $metres م';
  }

  @override
  String get checkInNotApproved => 'حسابك غير معتمد بعد، فلا يمكن تسجيل الوصول';

  @override
  String get checkInNotAPlace => 'هذا الرمز لا يخصّ مكاناً قائماً';

  @override
  String get checkInNeedsAPosition =>
      'لم يُسجَّل: فعّل خدمة الموقع ثم امسح الرمز من جديد';

  @override
  String get checkInCodeExpired =>
      'هذا الرمز لم يعد صالحاً — ابحث عن الرمز الجديد الملصق مكانه';

  @override
  String get checkInPlaceHasNoLocation =>
      'لم يُحدَّد موقع هذا المكان بعد، فلا يمكن التحقق من قربك منه. أبلغ الإدارة.';

  @override
  String get checkInTooFar =>
      'أنت بعيد عن هذا المكان — يجب أن تكون عنده لتسجّل وصولك';

  @override
  String get checkInCodesDenied => 'لا تملك صلاحية عرض رموز الأماكن';

  @override
  String get checkInRotateDenied => 'لا تملك صلاحية تجديد رموز الأماكن';

  @override
  String get checkInQrTitle => 'رمز المكان';

  @override
  String get checkInQrHint =>
      'اطبع هذا الرمز وألصقه في المكان — يمسحه من يصل فيسجّل وصوله';

  @override
  String get checkInQrPrint => 'طباعة أو مشاركة';

  @override
  String get checkInQrShare => 'مشاركة';

  @override
  String get checkInQrShareFailed => 'تعذّرت المشاركة — استخدم الطباعة';

  @override
  String get checkInQrSave => 'حفظ على الجهاز';

  @override
  String checkInQrSaved(String path) {
    return 'حُفظ في $path';
  }

  @override
  String get checkInQrSavedPlain => 'حُفظ الملف';

  @override
  String get checkInQrSaveFailed => 'تعذّر الحفظ';

  @override
  String checkInQrRotatesOn(String when) {
    return 'يتجدّد تلقائياً: $when';
  }

  @override
  String checkInQrRotatesSoon(String when) {
    return 'يتجدّد تلقائياً في $when — اطبع البديل وألصقه قبل ذلك اليوم، وإلا تعذّر تسجيل الوصول هنا';
  }

  @override
  String get checkInQrCard => 'رمز تسجيل الوصول';

  @override
  String checkInQrRotatedAt(String when) {
    return 'آخر تجديد: $when';
  }

  @override
  String get checkInQrNoLocation =>
      'لا موقع لهذا المكان — لن يستطيع أحد تسجيل وصوله إليه حتى يُحدَّد';

  @override
  String get checkInQrRotate => 'تجديد الرمز';

  @override
  String get checkInQrRotateConfirm =>
      'سيتوقف كل رمز مطبوع لهذا المكان عن العمل فوراً. لا بدّ من طباعة الرمز الجديد وإلصاقه قبل أن يتمكّن أحد من تسجيل وصوله هنا.';

  @override
  String get checkInQrRotated => 'جُدّد الرمز — اطبعه وألصقه الآن';

  @override
  String get checkInQrPrintAll => 'طباعة رموز القائمة';

  @override
  String get checkInQrPrintingAll => 'يجري تجهيز الرموز…';

  @override
  String get navMyCheckInsSubtitle => 'أين سجّلتَ وصولك ومتى — ومن هنا تسجّل';

  @override
  String get myCheckInsTitle => 'سجلّ حضوري';

  @override
  String get myCheckInsEmpty => 'لم تسجّل وصولك بعد';

  @override
  String get myCheckInsEmptyHint =>
      'امسح رمز المكان بالزر في الأسفل وأنت واقف عنده، فيظهر هنا';

  @override
  String get myCheckInsWindowDay => 'اليوم';

  @override
  String get myCheckInsWindowWeek => 'الأسبوع';

  @override
  String get myCheckInsWindowAll => 'الكل';

  @override
  String get myCheckInsAllPlaces => 'كل الأماكن';

  @override
  String myCheckInsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تسجيل',
      many: '$count تسجيلاً',
      few: '$count تسجيلات',
      two: 'تسجيلان',
      one: 'تسجيل واحد',
      zero: 'لا تسجيل',
    );
    return '$_temp0';
  }

  @override
  String get presenceTitle => 'سجل الدوام';

  @override
  String get presenceSubtitle => 'آخر تسجيلات الوصول في أماكن الموسم';

  @override
  String get presenceEmpty => 'لم يسجّل أحد وصوله بعد';

  @override
  String get presenceTabPresent => 'الحاضرون';

  @override
  String get presenceTabGaps => 'لم يسجّلوا';

  @override
  String get presenceGapsEmpty => 'كل موقع مؤكَّد';

  @override
  String get presenceGapsEmptyHint =>
      'لا منصب على مكان بلا تسجيل خلال المدة المختارة';

  @override
  String get presenceGapNeverSeen => 'لم يسجّل قط';

  @override
  String presenceGapLastSeen(String time) {
    return 'آخر تسجيل $time';
  }

  @override
  String presenceGapCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count موقع',
      many: '$count موقعاً',
      few: '$count مواقع',
      two: 'موقعان',
      one: 'موقع واحد',
      zero: 'لا شيء',
    );
    return '$_temp0';
  }

  @override
  String get presenceEmptyHint => 'يظهر هنا من مسح رمز مكان وهو واقف عنده';

  @override
  String get presenceWindow4h => '٤ ساعات';

  @override
  String get presenceWindow12h => '١٢ ساعة';

  @override
  String get presenceWindow24h => '٢٤ ساعة';

  @override
  String presenceCounts(int people, int places) {
    return '$people شخصاً في $places مكاناً';
  }

  @override
  String get exportTitle => 'تصدير البيانات';

  @override
  String get exportSubtitle => 'أخرج أي قائمة كملف — بالأعمدة التي تختارها';

  @override
  String get exportWhat => 'ما الذي تريد تصديره؟';

  @override
  String get exportPickFirst => 'اختر جدولاً من الأعلى';

  @override
  String get exportPickFirstHint =>
      'بعد الاختيار يظهر هنا ما يمكن أخذه منه، وصيغة الملف، وزرّا الحفظ والإرسال.';

  @override
  String get exportWhichColumns => 'الأعمدة';

  @override
  String get exportWholeRecord => 'يُصدَّر كاملاً';

  @override
  String get exportWholeRecordHint =>
      'لا أعمدة تُختار هنا: المستند نصٌّ كُتب بترتيبه، فيُطبع كاملاً — بياناته، ومحتواه كتلةً كتلة، وجداوله، وما أُرفق به.';

  @override
  String get exportColumnsDefault => 'الافتراضية';

  @override
  String get exportColumnsAll => 'الكل';

  @override
  String get exportPickAtLeastOne => 'اختر عموداً واحداً على الأقل';

  @override
  String exportSensitiveNotice(String column) {
    return '«$column» بيانٌ داخلي: من يحمله يستطيع أن يربط الشخص بسجلّاته في أي جدولٍ آخر. الملف يخرج باسمك ويبقى بعد إغلاق الشاشة — فليصل إلى من يحتاجه وحده.';
  }

  @override
  String get exportOptionAny => 'اتركه فارغاً ليشمل الجميع';

  @override
  String get exportFormat => 'صيغة الملف';

  @override
  String get exportFormatCsv => 'CSV (إكسل)';

  @override
  String get exportFormatPdf => 'PDF (للطباعة)';

  @override
  String get exportSave => 'حفظ في الجهاز';

  @override
  String get exportShare => 'مشاركة';

  @override
  String exportSavedTo(String path) {
    return 'حُفظ في $path';
  }

  @override
  String get exportSaveFailed => 'تعذّر الحفظ';

  @override
  String get exportRunning => 'جارٍ التحضير…';

  @override
  String exportDoneRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'صُدِّر $count سطراً',
      few: 'صُدِّرت $count أسطر',
      two: 'صُدِّر سطران',
      one: 'صُدِّر سطر واحد',
    );
    return '$_temp0';
  }

  @override
  String exportDoneRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'صُدِّر $count سجلّاً كاملاً',
      few: 'صُدِّرت $count سجلّات كاملة',
      two: 'صُدِّر سجلّان كاملان',
      one: 'صُدِّر سجلّ واحد كاملاً',
    );
    return '$_temp0';
  }

  @override
  String get exportNothingMatched =>
      'لا توجد بيانات مطابقة — راجع الخيارات أعلاه';

  @override
  String get exportNothingAvailable => 'لا يوجد ما يمكن تصديره';

  @override
  String get exportNothingAvailableHint =>
      'التصدير متاح لما تملك صلاحية الاطلاع عليه';

  @override
  String get exportGeneratedBy => 'مستخرج من نظام إدارة بعثة الحج';

  @override
  String get exportPage => 'صفحة';

  @override
  String get accountStatusIncomplete => 'غير مكتمل';

  @override
  String get accountStatusPending => 'قيد الانتظار';

  @override
  String get accountStatusApproved => 'معتمد';

  @override
  String get accountStatusRejected => 'مرفوض';

  @override
  String get outboxSavedOffline => 'حُفظ على الجهاز — سيُرسل عند عودة الشبكة';

  @override
  String offlineShowingSaved(String time) {
    return 'لا توجد شبكة — معروضٌ من نسخة محفوظة، آخر تحديث $time';
  }

  @override
  String get outboxTitle => 'بانتظار الإرسال';

  @override
  String get outboxEmpty => 'لا شيء بانتظار الإرسال';

  @override
  String get outboxEmptyHint => 'كل ما كتبته وصل إلى الخادم';

  @override
  String outboxPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر بانتظار الإرسال',
      many: '$count عنصراً بانتظار الإرسال',
      few: '$count عناصر بانتظار الإرسال',
      two: 'عنصران بانتظار الإرسال',
      one: 'عنصر واحد بانتظار الإرسال',
    );
    return '$_temp0';
  }

  @override
  String get outboxStateWaiting => 'بانتظار الشبكة';

  @override
  String get outboxStateSending => 'جارٍ الإرسال…';

  @override
  String get outboxStateBlocked => 'لم يُقبل';

  @override
  String outboxAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محاولة',
      few: '$count محاولات',
      two: 'محاولتان',
      one: 'محاولة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get outboxRetry => 'إعادة المحاولة';

  @override
  String get outboxDiscard => 'حذف';

  @override
  String get outboxDiscardTitle => 'حذف هذا العنصر؟';

  @override
  String get outboxDiscardBody => 'لن يصل إلى الخادم، ولا يمكن استرجاعه.';

  @override
  String get outboxKindTaskState => 'حالة مهمة';

  @override
  String get outboxKindReport => 'تقرير ملف';

  @override
  String outboxBlockedNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصراً لم يُقبل',
      few: '$count عناصر لم تُقبل',
      two: 'عنصران لم يُقبلا',
      one: 'عنصر واحد لم يُقبل',
    );
    return '$_temp0';
  }

  @override
  String get settingsInApp => 'داخل التطبيق';

  @override
  String get sidebarExpand => 'توسيع الشريط الجانبي';

  @override
  String get sidebarCollapse => 'طيّ الشريط الجانبي';

  @override
  String get sidebarMenu => 'القائمة';

  @override
  String get roadmapTitle => 'الخريطة التشغيلية';

  @override
  String get roadmapIntroTitle => 'كيف يُدار الموسم';

  @override
  String get roadmapIntroBody =>
      'كل شاشة أخرى في هذا التطبيق تُجيب عن سؤال «أين»، وهذه تُجيب عن سؤال «متى». الموسم مرسومٌ أدناه من الأسبوع الذي يسبق افتتاحه إلى الأسبوع الذي يلي إغلاقه: خمس مراحل، وكل خطوة تقول ما يُصنع فيها وعلى أي شيء تنتظر. والخريطة مرسومةٌ كاملة للجميع — وما ليس من عملك مُعلَّمٌ بذلك، لأن معرفتك أن أحداً كان عليه أن يعبّئ البيانات المرجعية قبل أن يوجد ملفك هي جزءٌ من معرفتك موقعك أنت من الموسم.';

  @override
  String get roadmapOpen => 'افتح';

  @override
  String get roadmapLocked => 'بيد الإدارة';

  @override
  String get roadmapEveryone => 'مفتوحة للجميع';

  @override
  String roadmapPhaseLabel(int number) {
    return 'المرحلة $number';
  }

  @override
  String roadmapStepsOpen(int open, int total) {
    return '$open من $total خطوة بيدك';
  }

  @override
  String get roadmapPhaseSetup => 'تهيئة الأرض';

  @override
  String get roadmapPhaseSetupWhen => 'قبل الموسم بأسابيع';

  @override
  String get roadmapPhaseSetupBody =>
      'لا شيء في هذا التطبيق يقوم وحده: كل ملف وكل مهمة وكل بلاغ عاجل يُقيَّد على موسم، ويُبنى من القوائم المرجعية. تُضبط هذه المرحلة مرةً في السنة، وكل ما بعدها يقوم عليها.';

  @override
  String get roadmapPhaseBuild => 'بناء العمل';

  @override
  String get roadmapPhaseBuildWhen => 'الشهر السابق';

  @override
  String get roadmapPhaseBuildBody =>
      'الورق الذي سيُشتغل الموسم به فعلاً: أي الملفات تُفتح، ومن فيها وبأي دور، وما الذي يُكلَّف به كل شخص، وما الذي تُبلَّغ به البعثة كلها.';

  @override
  String get roadmapPhaseRun => 'تشغيل الموسم';

  @override
  String get roadmapPhaseRunWhen => 'ذو الحجة نفسه';

  @override
  String get roadmapPhaseRunBody =>
      'المرحلة الوحيدة التي يمسّها أكثر أهل البعثة، والوحيدة التي تُقاس بالساعات لا بالأسابيع. وكل ما فيها مفتوحٌ للجميع، وهذا طبعها كله: الموسم لا يُدار بأصحاب الصلاحيات، بل بمن يقف في منى الثالثة فجراً.';

  @override
  String get roadmapPhaseWatch => 'المتابعة والإشراف';

  @override
  String get roadmapPhaseWatchWhen => 'بالتوازي مع المرحلة التي فوقها';

  @override
  String get roadmapPhaseWatchBody =>
      'نصيب غرفة العمليات من الأيام نفسها. بعضه الموسم منظوراً إليه كاملاً وهو لا يزال يتحرك، وبقيته تُقرأ بعد وقوعها، فعلاً فعلاً.';

  @override
  String get roadmapPhaseClose => 'إغلاق السنة';

  @override
  String get roadmapPhaseCloseWhen => 'الأسابيع التالية';

  @override
  String get roadmapPhaseCloseBody =>
      'ما يُحصد من الموسم بعد أن تعود الحافلات: العلامات التي طُلب من الناس أن يكتبوها، والسجلات التي تُخرَج من التطبيق، والسنة التي تُطوى ليُفتح ما بعدها.';

  @override
  String get roadmapStepSeason =>
      'سمِّ السنة التي تعمل عليها الإدارة واجعلها الموسم الحالي. كل ملف ومهمة وتقرير وحضور يأتي بعدها يُقيَّد عليها، ولهذا لا يمكن أن يسبقها شيء آخر في هذه الخريطة.';

  @override
  String get roadmapNoteSeason =>
      'موسمٌ واحد يكون حالياً في كل وقت، وتغييره يغيّر ما تعرضه كل شاشة أخرى في التطبيق.';

  @override
  String get roadmapStepReference =>
      'القوائم التي يُركَّب منها كل ما سواها: الفنادق والتجمّعات وأماكن المشاعر وبقية البيانات المرجعية. الملف يذكر اسم فندق ولا يصفه، ففندقٌ ليس في هذه القائمة لا يمكن وضعه في ملف.';

  @override
  String get roadmapNoteReference =>
      'لا يصير المكان قابلاً للمسح إلا بعد أن يكون هنا بموقعه ونصف قطره — وهذا ما يجعل تسجيل الحضور ممكناً أصلاً.';

  @override
  String get roadmapStepApprovals =>
      'لا يصل أحدٌ إلى التطبيق قبل اعتماد حسابه. تصطفّ التسجيلات هنا، فيُقبل كلٌّ منها أو يُرفض أو يُترك منتظراً.';

  @override
  String get roadmapStepEmployees =>
      'من يعمل في هذا الموسم: بياناتهم وصورهم والأرقام التي يُوصل إليهم عبرها. تُملأ هنا مرةً، وتقرؤها منها كل شاشة أخرى تحتاج أن تتصل بأحد.';

  @override
  String get roadmapStepPermissions =>
      'ما يجوز لكل شخص فعله. الاعتماد يُدخِل الشخص، وهذه تقرّر ما الذي يجده بعد دخوله — والأقسام التي لا يُمنحها تبقى مخفيّةً ومغلقةً معاً.';

  @override
  String get roadmapNotePermissions =>
      'الصلاحية الممنوحة الآن تصل صاحبها عند تحديث جلسته القادم — وسحبةٌ على أي قائمة تكفي.';

  @override
  String get roadmapStepFiles =>
      'افتح ملفات الموسم التشغيلية، وضع الناس فيها، وأعطِ كلاً منهم دوره. هذه هي الخطوة التي تحوّل دليل موظفين إلى تنظيم: الملف يصل أعضاءه بالإسناد، وهنا يقع الإسناد.';

  @override
  String get roadmapNoteFiles =>
      'العضو يرى الملف لأنه وُضع فيه، لا لأنه يملك صلاحية — ولهذا لا بد أن يُبنى كل ملف هنا قبل أن يعمل عليه أحد.';

  @override
  String get roadmapStepAssign =>
      'اكتب المهام على قوائم الآخرين وتابعها. وهي منفصلة عن الملفات عمداً: المهمة تُوجَّه إلى شخص لا إلى مجلد، وأكثرها لا ملف خلفه أصلاً.';

  @override
  String get roadmapStepForms =>
      'اكتب أوراق التقييم التي سيُحاكم بها الموسم: مراحلها وأسئلتها ودرجة كلٍّ منها. تُكتب قبل أن يُطلب من أحد تعبئتها، لأن الورقة لا تتغيّر تحت علامةٍ أُعطيت.';

  @override
  String get roadmapNoteForms =>
      'كتابة الأسئلة وقراءة الأجوبة أمانتان مختلفتان، وصلاحيتان مختلفتان.';

  @override
  String get roadmapStepCirculars =>
      'أدخِل وانشر القرارات والجداول والتعميمات التي تقرؤها البعثة كلها — مواعيد الوجبات، وأوامر التحرّك، وكل ما يجب أن يصل الجميع دفعةً واحدة.';

  @override
  String get roadmapStepMyFiles =>
      'الملفات التي وُضعت فيها، ودورك في كلٍّ منها. مهما كانت رتبتك فهذه تعرض عملك أنت: أن يُسمح لك بفتح كل ملف لا يجعل كل ملف ملفك.';

  @override
  String get roadmapStepMyTasks =>
      'قائمتك أنت، وما كتبه غيرك عليها. علّم المهمة منجزةً أولاً بأول لا في آخر اليوم — فشاشات المتابعة تقرأ هذا بعينه.';

  @override
  String get roadmapNoteOffline =>
      'ما كُتب بلا شبكة يُحفظ في الجهاز ويُرسَل وحده حين تعود. فلا تكتبه مرتين.';

  @override
  String get roadmapStepCheckIn =>
      'امسح الرمز المثبَّت في المكان فيُسجَّل حضورك فيه بوقته ومكانه. وسِجلّك الخاص تقرؤه أنت من أي جهاز.';

  @override
  String get roadmapNoteCheckIn =>
      'يُتحقَّق من موضع الهاتف كما يُتحقَّق من الرمز، فلا يُسجَّل حضورٌ من الطرف الآخر من الشارع.';

  @override
  String get roadmapStepIncident =>
      'قل إن شيئاً قد ساء — حافلة تعطّلت، أو حاج ضاع، أو فندق رفض مجموعة — فيصل إلى غرفة العمليات فوراً. وله زرٌّ أحمر في كل شاشة تقريباً.';

  @override
  String get roadmapNoteIncident =>
      'مفتوحٌ للجميع عمداً: نظامٌ لا يُبلَّغ فيه عن حافلة معطّلة إلا بصلاحية هو نظامٌ لا يعرف بالحافلة.';

  @override
  String get roadmapStepReadCirculars =>
      'ما نشرته الإدارة على البعثة كلها في هذا الموسم. تُقرأ ولا تُكتب — وكتابتها هي الخطوة التي فوقها، في يدٍ أخرى.';

  @override
  String get roadmapStepComplain =>
      'قدّم شكوى واقرأ ما عاد عليها. والشكوى ليست صلاحيةً يمنحها أحد، فهذه مفتوحة لكل حساب معتمد.';

  @override
  String get roadmapStepDashboard =>
      'الموسم من فوق: كم ملفاً يعمل، ومن أين، وما الذي لا يزال منتظراً. وكل قسمٍ فيها يُجيب عن نفسه، فترى ما تملكه منها لا غير.';

  @override
  String get roadmapStepMap =>
      'الموسم مرسوماً على الأرض — الفنادق والمخيّمات وأماكن المشاعر، وما يجري في كلٍّ منها.';

  @override
  String get roadmapStepPresence =>
      'من هو حاضر، في كل مكان، الآن. الخريطة تقول أين الأماكن، وهذه تقول من يقف فيها.';

  @override
  String get roadmapStepIncidents =>
      'سجلّ البلاغات العاجلة وهي تصل. وهي شاشة الإشراف الوحيدة في التطبيق التي تُقرأ والأمر الذي تتحدث عنه لا يزال يقع.';

  @override
  String get roadmapStepComplaints =>
      'كل شكوى قُدّمت في البعثة: تُردّ عليها، أو تُصرف، أو تُقفل بعد تسويتها.';

  @override
  String get roadmapNoteComplaints =>
      'الشكوى قد تتصاعد إلى حساب صاحبها بلا تدخّل بشري، ولهذا يقف السجلّ مع الأشخاص لا مع الملفات.';

  @override
  String get roadmapStepAudit =>
      'الموسم فعلاً فعلاً: من فعل ماذا، ومتى. اللوحة هي الموسم من فوق، وهذا هو الموسم نفسه من الجانب.';

  @override
  String get roadmapStepEvaluate =>
      'عبّئ التقييمات التي طُلبت منك. تصلك بالاسم لا بالصلاحية، فتكون هذه القائمة فارغةً لمن لم يُطلب منه شيء — وهذا هو الجواب الصادق، لا بابٌ ناقص.';

  @override
  String get roadmapNoteEvaluate =>
      'ما كُتب عنك ليس هنا. هو في صفحتك أنت، ويصلك بلا اسم كاتبه.';

  @override
  String get roadmapStepExport =>
      'أخرِج أي قائمة من التطبيق ملفاً، بالأعمدة التي تختارها — لتقرير، أو لأرشيف، أو لأي عمل يُصنع خارج التطبيق.';

  @override
  String get roadmapStepArchiveTitle => 'إغلاق السنة وفتح التالية';

  @override
  String get roadmapStepArchive =>
      'لا يُحذف شيء في آخر الموسم. تتوقّف السنة عن كونها الحالية فتصير أرشيفاً، ويُفتح موسمٌ جديد بجانبها — وهذا يعيدك إلى أول خطوة في هذه الخريطة.';

  @override
  String get roadmapNoteArchive =>
      'كل ما قُيّد على موسم ماضٍ يبقى مقروءاً كما كُتب تماماً. وإغلاق السنة لا يُخفي شيئاً.';

  @override
  String get navMyJourney => 'مساري';

  @override
  String get navMyJourneySubtitle =>
      'رحلة قدومك وتنقّلاتك وموعد عودتك، من البداية إلى النهاية.';

  @override
  String get navTravel => 'السفر والتنقّل';

  @override
  String get navTravelSubtitle =>
      'رحلات الموسم وحركات التنقّل، وإسناد الموظفين إليها.';

  @override
  String get perm_travel => 'السفر والتنقّل';

  @override
  String get permTravelView => 'قراءة مسار سفر زميل في صفحته';

  @override
  String get permTravelViewAll => 'قراءة رحلات الموسم كلها';

  @override
  String get permTravelEdit => 'إنشاء الرحلات وتعديل بياناتها';

  @override
  String get permTravelAssign => 'إسناد الموظفين إلى الرحلات ونقلهم بينها';

  @override
  String get permTravelConfirm => 'تسجيل ما حدث فعلاً — المغادرة والوصول';

  @override
  String get permTravelDelete => 'حذف رحلة';

  @override
  String get travelMyJourneyTitle => 'مساري';

  @override
  String get travelJourneyTitle => 'مسار الرحلة';

  @override
  String get travelSectionTitle => 'السفر والتنقّل';

  @override
  String get travelViewFullJourney => 'عرض المسار الكامل';

  @override
  String get travelNoJourney => 'لم يُسجَّل أي سفر لهذا الموسم بعد';

  @override
  String get travelNoJourneyHint =>
      'تظهر هنا رحلة القدوم وحركات التنقّل ورحلة العودة فور تسجيلها.';

  @override
  String get travelNotInSeason => 'هذا الحساب ليس ضمن مشاركي الموسم الحالي';

  @override
  String travelCurrentlyIn(String place) {
    return 'الآن في $place';
  }

  @override
  String get travelCurrentLocation => 'الموقع الحالي';

  @override
  String travelDays(int count) {
    return '$count يوماً';
  }

  @override
  String travelDaysSoFar(int count) {
    return '$count يوماً حتى الآن';
  }

  @override
  String travelSince(String date) {
    return 'منذ $date';
  }

  @override
  String get travelStayPlaceTitle => 'مكان الإقامة';

  @override
  String get travelStayHome => 'الوطن';

  @override
  String get travelStayResidence => 'إقامة';

  @override
  String get travelStayRites => 'المشاعر';

  @override
  String get travelHereNow => 'هنا الآن';

  @override
  String get travelSeasonBreakdown => 'أين قضيت الموسم';

  @override
  String get travelSeasonBreakdownHint => 'أيام الإقامة في كل مدينة';

  @override
  String get travelNotDepartedYet => 'لم تبدأ الرحلة بعد';

  @override
  String get travelJourneyComplete => 'انتهت الرحلة';

  @override
  String travelDayOf(int day) {
    return 'اليوم $day من الرحلة';
  }

  @override
  String travelSinceDays(int days) {
    return 'منذ $days يوماً';
  }

  @override
  String travelReturnIn(int days) {
    return 'العودة بعد $days يوماً';
  }

  @override
  String get travelReturnTomorrow => 'العودة غداً';

  @override
  String get travelReturnToday => 'العودة اليوم';

  @override
  String get travelReturnPassed => 'مضى موعد العودة';

  @override
  String get travelNoReturnYet => 'لم تُحدَّد رحلة العودة بعد';

  @override
  String get travelNoReturnYetHint =>
      'تُحدَّد رحلة العودة عادةً قبل موعدها بأيام قليلة.';

  @override
  String travelBetween(String from, String to) {
    return 'من $from إلى $to';
  }

  @override
  String get travelUntrackedTransferOptional =>
      'لم تُسجَّل وسيلة الانتقال — اختياري';

  @override
  String get travelRecordTransferShort => 'تسجيل';

  @override
  String get travelUntrackedTransfer => 'لم تُسجَّل وسيلة الانتقال';

  @override
  String get travelRecordTransfer => 'تسجيل وسيلة الانتقال';

  @override
  String get travelSelfArranged => 'ترتيب ذاتي';

  @override
  String get travelConfirmArrival => 'تأكيد الوصول';

  @override
  String travelConfirmedBy(String name) {
    return 'أكّدها $name';
  }

  @override
  String get travelNeedsYourWord => 'لا مصدر آلي لهذه الحركة — تأكيدها بيدك';

  @override
  String travelPlannedAt(String time) {
    return 'المخطط $time';
  }

  @override
  String travelActualAt(String time) {
    return 'الفعلي $time';
  }

  @override
  String travelDepartedAt(String time) {
    return 'غادر $time';
  }

  @override
  String travelArrivedAt(String time) {
    return 'وصل $time';
  }

  @override
  String get travelRoleInbound => 'رحلة القدوم';

  @override
  String get travelRoleInternal => 'تنقّل داخلي';

  @override
  String get travelRoleOutbound => 'رحلة العودة';

  @override
  String get travelModeAir => 'طيران';

  @override
  String get travelModeRail => 'قطار';

  @override
  String get travelModeRoad => 'برّاً';

  @override
  String get travelModeOther => 'وسيلة أخرى';

  @override
  String get travelLegPlanned => 'مخطط';

  @override
  String get travelLegConfirmed => 'مؤكَّد';

  @override
  String get travelLegCompleted => 'تم';

  @override
  String get travelLegMissed => 'لم يسافر';

  @override
  String get travelLegCancelled => 'أُلغيت';

  @override
  String get travelLegRebooked => 'نُقل إلى غيرها';

  @override
  String get travelTripState => 'حالة الرحلة';

  @override
  String get travelTripScheduled => 'في موعدها';

  @override
  String get travelTripDelayed => 'متأخرة';

  @override
  String get travelTripDeparted => 'غادرت';

  @override
  String get travelTripArrived => 'وصلت';

  @override
  String get travelTripCancelled => 'ملغاة';

  @override
  String get travelTripsTitle => 'رحلات الموسم';

  @override
  String get travelNewTrip => 'رحلة جديدة';

  @override
  String get travelEditTrip => 'تعديل الرحلة';

  @override
  String get travelTripDetailTitle => 'تفاصيل الرحلة';

  @override
  String get travelNoTrips => 'لا رحلات في هذا الموسم بعد';

  @override
  String get travelNoTripsHint =>
      'أنشئ رحلة، ثم أسند إليها الموظفين دفعةً واحدة.';

  @override
  String get travelNoTripsInRole => 'لا رحلات في هذا القسم بعد';

  @override
  String get travelNoTripsMatch => 'لا رحلة تطابق البحث';

  @override
  String travelAssignedCount(int count) {
    return '$count مسنَد';
  }

  @override
  String travelConfirmedOf(int done, int total) {
    return '$done من $total مؤكَّد';
  }

  @override
  String get travelAssign => 'إسناد موظفين';

  @override
  String get travelPassengers => 'الركّاب';

  @override
  String get travelNoPassengers => 'لم يُسند أحد إلى هذه الرحلة بعد';

  @override
  String travelAssignOutcome(int assigned, int rebooked, int skipped) {
    return 'أُسند $assigned، ونُقل $rebooked، وتُرك $skipped';
  }

  @override
  String travelAssignNotInSeason(int count) {
    return 'و$count ليسوا ضمن مشاركي الموسم';
  }

  @override
  String get travelConfirmAll => 'تأكيد وصول الجميع';

  @override
  String travelConfirmAllPrompt(int count) {
    return 'هل نعتبر الـ$count المسنَدين قد وصلوا؟ هذا تسجيلٌ لما حدث، ولا يقع تلقائياً.';
  }

  @override
  String get travelRemoveFromTrip => 'إزالة من الرحلة';

  @override
  String travelRemoveFromTripConfirm(String name) {
    return 'إزالة $name من هذه الرحلة؟ تُحفظ الحركة في السجل ولا تُحذف.';
  }

  @override
  String get travelCancelTrip => 'إلغاء الرحلة';

  @override
  String get travelDeleteTrip => 'حذف الرحلة';

  @override
  String get travelDeleteTripConfirm =>
      'حذف هذه الرحلة نهائياً؟ لا يمكن حذف رحلة عليها ركّاب — ألغِها بدلاً من ذلك.';

  @override
  String get travelFieldMode => 'الوسيلة';

  @override
  String get travelFieldRole => 'نوع الحركة';

  @override
  String get travelFieldFrom => 'من';

  @override
  String get travelFieldTo => 'إلى';

  @override
  String get travelFieldNumber => 'رقم الرحلة';

  @override
  String get travelFieldDeparture => 'موعد المغادرة';

  @override
  String get travelFieldArrival => 'موعد الوصول';

  @override
  String get travelFieldNote => 'ملاحظة';

  @override
  String get travelFieldTicket => 'رقم التذكرة';

  @override
  String get travelFieldSeat => 'المقعد';

  @override
  String get travelFieldRequired => 'هذا الحقل مطلوب';

  @override
  String get travelPickDateTime => 'اختر التاريخ والوقت';

  @override
  String get travelSameEndpoints =>
      'نقطة الانطلاق والوصول لا يمكن أن تكونا واحدة';

  @override
  String get travelMustStartWhereHeIs =>
      'تبدأ الحركة من حيث تركته الحركة السابقة';

  @override
  String get travelGapsTitle => 'ما لم يُجَب عنه';

  @override
  String get travelGapsClear => 'لا ثغرات — كل شيء مُجاب عنه';

  @override
  String get travelGapsClearHint =>
      'لا مشارك بلا رحلة، ولا حركة مضى موعدها بلا تأكيد.';

  @override
  String get travelGapNoInbound => 'بلا رحلة قدوم';

  @override
  String get travelGapNoOutbound => 'بلا رحلة عودة';

  @override
  String get travelGapUnconfirmed => 'مضى موعدها بلا تأكيد';

  @override
  String get travelGapCancelledTrip => 'على رحلة ملغاة';

  @override
  String get travelMarkDoesNotTravel => 'لا يسافر هذا الموسم';

  @override
  String travelMarkDoesNotTravelConfirm(String name) {
    return 'تعليم $name كمن لا يسافر هذا الموسم؟ يُرفع من هذه القائمة، ويبقى تسجيل أي حركة له ممكناً.';
  }

  @override
  String get travelRecordTitle => 'تسجيل حركة تنقّل';

  @override
  String get travelRecordSubtitle =>
      'للحركات التي رتّبها الموظف بنفسه — سيارة خاصة أو غيرها.';

  @override
  String get travelRecordAlreadyHappened => 'حدثت بالفعل';

  @override
  String get travelRecordSaved => 'سُجّلت الحركة';

  @override
  String get travelAttachments => 'المرفقات';

  @override
  String get travelNoAttachments => 'لا مرفقات';

  @override
  String get travelNoAttachmentsHint =>
      'أرفق تذكرة أو كشف ركّاب أو صورة — PDF أو صورة.';

  @override
  String get travelAddAttachment => 'إضافة مرفق';
}
