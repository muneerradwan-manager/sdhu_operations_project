// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hajj Operations';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonConnectionErrorTitle => 'Couldn\'t reach the server';

  @override
  String get commonConnectionErrorBody =>
      'Check your internet connection and try again.';

  @override
  String get commonGenericError => 'Something went wrong. Please try again.';

  @override
  String get commonLogout => 'Log out';

  @override
  String get commonLoggingOut => 'Signing out…';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonNext => 'Next';

  @override
  String get commonBack => 'Back';

  @override
  String get commonDone => 'Done';

  @override
  String get commonCopied => 'Copied';

  @override
  String get profileEmail => 'Email';

  @override
  String get commonMore => 'More';

  @override
  String get moduleNotifyMembers => 'Notify everyone in this file';

  @override
  String get employeeNotify => 'Send a notification';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonToday => 'Today';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsNotifications => 'Notifications on this device';

  @override
  String get settingsNotificationsHint =>
      'Turning this off only silences the device — messages still reach your inbox';

  @override
  String get settingsLogoutConfirm =>
      'Log out of this device? The account leaves the quick-switch list, and signing back in will ask for the password.';

  @override
  String get settingsSolidSurfaces => 'Solid surfaces';

  @override
  String get settingsSolidSurfacesHint =>
      'No transparency or blur — clearer in sunlight, lighter on slower phones';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get settingsGroupDevice => 'This device';

  @override
  String get settingsSwitchAccount => 'Switch to another account';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get authLoginTitle => 'Welcome back';

  @override
  String get authLoginSubtitle => 'Sign in to continue';

  @override
  String get authRegisterTitle => 'Create account';

  @override
  String get authRegisterSubtitle => 'Register with your email to get started';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignUp => 'Sign up';

  @override
  String get authOrContinueWith => 'or';

  @override
  String get authGoogle => 'Continue with Google';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authInvalidEmail => 'Enter a valid email';

  @override
  String get authPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get authPasswordMismatch => 'Passwords do not match';

  @override
  String get authVerifyTitle => 'Enter the verification code';

  @override
  String authVerifySubtitle(String email) {
    return 'We sent a verification code to $email';
  }

  @override
  String get authVerifyAction => 'Confirm';

  @override
  String get authVerifyResend => 'Send again';

  @override
  String authVerifyResendIn(int seconds) {
    return 'Send again in ${seconds}s';
  }

  @override
  String get authVerifyResent => 'A new code is on its way';

  @override
  String get authVerifyWrongCode => 'That code is wrong or has expired';

  @override
  String get authVerifyChangeEmail => 'Change the address';

  @override
  String get authVerifyJunkHint => 'Nothing arrived? Look in the junk folder';

  @override
  String get authVerifyUnconfirmed =>
      'This account was never confirmed. We have sent a new code.';

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get accountsSaved => 'Quick sign-in';

  @override
  String get accountsSavedHint =>
      'Accounts saved on this device — tap one to sign in without a password';

  @override
  String get accountsCurrent => 'Current account';

  @override
  String get accountsAdd => 'Add another account';

  @override
  String get accountsAddTitle => 'Add account';

  @override
  String get accountsAddSubtitle =>
      'Sign in with another account — the one you are using stays saved to return to';

  @override
  String get accountsSwitching => 'Switching account…';

  @override
  String get accountsRemove => 'Remove from this device';

  @override
  String accountsRemoveConfirm(String name) {
    return 'Remove $name from this device\'s list? Signing back in will ask for the password.';
  }

  @override
  String get accountsExpired =>
      'This account\'s session on this device has expired. Sign in with it again.';

  @override
  String get profileCompleteTitle => 'Complete your profile';

  @override
  String get profileCompleteSubtitle =>
      'Fill in your details to submit for approval';

  @override
  String get profileFirstName => 'First name';

  @override
  String get profileSurname => 'Surname';

  @override
  String get profileFatherName => 'Father\'s name';

  @override
  String get profilePhoto => 'Profile photo';

  @override
  String get profileJobTitle => 'Job title';

  @override
  String get profileCity => 'City';

  @override
  String get profileGender => 'Gender';

  @override
  String get profileDateOfBirth => 'Date of birth';

  @override
  String get profileMissionType => 'Mission type';

  @override
  String get profilePhoneSy => 'Syrian phone number';

  @override
  String get profilePhoneSa => 'Saudi phone number';

  @override
  String get profilePassportPhoto => 'Passport photo';

  @override
  String get profileVisaPhoto => 'Visa photo';

  @override
  String get profileNusukPhoto => 'Nusuk card photo';

  @override
  String get profileDocumentsSection => 'Documents (optional)';

  @override
  String get profilePickImage => 'Choose image';

  @override
  String get profileChangeImage => 'Change';

  @override
  String get profileSelectDate => 'Select date';

  @override
  String get profileSubmitForApproval => 'Submit for approval';

  @override
  String get profileCamera => 'Camera';

  @override
  String get profileGallery => 'Gallery';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get statusPendingTitle => 'Pending approval';

  @override
  String get statusPendingMessage =>
      'Your account is under review. You\'ll gain access once an administrator approves it.';

  @override
  String get statusRejectedTitle => 'Account not approved';

  @override
  String get statusRejectedMessage => 'Your account was not approved.';

  @override
  String statusRejectedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get statusEditAndResubmit => 'Edit and resubmit';

  @override
  String get statusSuspendedTitle => 'Account suspended';

  @override
  String get statusSuspendedMessage =>
      'Your account has been suspended. Please contact an administrator.';

  @override
  String get homeTitle => 'Home';

  @override
  String homeWelcome(String name) {
    return 'Welcome, $name';
  }

  @override
  String homeHijriDate(String date) {
    return '$date AH';
  }

  @override
  String homeGregorianDate(String date) {
    return '$date CE';
  }

  @override
  String profileTitleBadgeSuffix(String badge) {
    return '($badge)';
  }

  @override
  String get homeAdminSection => 'Administration';

  @override
  String get homeGeneralSection => 'General';

  @override
  String get homeAdminGroupFiles => 'Files, decisions & circulars';

  @override
  String get homeAdminGroupPeople => 'People & permissions';

  @override
  String get homeAdminGroupSeason => 'Season & reference data';

  @override
  String get homeAdminGroupOversight => 'Oversight & records';

  @override
  String get navApprovals => 'Account approvals';

  @override
  String get navApprovalsSubtitle => 'Review pending registrations';

  @override
  String get approvalQueueTitle => 'Pending approvals';

  @override
  String get approvalEmpty => 'No accounts are waiting for approval';

  @override
  String approvalPendingCount(int count) {
    return '$count pending';
  }

  @override
  String get approvalDetailTitle => 'Review account';

  @override
  String get approvalApprove => 'Approve';

  @override
  String get approvalReject => 'Reject';

  @override
  String get approvalRejectReasonTitle => 'Reason for rejection';

  @override
  String get approvalRejectReasonHint => 'Optional — shown to the applicant';

  @override
  String get approvalApproved => 'Account approved';

  @override
  String get approvalRejected => 'Account rejected';

  @override
  String get profileSectionPersonal => 'Personal information';

  @override
  String get profileSectionContact => 'Contact';

  @override
  String get contactWhatsApp => 'Message on WhatsApp';

  @override
  String get profileSectionDocuments => 'Documents';

  @override
  String get profileBadgeExternal => 'External';

  @override
  String get profileBadgeAdmin => 'Admin';

  @override
  String get profileFieldNotProvided => 'Not provided';

  @override
  String get profileNoPhone => '—';

  @override
  String get navPermissions => 'Permissions';

  @override
  String get navPermissionsSubtitle => 'Grant permissions to employees';

  @override
  String get permissionsEmployeesTitle => 'Employees';

  @override
  String get permissionEditorTitle => 'Permissions';

  @override
  String get permissionAssignIntro =>
      'Choose the permissions you need, then assign them to several employees at once. One person\'s permissions are edited from their page in the directory.';

  @override
  String permissionAssignSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count permissions selected',
      one: '1 permission selected',
      zero: 'No permissions selected yet',
    );
    return '$_temp0';
  }

  @override
  String get permissionAssignAction => 'Assign to employees';

  @override
  String get permissionAssignPickEmployees => 'Choose employees';

  @override
  String permissionAssignDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Permissions assigned to $count employees',
      one: 'Permissions assigned to 1 employee',
    );
    return '$_temp0';
  }

  @override
  String get permissionAssignNothingNew =>
      'Nothing to add — they already hold these permissions';

  @override
  String get employeesEmpty => 'No employees yet';

  @override
  String get permissionSaved => 'Permissions updated';

  @override
  String permissionGrantedCount(int count, int total) {
    return '$count of $total granted';
  }

  @override
  String get commonSearch => 'Search';

  @override
  String get commonClearAll => 'Clear selection';

  @override
  String pickerSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get commonSelectAll => 'Select all';

  @override
  String get permAllGranted => 'Full access (administrator)';

  @override
  String get perm_employees => 'Employees';

  @override
  String get perm_approvals => 'Account approvals';

  @override
  String get perm_seasons => 'Seasons';

  @override
  String get perm_permissions => 'Permissions';

  @override
  String get permEmployeesView => 'View employees & details';

  @override
  String get permEmployeesCreate => 'Add employees';

  @override
  String get permEmployeesEdit => 'Edit employee records';

  @override
  String get permEmployeesDelete => 'Delete employee records';

  @override
  String get permEmployeesPassword => 'Reset an employee\'s password';

  @override
  String get permEmployeesEmail => 'Change an employee\'s email address';

  @override
  String get permEmployeesSuspend => 'Suspend & reactivate accounts';

  @override
  String get permEmployeesExternal => 'Manage external status';

  @override
  String get permEmployeesDocuments => 'View employee documents';

  @override
  String get permApprovalsView => 'View registration requests';

  @override
  String get permApprovalsDecide => 'Approve & reject requests';

  @override
  String get permSeasonsView => 'View seasons';

  @override
  String get permSeasonsSwitch => 'Set the current season';

  @override
  String get permSeasonsParticipantsView => 'View season participants';

  @override
  String get permSeasonsParticipantsManage => 'Add & withdraw participants';

  @override
  String get permPermissionsView => 'View granted permissions';

  @override
  String get permPermissionsManage => 'Grant & revoke permissions';

  @override
  String get perm_reference => 'Master data';

  @override
  String get permReferenceView => 'View master data';

  @override
  String get permReferenceEdit => 'Add & edit master data';

  @override
  String get permReferenceDelete => 'Delete master data';

  @override
  String get permReferenceImport => 'Copy data from another season';

  @override
  String get perm_reports => 'Decisions and circulars';

  @override
  String get permReportsViewAll => 'View all decisions, including drafts';

  @override
  String get permReportsCreate => 'Create decisions';

  @override
  String get permReportsEdit => 'Edit decisions';

  @override
  String get permReportsDelete => 'Delete decisions';

  @override
  String get permReportsPublish => 'Publish & unpublish decisions';

  @override
  String get perm_notifications => 'Notifications';

  @override
  String get permNotificationsSend => 'Notify an individual employee';

  @override
  String get permNotificationsBroadcastModule => 'Notify a file\'s members';

  @override
  String get permNotificationsBroadcastAll => 'Notify everyone';

  @override
  String get perm_audit => 'Audit log';

  @override
  String get permAuditView => 'Read the record of who did what';

  @override
  String get perm_complaints => 'Complaints';

  @override
  String get permComplaintsView => 'View every complaint filed';

  @override
  String get permComplaintsReply => 'Take part in any complaint thread';

  @override
  String get permComplaintsLock => 'Close a complaint to further replies';

  @override
  String get permComplaintsDismiss => 'Dismiss a complaint as unfounded';

  @override
  String get permComplaintsDelete => 'Delete a complaint';

  @override
  String get perm_evaluations => 'Evaluations';

  @override
  String get permEvaluationsView => 'View every evaluation and its marks';

  @override
  String get permEvaluationsTemplates => 'Build and edit the evaluation forms';

  @override
  String get permEvaluationsAssign =>
      'Open an evaluation and name its evaluator';

  @override
  String get permEvaluationsDelete => 'Delete an evaluation';

  @override
  String get perm_incidents => 'Urgent reports';

  @override
  String get permIncidentsReceive => 'Receive and read every urgent report';

  @override
  String get permIncidentsHandle => 'Take on an urgent report and close it';

  @override
  String get permIncidentsDelete => 'Delete urgent reports from the register';

  @override
  String get perm_checkin => 'Check-in';

  @override
  String get permCheckinBoard => 'Read everyone\'s attendance record';

  @override
  String get permCheckinCodes => 'View, print and share place codes';

  @override
  String get permCheckinRotate =>
      'Regenerate a place code, voiding every printed copy';

  @override
  String get perm_export => 'Data export';

  @override
  String get permExportData =>
      'Export any dataset, including data you cannot open on screen';

  @override
  String get perm_map => 'Season map';

  @override
  String get permMapView => 'Open the season map';

  @override
  String get perm_tasks => 'Tasks';

  @override
  String get permTasksAssign => 'Assign tasks to other people';

  @override
  String get permTasksViewAll => 'See every assigned task in the mission';

  @override
  String permissionRequires(String names) {
    return 'Requires: $names';
  }

  @override
  String get permissionDenied =>
      'You don\'t hold the permission this action needs';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get notificationTargetGone => 'That file is no longer available';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get notificationSend => 'Send notification';

  @override
  String get notificationFilterAll => 'All';

  @override
  String get notificationFilterMessages => 'Notices';

  @override
  String get notificationFilterIncidents => 'Urgent reports';

  @override
  String notificationFilterCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get notificationOpenIncident => 'Open the report';

  @override
  String get notificationOpenModule => 'Open the file';

  @override
  String get notificationsEmptyIncidents => 'No urgent reports in the inbox';

  @override
  String get notificationsEmptyMessages => 'No notices';

  @override
  String get notificationTitleField => 'Title';

  @override
  String get notificationBodyField => 'Message';

  @override
  String get notificationSent => 'Notification sent';

  @override
  String get notificationMarkAllRead => 'Mark all as read';

  @override
  String get notificationAudience => 'Send to';

  @override
  String get notificationAudienceAll => 'Everyone';

  @override
  String get notificationAudienceModule => 'Members of a file';

  @override
  String get notificationChooseModule => 'Choose the file';

  @override
  String get notificationBroadcastHint =>
      'Reaches everyone holding a role in the file';

  @override
  String get notificationAttach => 'Attach';

  @override
  String get notificationAttachPhoto => 'Photo';

  @override
  String get notificationAttachCamera => 'Take a photo';

  @override
  String get notificationAttachVideo => 'Video';

  @override
  String get notificationAttachAudio => 'Audio';

  @override
  String get notificationAttachFile => 'File';

  @override
  String notificationAttachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0';
  }

  @override
  String attachmentTooLarge(String limit) {
    return 'That file is larger than the $limit limit. Choose a smaller one.';
  }

  @override
  String get attachmentImage => 'Image';

  @override
  String get attachmentVideo => 'Video';

  @override
  String get attachmentAudio => 'Audio';

  @override
  String get attachmentFile => 'File';

  @override
  String get attachmentDownload => 'Download';

  @override
  String get attachmentOpenFailed => 'Could not open the attachment';

  @override
  String get modulesSearchHint => 'Search files';

  @override
  String get modulesNoMatches => 'No file matches';

  @override
  String get reportScanCode => 'Scan';

  @override
  String get reportCellEntryGone => 'This choice no longer exists';

  @override
  String get reportTimeFrom => 'From';

  @override
  String get reportTimeTo => 'To';

  @override
  String reportTimeRange(String from, String to) {
    return 'From $from to $to';
  }

  @override
  String get reportAddTag => 'Add an item';

  @override
  String get reportSubtitle => 'Subtitle';

  @override
  String get reportShape => 'Document shape';

  @override
  String get reportKindDecision => 'Decision';

  @override
  String get reportKindCircular => 'Circular';

  @override
  String get reportNumber => 'Decision number';

  @override
  String reportNumberBadge(String number) {
    return 'No. $number';
  }

  @override
  String get reportContentSection => 'Content';

  @override
  String get reportContentHint =>
      'Build the decision from the pieces below — a heading, prose, a list, a table, a link, a code to scan. They appear in the order you add them.';

  @override
  String get reportNoBlocks => 'Nothing added yet';

  @override
  String get blockHeading => 'Heading';

  @override
  String get blockSubheading => 'Subheading';

  @override
  String get blockParagraph => 'Paragraph';

  @override
  String get blockBullets => 'Bulleted list';

  @override
  String get blockNumbers => 'Numbered list';

  @override
  String get blockTable => 'Table';

  @override
  String get blockUrl => 'Link';

  @override
  String get blockQr => 'QR code';

  @override
  String get blockNote => 'Note';

  @override
  String get blockDivider => 'Divider';

  @override
  String get blockMoveUp => 'Move up';

  @override
  String get blockMoveDown => 'Move down';

  @override
  String get blockTextShort => 'Text';

  @override
  String get blockTextLong => 'Text';

  @override
  String get blockItems => 'Items';

  @override
  String get blockItemsHint => 'One per line';

  @override
  String get blockLabel => 'Label';

  @override
  String get blockQrValue => 'What the code carries';

  @override
  String get blockQrHint => 'Usually a link';

  @override
  String get blockColumnLabel => 'Heading';

  @override
  String get blockColumnKind => 'Column type';

  @override
  String get blockColumnKindText => 'Text';

  @override
  String get blockColumnKindNumber => 'Number';

  @override
  String get blockColumnKindDate => 'Date';

  @override
  String get blockColumnKindTime => 'Time';

  @override
  String get blockColumnKindTimeRange => 'Time range';

  @override
  String get blockColumnKindReference => 'From master data';

  @override
  String get blockColumnKindTags => 'List of items';

  @override
  String get blockColumnSet => 'List';

  @override
  String get blockColumnSpan => 'Merge repeats';

  @override
  String blockColumnRetypeWarning(int count) {
    return '$count cells cannot be converted and will be emptied';
  }

  @override
  String get blockAddItem => 'Add an item';

  @override
  String get blockAddColumn => 'Add a column';

  @override
  String get blockTableNeedsColumns => 'Name the columns first, then add rows';

  @override
  String get reportNew => 'New decision';

  @override
  String get reportEdit => 'Edit decision';

  @override
  String get reportSaved => 'Decision saved';

  @override
  String get reportIdentity => 'What this decision is';

  @override
  String get reportTitle => 'Title';

  @override
  String get reportScopeHint =>
      'General decisions stay true whichever season is running';

  @override
  String get reportOncePerSeason =>
      'This kind of decision is created only once per season, and it already exists — edit the existing one instead of creating another';

  @override
  String get reportPublished => 'Published';

  @override
  String get reportPublishedHint =>
      'An unpublished decision is visible only to whoever manages decisions';

  @override
  String get reportAddRow => 'Add a row';

  @override
  String get reportNoRows => 'No rows yet';

  @override
  String get reportsManageEmpty => 'No decisions yet';

  @override
  String reportDeleteConfirm(String title) {
    return 'Delete $title? This cannot be undone.';
  }

  @override
  String get reportDeleted => 'Decision deleted';

  @override
  String reportRowsSection(int count) {
    return 'Rows ($count)';
  }

  @override
  String reportRowNumber(int number) {
    return 'Row $number';
  }

  @override
  String get navReportsManage => 'Decisions & circulars management';

  @override
  String get navReportsManageSubtitle => 'Enter, correct and publish decisions';

  @override
  String get navReports => 'Decisions and circulars';

  @override
  String get navReportsSubtitle =>
      'Timetables and notices published to the mission';

  @override
  String get reportsEmpty => 'Nothing has been published yet';

  @override
  String get reportsNoMatches => 'No decision matches';

  @override
  String get reportsSearchHint => 'Search decisions';

  @override
  String get reportsScopeAll => 'All';

  @override
  String get reportsScopeSeasonal => 'This season';

  @override
  String get reportsScopeGeneral => 'General';

  @override
  String get reportsDraft => 'Unpublished';

  @override
  String get reportMissing => 'That decision is no longer available';

  @override
  String get reportAboutSection => 'About this decision';

  @override
  String get reportKind => 'Kind';

  @override
  String get reportScope => 'Applies to';

  @override
  String get reportAbout => 'What it covers';

  @override
  String get reportSource => 'The original document';

  @override
  String get reportQrFailed => 'This code could not be drawn';

  @override
  String reportUpdated(String date) {
    return 'Last updated $date';
  }

  @override
  String get navSeasons => 'Seasons';

  @override
  String get navSeasonsSubtitle => 'Current season and archive';

  @override
  String get seasonsTitle => 'Seasons';

  @override
  String get seasonCurrentLabel => 'Current season';

  @override
  String get seasonUpcomingLabel => 'Upcoming seasons';

  @override
  String get seasonArchiveLabel => 'Previous seasons';

  @override
  String seasonHijriYear(int year) {
    return '$year AH';
  }

  @override
  String get seasonBadgeCurrent => 'Current';

  @override
  String get seasonParticipantsTitle => 'Participants';

  @override
  String seasonParticipantsCount(int count) {
    return '$count participants';
  }

  @override
  String get seasonManageParticipants => 'Manage participants';

  @override
  String get seasonNoParticipants => 'No participants in this season yet';

  @override
  String get seasonSetCurrent => 'Set as current season';

  @override
  String get seasonSetCurrentDone => 'Current season updated';

  @override
  String get seasonArchiveEmpty => 'No previous seasons';

  @override
  String get seasonSelectParticipants => 'Select participants';

  @override
  String get seasonParticipantsSaved => 'Participants updated';

  @override
  String get navEmployees => 'Employees';

  @override
  String get navEmployeesSubtitle => 'Staff directory and externals';

  @override
  String get employeesPermanentSection => 'Permanent staff';

  @override
  String get employeesExternalSection => 'External participants';

  @override
  String get employeesFilterSuspended => 'Suspended only';

  @override
  String get employeesExternalEmpty => 'No external employees';

  @override
  String get employeeDetailTitle => 'Employee';

  @override
  String get modulePickerOnlyFree => 'Unassigned only';

  @override
  String get moduleRosterSearchHint => 'Search by name or role';

  @override
  String get moduleRosterAllRoles => 'All roles';

  @override
  String get moduleRosterClear => 'Clear';

  @override
  String moduleRosterShowing(int showing, int total) {
    return 'Showing $showing of $total';
  }

  @override
  String get moduleRosterNoMatch => 'Nobody in this file matches';

  @override
  String referenceChildCount(String list) {
    return '$list assigned';
  }

  @override
  String referenceOfCapacity(int total, int capacity) {
    return '$total of $capacity';
  }

  @override
  String referenceOverCapacity(int excess) {
    return 'Over capacity by $excess';
  }

  @override
  String get placeOccupants => 'Occupants';

  @override
  String placeOccupantsBreakdown(int pilgrims, int staff) {
    return '$pilgrims pilgrims, $staff staff';
  }

  @override
  String get placeOccupantsStaff => 'Staff housed';

  @override
  String get placeOccupantsPilgrims => 'Pilgrims';

  @override
  String get employeePermissionsSection => 'Granted permissions';

  @override
  String get employeePermissionsEmpty => 'No permissions granted';

  @override
  String get employeePermissionsAdmin =>
      'An administrator — holds every permission, without needing to be granted them.';

  @override
  String get employeePermissionsEdit => 'Edit permissions';

  @override
  String get employeeEditDetailsTitle => 'Edit employee details';

  @override
  String get employeeEditSaved => 'Employee details updated';

  @override
  String get employeeEdit => 'Edit details';

  @override
  String get employeeDelete => 'Delete employee';

  @override
  String get employeeDeleteConfirmTitle => 'Delete this employee?';

  @override
  String employeeDeleteConfirmBody(String name) {
    return '$name will be removed permanently, along with their account and every assignment they hold. This cannot be undone.';
  }

  @override
  String get employeeDeleted => 'Employee deleted';

  @override
  String get employeeDeleteAdminBlocked =>
      'An administrator cannot be deleted. Remove their admin role first.';

  @override
  String get employeePassword => 'Change password';

  @override
  String employeePasswordTitle(String name) {
    return 'New password for $name';
  }

  @override
  String get employeePasswordHint =>
      'The employee signs in with the new password from now on. Tell them yourself — no message is sent.';

  @override
  String get employeePasswordNew => 'New password';

  @override
  String get employeePasswordConfirm => 'Confirm password';

  @override
  String get employeePasswordChanged => 'Password changed';

  @override
  String get employeePasswordAdminBlocked =>
      'Only an administrator can change another administrator\'s password.';

  @override
  String get employeeEmail => 'Change email';

  @override
  String employeeEmailTitle(String name) {
    return 'New email for $name';
  }

  @override
  String get employeeEmailHint =>
      'The employee signs in with the new email from now on. Tell them yourself — no message is sent to either address.';

  @override
  String get employeeEmailNew => 'New email';

  @override
  String get employeeEmailChanged => 'Email changed';

  @override
  String get employeeEmailAdminBlocked =>
      'Only an administrator can change another administrator\'s email.';

  @override
  String get employeeEmailTaken =>
      'This email is already used by another account.';

  @override
  String get myProfileChangeEmail => 'Change email';

  @override
  String get myProfileNewEmail => 'New email';

  @override
  String get myProfileEmailChanged =>
      'Email changed. You sign in with the new address from now on.';

  @override
  String get employeeEditExternalTitle => 'External status';

  @override
  String get employeeIsExternal => 'External employee';

  @override
  String get employeeIsExternalHint =>
      'From another government body — not permanent staff';

  @override
  String get employeeOrganization => 'Organization / ministry';

  @override
  String get employeeExternalSaved => 'Employee updated';

  @override
  String get employeeSectionOrganization => 'Organization';

  @override
  String get employeeSeasonsSection => 'Seasons taken part in';

  @override
  String get employeeSeasonsEmpty => 'Has not taken part in any season yet';

  @override
  String get employeeSeasonBadgeCurrent => 'Current';

  @override
  String get employeeModulesSection => 'Assigned modules';

  @override
  String get employeeModulesEmpty => 'Not assigned to any operational module';

  @override
  String get navMyProfile => 'My profile';

  @override
  String get navMyProfileSubtitle => 'View and edit your details';

  @override
  String get myProfileEdit => 'Edit profile';

  @override
  String get myProfileChangePassword => 'Change password';

  @override
  String get myProfileNewPassword => 'New password';

  @override
  String get myProfileConfirmPassword => 'Confirm new password';

  @override
  String get myProfilePasswordChanged => 'Password changed';

  @override
  String get myProfileSaved => 'Profile updated';

  @override
  String get myProfileEditTitle => 'Edit profile';

  @override
  String get createEmployeeTitle => 'Create employee';

  @override
  String get createEmployeeCreated => 'Employee created';

  @override
  String get createEmployeeAccountSection => 'Account';

  @override
  String get createEmployeeSubmit => 'Create account';

  @override
  String get commonDelete => 'Delete';

  @override
  String get perm_modules => 'Operational files';

  @override
  String get permModulesViewAll => 'View all files, including drafts';

  @override
  String get permModulesCreate => 'Create an operational file';

  @override
  String get permModulesEdit => 'Edit a file & its structure';

  @override
  String get permModulesDelete => 'Delete an operational file';

  @override
  String get permModulesActivate => 'Activate & deactivate files';

  @override
  String get permModulesMembers => 'Assign members & duties';

  @override
  String get permModulesTasks => 'Write file duties and set any state';

  @override
  String get permModulesReports => 'Read members\' file reports';

  @override
  String get navModules => 'Operational modules';

  @override
  String get navModulesSubtitle =>
      'The files you were assigned to, and your roles in them';

  @override
  String get navReferenceData => 'Master data';

  @override
  String get navReferenceDataSubtitle => 'Hotels, clusters and other lists';

  @override
  String get modulesManageTitle => 'Manage operational files';

  @override
  String get modulesEmptyMine => 'No files were assigned to you this season';

  @override
  String get navModulesManage => 'Manage operational files';

  @override
  String get navModulesManageSubtitle =>
      'Every file of the season, and opening a new one';

  @override
  String get modulesTitle => 'Operational files';

  @override
  String get modulesEmpty => 'No files have been assigned to you yet';

  @override
  String get modulesEmptyManager => 'No files created yet';

  @override
  String get moduleActiveSection => 'Active files';

  @override
  String get moduleDraftSection => 'Drafts';

  @override
  String get moduleBadgeDraft => 'Draft';

  @override
  String get moduleNew => 'New file';

  @override
  String get moduleChooseType => 'Choose a file type';

  @override
  String get moduleNoTypes => 'No file types have been defined yet';

  @override
  String get moduleAllTypesUsed =>
      'Every file type has already been opened for this season';

  @override
  String get moduleOnePerSeason =>
      'A file of a kind is created once per season, and its type is its name';

  @override
  String get moduleSeasonLabel => 'Season';

  @override
  String moduleDecisionBadge(String number) {
    return 'Decision $number';
  }

  @override
  String get moduleDecisionNumber => 'Decision / file number';

  @override
  String get moduleDecisionNumberHint =>
      'Optional — added when the decision is issued';

  @override
  String get moduleEndDate => 'End date';

  @override
  String get moduleEndDateHint =>
      'Optional — the file ends at the close of this day';

  @override
  String get moduleEndDateClear => 'No end date';

  @override
  String get moduleEndBeforeStart => 'The end date is before the start date';

  @override
  String get moduleStartDate => 'Work starts on';

  @override
  String get moduleStartNote => 'Start note';

  @override
  String get moduleStartNoteHint =>
      'Optional — what there is to say about this file\'s start';

  @override
  String get moduleEndNote => 'End note';

  @override
  String get moduleEndNoteHint =>
      'Optional — what there is to say about this file\'s end';

  @override
  String get moduleReportCadence => 'Reports';

  @override
  String get moduleReportCadenceHint =>
      'How often the people in this file file one';

  @override
  String get cadenceNone => 'No reports';

  @override
  String get cadenceDaily => 'Daily';

  @override
  String get cadenceWeekly => 'Weekly';

  @override
  String get cadenceOnce => 'Once';

  @override
  String get moduleRatingNone => 'Nobody has rated you in this file yet';

  @override
  String moduleRatingValue(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ratings',
      one: '1 rating',
    );
    return '$average of 5 · $_temp0';
  }

  @override
  String get moduleRatingAnonymous =>
      'Ratings are anonymous — a colleague sees his average and how many rated him, never who gave what';

  @override
  String get moduleRatingSaved => 'Rating saved';

  @override
  String get moduleRatingCleared => 'Rating withdrawn';

  @override
  String get moduleReports => 'Reports';

  @override
  String get moduleReportWrite => 'File a report';

  @override
  String get moduleReportEdit => 'Edit my report';

  @override
  String get moduleReportNotes => 'Notes';

  @override
  String get moduleReportNotesHint =>
      'Optional — anything to add about what you attached';

  @override
  String get moduleReportAttachHint =>
      'The report is what you upload: photos, files or a voice note';

  @override
  String get moduleReportNothingAttached => 'Nothing attached';

  @override
  String get moduleReportSaved => 'Report filed';

  @override
  String get moduleReportsEmpty => 'No reports filed yet';

  @override
  String moduleReportPeriodDay(String date) {
    return 'Report for $date';
  }

  @override
  String moduleReportPeriodWeek(String date) {
    return 'Week of $date';
  }

  @override
  String get moduleStartCondition => 'Work begins';

  @override
  String get moduleEndCondition => 'Ends';

  @override
  String get moduleStepInfo => 'File';

  @override
  String get moduleStepSectors => 'Sectors';

  @override
  String get moduleStepTowers => 'Towers';

  @override
  String get moduleStepMembers => 'Team';

  @override
  String get moduleNodeName => 'Name';

  @override
  String moduleNodeAdd(String level) {
    return 'Add $level';
  }

  @override
  String moduleNodeEdit(String level) {
    return 'Edit $level';
  }

  @override
  String moduleNodeDelete(String level) {
    return 'Delete $level';
  }

  @override
  String moduleNodeDeleteConfirm(String name) {
    return 'Delete “$name”? Everything inside it goes with it.';
  }

  @override
  String moduleNodeSuggestedName(String level, int number) {
    return '$level $number';
  }

  @override
  String get moduleSectorsImport => 'Import sectors';

  @override
  String get moduleSectorsImportPick =>
      'Copy the sectors from another file in this season — the name, the supervisor and his deputy. The copies are independent: deleting a sector here does not touch the other file.';

  @override
  String moduleSectorsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count sectors',
      one: 'Imported 1 sector',
      zero: 'No new sectors',
    );
    return '$_temp0';
  }

  @override
  String get moduleSectorsImportFailed => 'Could not import the sectors';

  @override
  String get moduleSectorsImportNoSources =>
      'No other file in this season has sectors';

  @override
  String get moduleNoNodes => 'Nothing has been added yet';

  @override
  String get moduleSectorsFirst =>
      'Add the sectors first, then place the hotels in them';

  @override
  String get moduleBuildTree => 'Add sectors & towers';

  @override
  String get moduleNoLevels => 'This file type has no structure defined yet';

  @override
  String get moduleSectionWhen => 'Work period';

  @override
  String get moduleSectionPaperwork => 'Decision and reports';

  @override
  String get moduleSectionTypeFields => 'Fields of this type';

  @override
  String get moduleNotesShow => 'Add a note to the start or the end';

  @override
  String get moduleNotesHide => 'Hide the notes';

  @override
  String get moduleSectionInfo => 'File information';

  @override
  String get moduleSectionTasks => 'My role';

  @override
  String moduleSectionTasksOf(String name) {
    return '$name — role';
  }

  @override
  String get moduleJobDescription => 'Job description';

  @override
  String get moduleTasksSection => 'Duties';

  @override
  String get moduleTasksFile => 'File duties';

  @override
  String get moduleTasksFileHint =>
      'The whole file\'s work — its members divide it among themselves';

  @override
  String get moduleTasksRole => 'Role duties';

  @override
  String moduleTasksRoleOf(String name) {
    return '$name duties';
  }

  @override
  String get moduleTasksRoleHint =>
      'Attached to the post, not the person — replacing the holder leaves them standing';

  @override
  String get moduleTasksNone => 'This file has no duties written yet';

  @override
  String get taskStateNotStarted => 'Not started';

  @override
  String get taskStateInProgress => 'In progress';

  @override
  String get taskStateBlocked => 'Stuck';

  @override
  String get taskStateSubmitted => 'Awaiting acceptance';

  @override
  String get taskStateDone => 'Done';

  @override
  String get taskStateReturned => 'Sent back';

  @override
  String get taskStateCancelled => 'Withdrawn';

  @override
  String moduleTaskDue(String date) {
    return 'Due $date';
  }

  @override
  String get moduleTaskAdd => 'Add a duty';

  @override
  String get moduleTaskEdit => 'Edit duty';

  @override
  String get moduleTaskDelete => 'Delete duty';

  @override
  String get moduleTaskDeleteConfirm =>
      'Delete this duty from the file\'s list?';

  @override
  String get moduleTaskScope => 'Scope';

  @override
  String get moduleTaskScopeFile => 'File duty';

  @override
  String get moduleTaskScopeFileHint =>
      'The whole file\'s — members share it among themselves';

  @override
  String get moduleTaskScopeRole => 'Role duty';

  @override
  String get moduleTaskScopeRoleHint =>
      'What holding the post means, whoever holds it';

  @override
  String get moduleTaskRoleLabel => 'Role';

  @override
  String get moduleTaskTitleLabel => 'Duty';

  @override
  String get moduleTaskTitleEnLabel => 'English title';

  @override
  String get moduleTaskDescriptionLabel => 'Description';

  @override
  String get moduleTaskNoDue => 'No date';

  @override
  String get moduleTaskPickRole => 'Choose a role';

  @override
  String get navTasks => 'My tasks';

  @override
  String get navTasksSubtitle => 'Your own list, and what was assigned to you';

  @override
  String get tasksTitle => 'My tasks';

  @override
  String get tasksOwnSection => 'My own tasks';

  @override
  String get tasksOwnHint =>
      'You wrote these for yourself — edit, delete and move them freely';

  @override
  String get tasksAssignedSection => 'Assigned to me';

  @override
  String get tasksAssignedHint =>
      'Written for you — you change only how they are going';

  @override
  String get tasksIAssignedSection => 'Assigned by me';

  @override
  String get tasksIAssignedHint =>
      'What you wrote onto other people\'s lists, followed up from here';

  @override
  String get tasksEmpty => 'No tasks yet';

  @override
  String get tasksEmptyHint => 'Write your first task with the button below';

  @override
  String get tasksNew => 'New task';

  @override
  String get tasksAssign => 'Assign a task';

  @override
  String get navTasksManage => 'Task assignment';

  @override
  String get navTasksManageSubtitle =>
      'Write tasks onto other people\'s lists, and follow them up';

  @override
  String get tasksManageTitle => 'Task assignment';

  @override
  String get tasksManageEmpty => 'You have assigned nothing yet';

  @override
  String get tasksManageEmptyHint =>
      'Assign a task with the button below — its owner is told, and changes only how it is going';

  @override
  String get taskPickPerson => 'Choose an employee';

  @override
  String taskAssignedBy(String name) {
    return 'Assigned by $name';
  }

  @override
  String taskAssignedTo(String name) {
    return 'For $name';
  }

  @override
  String get taskTitleLabel => 'Task';

  @override
  String get taskDescriptionLabel => 'Description';

  @override
  String taskDue(String date) {
    return 'Due $date';
  }

  @override
  String get taskNoDue => 'No date';

  @override
  String get taskState => 'State';

  @override
  String get taskNote => 'Note';

  @override
  String get taskNoteHint => 'Anything worth saying about it?';

  @override
  String get taskEvidence => 'Evidence';

  @override
  String get taskUpdate => 'Update state';

  @override
  String get taskStateSaved => 'State updated';

  @override
  String get taskSaved => 'Task saved';

  @override
  String get taskReadOnly =>
      'Assigned to you — move it and talk about it; its wording is its author\'s';

  @override
  String get taskEdit => 'Edit task';

  @override
  String get taskDelete => 'Delete task';

  @override
  String get taskDeleteConfirm =>
      'Delete this task? Whatever was filed against it goes with it.';

  @override
  String taskProgress(int done, int total) {
    return '$done/$total';
  }

  @override
  String taskKey(int seq) {
    return 'T-$seq';
  }

  @override
  String get taskMoveStart => 'Start';

  @override
  String get taskMoveBlock => 'I\'m stuck';

  @override
  String get taskMoveSubmit => 'Send for acceptance';

  @override
  String get taskMoveDone => 'Done';

  @override
  String get taskMoveAccept => 'Accept';

  @override
  String get taskMoveReturn => 'Send back';

  @override
  String get taskMoveReopen => 'Reopen';

  @override
  String get taskMoveCancel => 'Withdraw task';

  @override
  String get taskMoveRestore => 'Put it back';

  @override
  String get taskNoActions => 'Nothing here is yours to move right now';

  @override
  String get taskPriority => 'Priority';

  @override
  String get taskPriorityHigh => 'Urgent';

  @override
  String get taskPriorityNormal => 'Normal';

  @override
  String get taskPriorityLow => 'Low';

  @override
  String get taskKind => 'Kind';

  @override
  String get taskKindTask => 'Task';

  @override
  String get taskKindFollowUp => 'Follow-up';

  @override
  String get taskKindRequest => 'Request';

  @override
  String get taskViewToday => 'Today';

  @override
  String get taskViewWeek => 'This week';

  @override
  String get taskViewOverdue => 'Overdue';

  @override
  String get taskViewOpen => 'Open';

  @override
  String get taskViewDone => 'Done';

  @override
  String get taskViewAll => 'All';

  @override
  String taskLateDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days late',
      one: '1 day late',
    );
    return '$_temp0';
  }

  @override
  String get taskDueToday => 'Due today';

  @override
  String get taskDueTomorrow => 'Due tomorrow';

  @override
  String get taskThread => 'What happened';

  @override
  String get taskThreadEmpty => 'Nothing said yet';

  @override
  String get taskCommentHint => 'Say what is worth saying';

  @override
  String get taskCommentSend => 'Send';

  @override
  String get taskCommentAdded => 'Comment added';

  @override
  String get taskCommentRequired => 'This move needs a reason in words';

  @override
  String get taskBySystem => 'The system';

  @override
  String get taskEventCreated => 'created the task';

  @override
  String get taskEventAssigned => 'assigned the task';

  @override
  String taskEventStateTo(String state) {
    return 'moved it to: $state';
  }

  @override
  String get taskEventReassigned => 'handed it to somebody else';

  @override
  String taskEventDue(String date) {
    return 'moved the deadline to $date';
  }

  @override
  String get taskEventDueCleared => 'removed the deadline';

  @override
  String taskEventPriority(String priority) {
    return 'changed the priority to $priority';
  }

  @override
  String get taskEventEscalated => 'reported as late';

  @override
  String get taskSteps => 'Steps';

  @override
  String taskStepsProgress(int done, int total) {
    return '$done of $total';
  }

  @override
  String get taskStepsEdit => 'Edit steps';

  @override
  String get taskStepAdd => 'Add a step';

  @override
  String get taskStepHint => 'Step';

  @override
  String get taskStepsSaved => 'Steps saved';

  @override
  String get taskStepsOwnerOnly =>
      'Steps are written by whoever assigned the task';

  @override
  String taskBatchOf(String title) {
    return 'Part of: $title';
  }

  @override
  String taskBatchCarriers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String taskBatchAcceptReady(int count) {
    return 'Accept the ready ($count)';
  }

  @override
  String get taskBatchNudge => 'Nudge the rest';

  @override
  String taskBatchAccepted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks accepted',
      one: '1 task accepted',
    );
    return '$_temp0';
  }

  @override
  String taskBatchNudged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people reminded',
      one: '1 person reminded',
    );
    return '$_temp0';
  }

  @override
  String get tasksBatchesEmpty => 'No batches yet';

  @override
  String get tasksBatchesEmptyHint =>
      'A batch is written when one task goes to more than one person';

  @override
  String get taskReassign => 'Reassign';

  @override
  String get taskReassignHint =>
      'It moves with its thread and its evidence, and returns to Not started';

  @override
  String get taskReassigned => 'Task handed over';

  @override
  String get taskCancel => 'Withdraw task';

  @override
  String get taskCancelConfirm =>
      'Withdraw this task? It stays in the record, its owner is told, and nothing is deleted.';

  @override
  String get taskCancelled => 'Task withdrawn';

  @override
  String get taskGone => 'This task is no longer there';

  @override
  String get taskGoneHint => 'It was probably withdrawn or deleted';

  @override
  String taskStartedAt(String date) {
    return 'Started $date';
  }

  @override
  String taskSubmittedAt(String date) {
    return 'Sent for acceptance $date';
  }

  @override
  String taskAcceptedAt(String date) {
    return 'Accepted $date';
  }

  @override
  String get tasksSearch => 'Search by title or number';

  @override
  String get tasksNoMatch => 'Nothing matches what you searched for';

  @override
  String get tasksClearFilters => 'Clear filters';

  @override
  String get tasksBoardTitle => 'Task board';

  @override
  String get tasksBoardView => 'By state';

  @override
  String get tasksBatchesView => 'By task';

  @override
  String get tasksPeopleView => 'By person';

  @override
  String get tasksAssignTargetTitle => 'Who is the task for?';

  @override
  String get tasksAssignToPeople => 'People';

  @override
  String get tasksAssignToPeopleHint =>
      'A tracked task on each chosen person\'s list, sent back to you for acceptance';

  @override
  String get tasksAssignToFile => 'An operational file';

  @override
  String get tasksAssignToFileHint =>
      'A duty written on the file itself, read and shared by all its members';

  @override
  String get tasksAssignToRole => 'A role in a file';

  @override
  String get tasksAssignToRoleHint =>
      'A duty on one post — the tower supervisor, say — whoever holds it';

  @override
  String get tasksAssignPickModule => 'Choose the file';

  @override
  String get tasksAssignPickRole => 'Choose the role';

  @override
  String get tasksAssignNoRoles => 'This file\'s type defines no roles';

  @override
  String get tasksAssignDutySaved => 'The duty was written on the file';

  @override
  String get tasksScopeMine => 'Assigned by me';

  @override
  String get tasksScopeAll => 'The whole mission';

  @override
  String get tasksReviewQueue => 'Awaiting your acceptance';

  @override
  String get tasksReviewEmpty => 'Nothing is waiting on you';

  @override
  String get taskStatsOpen => 'On me';

  @override
  String get taskStatsOverdue => 'Overdue';

  @override
  String get taskStatsReview => 'Awaiting my acceptance';

  @override
  String get taskStatsDone => 'Done';

  @override
  String get moduleTeamPick => 'Choose members';

  @override
  String moduleTeamPickFor(String role) {
    return 'Choose: $role';
  }

  @override
  String get moduleNoTeamMembers => 'No one has been put on this team yet';

  @override
  String get moduleNoRoles => 'This file type has no roles defined yet';

  @override
  String moduleMembersCount(int count) {
    return '$count members';
  }

  @override
  String get moduleNoMembers => 'No one has been assigned here yet';

  @override
  String get moduleRoleUnassigned => 'Not assigned';

  @override
  String get moduleMemberHousing => 'Housing';

  @override
  String get moduleHousingUnset => 'No housing set';

  @override
  String get moduleHousedHere => 'Housed here';

  @override
  String get moduleSaved => 'Saved';

  @override
  String get moduleActivate => 'Activate file';

  @override
  String get moduleDeactivate => 'Deactivate file';

  @override
  String get moduleActivated => 'File activated — members have been notified';

  @override
  String get moduleDeactivated => 'File deactivated';

  @override
  String get moduleAttachPdf => 'Attach PDF';

  @override
  String get moduleReplacePdf => 'Replace file';

  @override
  String get moduleOpenPdf => 'Open PDF';

  @override
  String get moduleNoPdf => 'No file attached';

  @override
  String get modulePdfOpenFailed => 'Could not open the file';

  @override
  String get moduleDelete => 'Delete file';

  @override
  String get moduleDeleteConfirm =>
      'Delete this file? Everything in it — its members, the duties they were handed, and its attachments — goes with it.';

  @override
  String get moduleDeleted => 'File deleted';

  @override
  String get moduleNoCurrentSeason =>
      'Set a current season before creating files';

  @override
  String get moduleNoParticipants =>
      'The current season has no participants yet';

  @override
  String get moduleContactSy => 'Syrian number';

  @override
  String get moduleContactSa => 'Saudi number';

  @override
  String get modulePickerSearchHint => 'Search by name or job title';

  @override
  String get modulePickerAll => 'Everyone';

  @override
  String get modulePickerInternal => 'Mission staff';

  @override
  String get modulePickerExternal => 'External';

  @override
  String get modulePickerNoMatches => 'Nobody matches that search';

  @override
  String get modulePickerFree => 'Not in any file';

  @override
  String modulePickerAlreadyIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Already in $count files',
      one: 'Already in 1 file',
    );
    return '$_temp0';
  }

  @override
  String modulePickerConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Confirm $count people',
      one: 'Confirm 1 person',
      zero: 'Confirm with nobody chosen',
    );
    return '$_temp0';
  }

  @override
  String get referenceShelfPlaces => 'Places';

  @override
  String get referenceShelfStructure => 'File divisions';

  @override
  String get referenceShelfMission => 'The mission';

  @override
  String get referenceShelfReports => 'Report inputs';

  @override
  String get referenceShelfOther => 'Other';

  @override
  String get referenceDataTitle => 'Master data';

  @override
  String referenceItemsCount(int count) {
    return '$count entries';
  }

  @override
  String get referenceImport => 'Import from another season';

  @override
  String get referenceImportPick =>
      'Copy the list from an earlier season. The copies are independent — deleting one here does not touch the other season.';

  @override
  String referenceImported(int count) {
    return 'Imported $count entries';
  }

  @override
  String get referenceImportFailed => 'Import failed';

  @override
  String get referenceImportNoSeasons => 'No other seasons';

  @override
  String get referenceAddItem => 'Add entry';

  @override
  String get referenceItemName => 'Name (Arabic)';

  @override
  String get referenceItemNameEn => 'Name (English)';

  @override
  String get referenceItemSaved => 'Entry saved';

  @override
  String get referenceItemDeleted => 'Entry deleted';

  @override
  String get referenceDivisionAll => 'All';

  @override
  String get referenceDivisionNone => 'Unclassified';

  @override
  String get referenceEmpty => 'No entries yet';

  @override
  String referenceDeleteConfirm(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get referenceInUse =>
      'This entry is used by a module and cannot be deleted';

  @override
  String get referenceDuplicate =>
      'An entry with this name already exists in the list';

  @override
  String get referenceDeleteAll => 'Delete all';

  @override
  String referenceDeleteAllConfirm(int count, String name) {
    return 'This permanently deletes $count entries from “$name”. It cannot be undone.';
  }

  @override
  String referenceDeleteAllDone(int count) {
    return 'Deleted $count entries';
  }

  @override
  String referenceDeleteAllPartial(int deleted, int kept) {
    return 'Deleted $deleted; $kept kept because they are used by modules or other lists';
  }

  @override
  String get referenceDeleteAllNone =>
      'Nothing was deleted: every entry is used by a module or another list';

  @override
  String get referenceDeletingAll => 'Deleting…';

  @override
  String get referenceOpenLink => 'Open link';

  @override
  String get locationPickerTitle => 'Set location';

  @override
  String get locationPickOnMap => 'On the map';

  @override
  String get locationUseCurrent => 'My location';

  @override
  String get locationOrPasteLink => 'Or paste a map link';

  @override
  String get locationTapToPlace => 'Tap the map to place the pin';

  @override
  String get locationConfirm => 'Confirm this location';

  @override
  String get locationCaptured => 'Current location captured';

  @override
  String get locationPermissionDenied => 'Location access was not granted';

  @override
  String get locationServiceDisabled => 'Location services are turned off';

  @override
  String get locationFailed => 'Could not determine your location';

  @override
  String get locationOpenMap => 'Open on map';

  @override
  String get referenceCall => 'Call';

  @override
  String get referenceLinkFailed => 'Could not open the link';

  @override
  String get referenceDetailsTitle => 'Details';

  @override
  String get profileSectionPermissions => 'Permissions';

  @override
  String get profilePermissionsAdmin => 'Administrator — every permission';

  @override
  String get profilePermissionsNone => 'No administrative permissions';

  @override
  String get profilePermissionsNoneHint =>
      'Which is the ordinary case: an operational file reaches you by assignment, not by permission.';

  @override
  String profilePermissionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count permissions',
      one: 'one permission',
    );
    return '$_temp0';
  }

  @override
  String get navAuditLog => 'Activity log';

  @override
  String get navAuditLogSubtitle => 'Who did what, and when';

  @override
  String get auditEmptyTitle => 'No events yet';

  @override
  String get auditEmptyBody => 'Every change made in the app is recorded here.';

  @override
  String get auditPulseTitle => 'Activity';

  @override
  String get auditPulseByAction => 'By kind of act';

  @override
  String get auditPulseEmpty => 'Nothing happened in this window';

  @override
  String auditPulseEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: 'no events',
    );
    return '$_temp0';
  }

  @override
  String auditPulseActors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
      zero: 'nobody',
    );
    return '$_temp0';
  }

  @override
  String get auditSearchHint => 'Search by person or record…';

  @override
  String get auditActionInsert => 'Added';

  @override
  String get auditActionUpdate => 'Edited';

  @override
  String get auditActionDelete => 'Deleted';

  @override
  String get auditActionLogin => 'Signed in';

  @override
  String get auditActionLogout => 'Signed out';

  @override
  String get auditFilterAction => 'Action';

  @override
  String get auditFilterEntity => 'Section';

  @override
  String get auditFilterActor => 'Person';

  @override
  String get auditFilterSeason => 'Season';

  @override
  String get auditSeasonNone => 'No season';

  @override
  String auditSeasonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: 'No events',
    );
    return '$_temp0';
  }

  @override
  String get auditFilterDate => 'Period';

  @override
  String get auditClearFilters => 'Clear filters';

  @override
  String get auditSystem => 'System';

  @override
  String get auditDetails => 'Event details';

  @override
  String get auditActor => 'Done by';

  @override
  String get auditChanges => 'What changed';

  @override
  String get auditRecordData => 'Record data';

  @override
  String get auditDeletedData => 'Deleted record';

  @override
  String auditRecipients(int count) {
    return '$count recipients';
  }

  @override
  String get auditYes => 'Yes';

  @override
  String get auditNo => 'No';

  @override
  String get auditNoDetails => 'This event carries no further details.';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navDashboardSubtitle => 'The season from above';

  @override
  String get chartOther => 'Other';

  @override
  String get chartTotal => 'Total';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardSeason => 'Season';

  @override
  String get dashboardNoSeason => 'No season yet';

  @override
  String get dashboardNothingToShow =>
      'You hold no permission that shows figures here';

  @override
  String get dashboardSectionPeople => 'People';

  @override
  String get dashboardSectionModules => 'Operational files';

  @override
  String get dashboardSectionWork => 'The work';

  @override
  String get dashboardSectionQueue => 'Approvals';

  @override
  String get dashboardSectionCentralReports => 'Decisions';

  @override
  String get dashboardCentralPublished => 'Published';

  @override
  String get dashboardCentralDrafts => 'Drafts';

  @override
  String get dashboardCentralGeneral => 'General (all seasons)';

  @override
  String get dashboardCentralByType => 'By type';

  @override
  String get dashboardCentralSplit => 'Published vs drafts';

  @override
  String get dashboardSectionNotifications => 'Notifications';

  @override
  String get dashboardNotifMessages30 => 'Messages (30 days)';

  @override
  String get dashboardNotifRecipients => 'Recipients';

  @override
  String get dashboardNotifReadShare => 'Read rate';

  @override
  String dashboardNotifReadOf(int read, int total) {
    return '$read of $total opened';
  }

  @override
  String get dashboardNotifTrend => 'Messages, last 30 days';

  @override
  String get dashboardNotifTrendEmpty => 'No messages in the last 30 days';

  @override
  String dashboardNotifAllTime(Object n) {
    return '$n messages all-time';
  }

  @override
  String get dashboardNotSeasonScoped =>
      'All seasons — not filtered by the one selected';

  @override
  String get dashboardSectionIncidents => 'Urgent reports';

  @override
  String get dashboardIncidentsOpen => 'Open reports';

  @override
  String dashboardIncidentsInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count in progress',
      one: 'and 1 in progress',
      zero: 'none in progress',
    );
    return '$_temp0';
  }

  @override
  String get dashboardIncidentsRecent => 'Reports, last 30 days';

  @override
  String dashboardIncidentsAllTime(int count) {
    return '$count all time';
  }

  @override
  String get dashboardIncidentsAvgHandle => 'Average time to pick up';

  @override
  String get dashboardIncidentsAvgHandleCaption => 'From raised to taken on';

  @override
  String get dashboardIncidentsSplit => 'Reports by state';

  @override
  String get dashboardIncidentsTrend => 'Reports per day';

  @override
  String get dashboardIncidentsTrendEmpty => 'No reports in this period';

  @override
  String get dashboardSectionCheckIn => 'Check-in';

  @override
  String get dashboardCheckInToday => 'Today\'s arrivals';

  @override
  String get dashboardCheckInPeople => 'People who filed';

  @override
  String dashboardCheckInPlaces(int count) {
    return 'at $count places';
  }

  @override
  String get dashboardCheckInTotal => 'Arrivals this season';

  @override
  String get dashboardCheckInTrend => 'Arrivals per day';

  @override
  String get dashboardCheckInTrendEmpty => 'No arrivals in this period';

  @override
  String get dashboardSectionTasks => 'Assigned tasks';

  @override
  String get dashboardTasksOpen => 'Open tasks';

  @override
  String get dashboardTasksLate => 'Late';

  @override
  String dashboardTasksEscalated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count escalated',
      one: '1 escalated',
      zero: 'none escalated',
    );
    return '$_temp0';
  }

  @override
  String get dashboardTasksAwaiting => 'Awaiting review';

  @override
  String get dashboardTasksAssignees => 'Assignees';

  @override
  String dashboardTasksAllTime(int count) {
    return '$count tasks all time';
  }

  @override
  String get dashboardTasksByState => 'Tasks by state';

  @override
  String get dashboardTasksByPriority => 'Open tasks by priority';

  @override
  String get dashboardSectionEvaluations => 'Evaluations';

  @override
  String get dashboardEvalSubmitted => 'Sheets submitted';

  @override
  String dashboardEvalOf(int count) {
    return 'of $count';
  }

  @override
  String get dashboardEvalLate => 'Late';

  @override
  String dashboardEvalDrafts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drafts',
      one: '1 draft',
      zero: 'no drafts',
    );
    return '$_temp0';
  }

  @override
  String get dashboardEvalAverage => 'Average';

  @override
  String get dashboardEvalAverageCaption => 'As a share of each form\'s total';

  @override
  String get dashboardEvalEvaluators => 'Evaluators';

  @override
  String get dashboardSectionComplaints => 'Complaints';

  @override
  String get dashboardComplaintsOpen => 'Open complaints';

  @override
  String get dashboardComplaintsRecent => 'Complaints, last 30 days';

  @override
  String dashboardComplaintsAllTime(int count) {
    return '$count all time';
  }

  @override
  String get dashboardComplaintsDismissed => 'Dismissed';

  @override
  String dashboardComplaintsLocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count locked',
      one: 'and 1 locked',
      zero: 'none locked',
    );
    return '$_temp0';
  }

  @override
  String get dashboardComplaintsByTarget => 'Complaints by subject';

  @override
  String get dashboardSectionReference => 'Master data';

  @override
  String get dashboardRefSets => 'Lists';

  @override
  String get dashboardRefItems => 'Entries';

  @override
  String get dashboardRefActive => 'Active';

  @override
  String get dashboardRefSeasonSplit => 'Seasonal vs general';

  @override
  String get dashboardRefSeasonItems => 'This season';

  @override
  String get dashboardRefGeneralItems => 'General';

  @override
  String get dashboardRefBySet => 'Entries per list';

  @override
  String get dashboardSectionPermissions => 'Permissions';

  @override
  String get dashboardPermAdmins => 'Admins';

  @override
  String get dashboardPermGrantees => 'Employees with grants';

  @override
  String get dashboardPermGrants => 'Grants held';

  @override
  String get dashboardPermBySection => 'Grants by section';

  @override
  String get dashboardParticipants => 'On this season';

  @override
  String get dashboardWithdrawn => 'Withdrawn';

  @override
  String dashboardWithdrawnCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count withdrew',
      one: 'and one withdrew',
      zero: 'nobody withdrew',
    );
    return '$_temp0';
  }

  @override
  String get dashboardInternalSplit => 'Mission and outside';

  @override
  String get dashboardInternal => 'Of the mission';

  @override
  String get dashboardExternal => 'From outside';

  @override
  String get dashboardUnknown => 'Not stated';

  @override
  String get dashboardByMission => 'By mission type';

  @override
  String get dashboardByGender => 'By gender';

  @override
  String get dashboardByJobTitle => 'Largest trades';

  @override
  String get dashboardFiles => 'Files';

  @override
  String dashboardFilesCaption(int active, int draft) {
    return '$active active, $draft draft';
  }

  @override
  String get dashboardRunning => 'Running';

  @override
  String get dashboardEnded => 'Ended';

  @override
  String get dashboardNodes => 'Sectors and towers';

  @override
  String get dashboardMembers => 'Hold a posting';

  @override
  String get dashboardUnstaffed => 'Files with nobody in them';

  @override
  String get dashboardUnstaffedCaption => 'Nobody assigned yet';

  @override
  String get dashboardByType => 'By file type';

  @override
  String get dashboardActiveDraft => 'Active against draft';

  @override
  String get dashboardReports => 'Decisions';

  @override
  String dashboardReportsCaption(int authors) {
    String _temp0 = intl.Intl.pluralLogic(
      authors,
      locale: localeName,
      other: 'from $authors authors',
      one: 'from one author',
      zero: 'from nobody',
    );
    return '$_temp0';
  }

  @override
  String get dashboardReportsTrend => 'Decisions over 30 days';

  @override
  String get dashboardReportsEmpty => 'No reports filed in this stretch';

  @override
  String get dashboardRatings => 'Ratings';

  @override
  String get dashboardAverage => 'Average';

  @override
  String dashboardRatedPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'about $count people',
      one: 'about one person',
      zero: 'nobody rated',
    );
    return '$_temp0';
  }

  @override
  String get dashboardRatingDistribution => 'Star distribution';

  @override
  String get dashboardPending => 'Awaiting approval';

  @override
  String get dashboardApproved => 'Approved';

  @override
  String get dashboardRejected => 'Rejected';

  @override
  String get dashboardIncomplete => 'Profile incomplete';

  @override
  String get prayerTimesTitle => 'Prayer times';

  @override
  String get prayerFajr => 'Fajr';

  @override
  String get prayerSunrise => 'Sunrise';

  @override
  String get prayerDhuhr => 'Dhuhr';

  @override
  String get prayerAsr => 'Asr';

  @override
  String get prayerMaghrib => 'Maghrib';

  @override
  String get prayerIsha => 'Isha';

  @override
  String get prayerNextLabel => 'Next prayer';

  @override
  String get prayerFajrEndsLabel => 'Fajr time ends';

  @override
  String get prayerRemainingLabel => 'remaining';

  @override
  String get prayerNowLabel => 'Now';

  @override
  String get prayerAm => 'AM';

  @override
  String get prayerPm => 'PM';

  @override
  String get prayerTomorrow => 'tomorrow';

  @override
  String get prayerSunriseGapNote => 'Sunrise — no prayer is due until Dhuhr';

  @override
  String get prayerLocating => 'Finding you…';

  @override
  String get prayerApproximate => 'Approximate';

  @override
  String get prayerYourLocation => 'Your location';

  @override
  String get prayerPlaceMakkah => 'Makkah';

  @override
  String get prayerPlaceMina => 'Mina';

  @override
  String get prayerPlaceMuzdalifah => 'Muzdalifah';

  @override
  String get prayerPlaceArafat => 'Arafat';

  @override
  String get prayerPlaceMadinah => 'Madinah';

  @override
  String get prayerPlaceJeddah => 'Jeddah';

  @override
  String get prayerAlertsTitle => 'Prayer alerts';

  @override
  String get prayerAlertsEnable => 'Announce the prayers';

  @override
  String get prayerAlertsHint =>
      'This phone alone. Times are worked out on the device from where it is standing — nothing is sent from a server.';

  @override
  String get prayerAlertsWhich => 'Which prayers';

  @override
  String get prayerAlertsBefore => 'Warning before the call';

  @override
  String get prayerAlertsBeforeOff => 'None';

  @override
  String prayerAlertsMinutes(int count) {
    return '$count min';
  }

  @override
  String get prayerAlertsSilent => 'Without a sound';

  @override
  String get prayerAlertsSilentHint => 'It still appears and still vibrates.';

  @override
  String get prayerAlertsBlocked =>
      'Notifications are switched off for this app in the system settings.';

  @override
  String get prayerAlertsInexact =>
      'Android may hold these back by several minutes. Allow exact alarms so each call arrives on the minute.';

  @override
  String get prayerAlertsGrantExact => 'Allow exact alarms';

  @override
  String get prayerAlertsNeedLocation =>
      'Set your location on the prayer card first — nothing is announced from an approximate position.';

  @override
  String get prayerAlertsUnsupported => 'Prayer alerts are an Android feature.';

  @override
  String prayerAlertNow(String prayer) {
    return '$prayer is now due';
  }

  @override
  String prayerAlertNowBody(String clock) {
    return 'The call is at $clock';
  }

  @override
  String prayerAlertBefore(String prayer, int count) {
    return '$prayer in $count minutes';
  }

  @override
  String prayerAlertBeforeBody(String clock) {
    return 'The call is at $clock';
  }

  @override
  String get navMyComplaints => 'Complaints';

  @override
  String get navMyComplaintsSubtitle => 'What you filed, and what came back';

  @override
  String get navComplaints => 'Complaints register';

  @override
  String get navComplaintsSubtitle =>
      'Every complaint filed across the mission';

  @override
  String get complaintsTitle => 'Complaints';

  @override
  String get complaintsMineTitle => 'My complaints';

  @override
  String get complaintsAgainstMeTitle => 'Complaints about me';

  @override
  String get complaintsNew => 'File a complaint';

  @override
  String get complaintsEmpty => 'No complaints filed';

  @override
  String get complaintsEmptyHint => 'File your first one with the button below';

  @override
  String get complaintsEmptyAll => 'Nothing has been filed yet';

  @override
  String get complaintsEmptyAllHint =>
      'What staff file appears here as soon as it is filed';

  @override
  String get complaintsAgainstMeEmpty => 'Nothing has been filed about you';

  @override
  String get complaintsNoMatches => 'No complaint matches this';

  @override
  String get complaintsNoMatchesHint => 'Widen the search or clear the filters';

  @override
  String get complaintsSearchHint => 'Search complaints';

  @override
  String get complaintsFilterAll => 'All';

  @override
  String get complaintsShowDismissed => 'Include dismissed';

  @override
  String get complaintTarget => 'About';

  @override
  String get complaintTargetEmployee => 'An employee';

  @override
  String get complaintTargetModule => 'An operational file';

  @override
  String get complaintTargetReport => 'A decision';

  @override
  String get complaintTargetHotel => 'A hotel';

  @override
  String get complaintTargetCluster => 'A cluster';

  @override
  String get complaintTargetGroup => 'A group';

  @override
  String get complaintTargetOther => 'Something else';

  @override
  String get complaintTargetPick => 'Choose what this is about';

  @override
  String complaintTargetNone(String kind) {
    return 'No $kind you can complain about: this lists the files you are posted to and the people you work with in them. Choose “Something else” and explain it in the complaint itself.';
  }

  @override
  String complaintTargetPicked(String name) {
    return 'Selected: $name';
  }

  @override
  String get complaintBody => 'What happened';

  @override
  String get complaintBodyHint => 'Describe it in your own words';

  @override
  String get complaintBodyRequired => 'Write what happened';

  @override
  String get complaintTargetRequired => 'Choose what the complaint is about';

  @override
  String get complaintSubmit => 'Send the complaint';

  @override
  String get complaintSubmitted => 'Your complaint was filed';

  @override
  String get complaintAnonymousNote =>
      'The person you are complaining about will read this, but will not be told who filed it.';

  @override
  String get complaintReply => 'Reply';

  @override
  String get complaintReplyHint => 'Write a reply';

  @override
  String get complaintReplySent => 'Reply sent';

  @override
  String complaintReplyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '1 reply',
      zero: 'No replies',
    );
    return '$_temp0';
  }

  @override
  String get complaintRoleComplainant => 'The complainant';

  @override
  String get complaintRoleAccused => 'The employee complained about';

  @override
  String get complaintRoleManager => 'Oversight';

  @override
  String get complaintLocked => 'This complaint is closed to replies';

  @override
  String get complaintLock => 'Close to replies';

  @override
  String get complaintUnlock => 'Reopen for replies';

  @override
  String get complaintDismissed => 'Dismissed';

  @override
  String get complaintDismiss => 'Dismiss as unfounded';

  @override
  String get complaintUndismiss => 'Reinstate';

  @override
  String get complaintDismissReason => 'Why it is being dismissed (optional)';

  @override
  String get complaintDismissConfirm =>
      'A dismissed complaint no longer counts toward an automatic suspension, and may lift one already in force. Dismiss it?';

  @override
  String get complaintDelete => 'Delete the complaint';

  @override
  String get complaintDeleteConfirm =>
      'Delete this complaint and everything attached to it? This cannot be undone.';

  @override
  String get complaintDeleted => 'Complaint deleted';

  @override
  String get complaintWithdraw => 'Withdraw';

  @override
  String get complaintMissing => 'This complaint is no longer there';

  @override
  String complaintFiledOn(String date) {
    return 'Filed $date';
  }

  @override
  String get complaintsSectionAgainst => 'Complaints about this employee';

  @override
  String complaintsAgainstCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count complaints',
      one: '1 complaint',
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String complaintsDistinctComplainants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count different people',
      one: '1 person',
      zero: 'no one',
    );
    return '$_temp0';
  }

  @override
  String get complaintsAutoSuspended => 'Suspended automatically by complaints';

  @override
  String get complaintsAutoSuspendNear =>
      'One more complainant suspends this account automatically';

  @override
  String complaintsDismissedCount(int count) {
    return '$count dismissed';
  }

  @override
  String get navEvaluations => 'Evaluations';

  @override
  String get navEvaluationsSubtitle => 'What you were asked to evaluate';

  @override
  String get navEvaluationsManage => 'Evaluation register';

  @override
  String get navEvaluationsManageSubtitle =>
      'Every evaluation across the mission and its marks';

  @override
  String get navEvaluationForms => 'Evaluation forms';

  @override
  String get navEvaluationFormsSubtitle =>
      'The forms, their questions and their marks';

  @override
  String get evaluationsTitle => 'Evaluation register';

  @override
  String get evaluationsMineTitle => 'My evaluations';

  @override
  String get evaluationsEmpty =>
      'You have not been asked to evaluate anything yet';

  @override
  String get evaluationsEmptyAll => 'No evaluation has been opened yet';

  @override
  String get evaluationsNoMatches => 'No matches';

  @override
  String get evaluationsSearchHint => 'Search by form or subject';

  @override
  String get evaluationsFilterAll => 'All';

  @override
  String get evaluationsNew => 'New evaluation';

  @override
  String evaluationsOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count outstanding',
      one: '1 outstanding',
      zero: 'nothing outstanding',
    );
    return '$_temp0';
  }

  @override
  String evaluationsOverdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count overdue',
      one: '1 overdue',
      zero: 'none overdue',
    );
    return '$_temp0';
  }

  @override
  String get evaluationStatusDraft => 'In progress';

  @override
  String get evaluationStatusSubmitted => 'Completed';

  @override
  String get evaluationOverdue => 'Overdue';

  @override
  String evaluationDueOn(String date) {
    return 'Due $date';
  }

  @override
  String evaluationOpenedOn(String date) {
    return 'Opened $date';
  }

  @override
  String evaluationSubmittedOn(String date) {
    return 'Completed $date';
  }

  @override
  String get evaluationEvaluator => 'Evaluator';

  @override
  String get evaluationEvaluatorHidden => 'Evaluator not disclosed';

  @override
  String get evaluationSubject => 'Subject';

  @override
  String get evaluationNote => 'Note from the office';

  @override
  String evaluationProgress(int answered, int total) {
    return '$answered of $total';
  }

  @override
  String evaluationScore(String score, String total) {
    return '$score of $total';
  }

  @override
  String evaluationPercent(String percent) {
    return '$percent%';
  }

  @override
  String get evaluationTargetEmployee => 'Employee';

  @override
  String get evaluationTargetModule => 'Operational file';

  @override
  String get evaluationTargetReport => 'Decision';

  @override
  String get evaluationTargetHotel => 'Hotel';

  @override
  String get evaluationTargetCluster => 'Cluster';

  @override
  String get evaluationTargetGroup => 'Group';

  @override
  String get evaluationTargetOther => 'Other';

  @override
  String get evaluationSheetTitle => 'Evaluation';

  @override
  String evaluationStageOf(int index, int total) {
    return 'Stage $index of $total';
  }

  @override
  String evaluationStageScore(String score, String total) {
    return 'Stage mark $score of $total';
  }

  @override
  String get evaluationQuestionRequired => 'Required';

  @override
  String get evaluationQuestionOptional => 'Optional';

  @override
  String get evaluationQuestionUnanswered => 'Not answered';

  @override
  String get evaluationWriteHint => 'Write your answer';

  @override
  String get evaluationSaveDraft => 'Save';

  @override
  String get evaluationSubmit => 'Submit evaluation';

  @override
  String get evaluationSubmitted => 'Evaluation submitted';

  @override
  String get evaluationDraftSaved => 'Answers saved';

  @override
  String get evaluationIncomplete => 'Answer every required question first';

  @override
  String get evaluationReopen => 'Reopen';

  @override
  String get evaluationReopened => 'Evaluation reopened';

  @override
  String get evaluationReopenConfirm =>
      'This returns the evaluation to in-progress and keeps the answers. Continue?';

  @override
  String get evaluationNext => 'Next';

  @override
  String get evaluationBack => 'Back';

  @override
  String get evaluationLocked => 'This evaluation is read-only';

  @override
  String get evaluationDiscardChanges =>
      'There are unsaved answers. Leave without saving?';

  @override
  String get evaluationMissing => 'Evaluation not found';

  @override
  String get evaluationAlreadySubmitted =>
      'This evaluation was already submitted';

  @override
  String get evaluationDelete => 'Delete evaluation';

  @override
  String get evaluationDeleteConfirm =>
      'This evaluation and its answers are deleted permanently. Continue?';

  @override
  String get evaluationDeleted => 'Evaluation deleted';

  @override
  String get evaluationAssignTitle => 'Open an evaluation';

  @override
  String get evaluationAssignForm => 'Form';

  @override
  String get evaluationAssignPickForm => 'Choose an evaluation form';

  @override
  String get evaluationAssignNoForms =>
      'No active forms. Create one and switch it on first.';

  @override
  String get evaluationAssignSubject => 'Subject';

  @override
  String get evaluationAssignPickSubject => 'Choose the subject';

  @override
  String evaluationAssignSubjectPicked(String name) {
    return 'About: $name';
  }

  @override
  String get evaluationAssignEvaluator => 'Evaluator';

  @override
  String get evaluationAssignPickEvaluator => 'Choose the employee';

  @override
  String get evaluationAssignNoteHint => 'What should they look at? (optional)';

  @override
  String get evaluationAssignDue => 'Due date (optional)';

  @override
  String get evaluationAssignDueClear => 'No due date';

  @override
  String get evaluationAssignSubmit => 'Open and send';

  @override
  String get evaluationAssigned =>
      'Evaluation opened and the evaluator notified';

  @override
  String get evaluationAssignAnonymousNote =>
      'The employee sees their mark and never learns who wrote it.';

  @override
  String get evaluationFormsTitle => 'Evaluation forms';

  @override
  String get evaluationFormsEmpty => 'No evaluation forms yet';

  @override
  String get evaluationFormsNew => 'New form';

  @override
  String get evaluationFormsSearchHint => 'Search the forms';

  @override
  String get evaluationFormActive => 'Active';

  @override
  String get evaluationFormInactive => 'Off';

  @override
  String get evaluationFormActivate => 'Switch on';

  @override
  String get evaluationFormDeactivate => 'Switch off';

  @override
  String evaluationFormStages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stages',
      one: '1 stage',
    );
    return '$_temp0';
  }

  @override
  String evaluationFormQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$_temp0';
  }

  @override
  String evaluationFormTotal(String total) {
    return 'out of $total';
  }

  @override
  String evaluationFormInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count evaluations open on it',
      one: '1 evaluation open on it',
    );
    return '$_temp0';
  }

  @override
  String get evaluationFormDelete => 'Delete form';

  @override
  String get evaluationFormDeleteConfirm =>
      'This form, its stages and its questions are deleted. Continue?';

  @override
  String get evaluationFormDeleted => 'Form deleted';

  @override
  String get evaluationFormInUseDelete =>
      'A form with evaluations open on it cannot be deleted. Switch it off instead.';

  @override
  String get evaluationEditorNewTitle => 'New evaluation form';

  @override
  String get evaluationEditorTitle => 'Edit form';

  @override
  String get evaluationEditorName => 'Form name';

  @override
  String get evaluationEditorNameHint =>
      'e.g. Operational file evaluation - Tarwiyah and catering';

  @override
  String get evaluationEditorDescription => 'Short description (optional)';

  @override
  String get evaluationEditorFor => 'Evaluates';

  @override
  String get evaluationEditorForLocked =>
      'The subject kind cannot change once evaluations have been opened on the form';

  @override
  String get evaluationEditorPublish => 'Active for use';

  @override
  String get evaluationEditorPublishHint =>
      'A form that is switched off takes no new evaluations; the ones already open keep working';

  @override
  String get evaluationEditorStages => 'Stages';

  @override
  String get evaluationEditorAddStage => 'Add stage';

  @override
  String get evaluationEditorStageName => 'Stage name';

  @override
  String get evaluationEditorStageNameHint => 'e.g. Tarwiyah team';

  @override
  String get evaluationEditorStageDescription => 'Stage description (optional)';

  @override
  String get evaluationEditorRemoveStage => 'Delete stage';

  @override
  String get evaluationEditorRemoveStageConfirm =>
      'The stage and all its questions are deleted. Continue?';

  @override
  String get evaluationEditorAddChoice => 'Multiple-choice question';

  @override
  String get evaluationEditorAddWritten => 'Written question';

  @override
  String get evaluationEditorQuestionText => 'Question';

  @override
  String get evaluationEditorQuestionPoints => 'Question mark';

  @override
  String get evaluationEditorRequired => 'Required';

  @override
  String get evaluationEditorAddOption => 'Add answer';

  @override
  String get evaluationEditorOptionText => 'Answer';

  @override
  String get evaluationEditorOptionPoints => 'Mark';

  @override
  String get evaluationEditorNoQuestions => 'No questions in this stage yet';

  @override
  String get evaluationEditorWrittenNote =>
      'A written question carries no mark - neither the question nor its answer';

  @override
  String evaluationEditorUnreachable(String best, String points) {
    return 'The best answer gives $best while the question is worth $points';
  }

  @override
  String get evaluationEditorNeedsTwoOptions =>
      'A multiple-choice question needs at least two answers';

  @override
  String evaluationEditorTotal(String total) {
    return 'Form total: $total';
  }

  @override
  String get evaluationEditorSave => 'Save form';

  @override
  String get evaluationEditorSaved => 'Form saved';

  @override
  String get evaluationEditorCannotPublish =>
      'Finish the form before switching it on: every stage needs a name, every question needs text, and every multiple-choice question needs at least two answers';

  @override
  String get evaluationEditorMoveUp => 'Move up';

  @override
  String get evaluationEditorMoveDown => 'Move down';

  @override
  String get evaluationsAboutMeTitle => 'Evaluations about me';

  @override
  String get evaluationsAboutMeEmpty =>
      'No evaluation has been written about you';

  @override
  String get evaluationsSectionAbout => 'Evaluations of this subject';

  @override
  String evaluationsAboutCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count evaluations',
      one: '1 evaluation',
      zero: 'No evaluations',
    );
    return '$_temp0';
  }

  @override
  String evaluationsAboutPending(int count) {
    return '$count in progress';
  }

  @override
  String evaluationsAboutAverage(String percent) {
    return 'Average $percent%';
  }

  @override
  String get evaluationsAboutAnonymousNote =>
      'Marks are shown without the names of who wrote them.';

  @override
  String get evaluationErrorOptionTooHigh =>
      'An answer is worth more than the question it answers';

  @override
  String get evaluationErrorWrittenHasOptions =>
      'A written question takes no preset answers';

  @override
  String get evaluationsOpenFromForms =>
      'Evaluations are opened from إدارة التقييم, standing on the form they will be filled on';

  @override
  String evaluationAssignNoTargets(String kind) {
    return 'There is nothing of kind «$kind» to open an evaluation about';
  }

  @override
  String get evaluationAssignNoEvaluators =>
      'There is no employee who can be assigned';

  @override
  String get evaluationFormMustBeActive =>
      'Switch the form on before an evaluation can be opened on it';

  @override
  String get evaluationEditorForHint =>
      'This picks the KIND of subject only. The particular file or employee is named when an evaluation is opened on this form — from the «New evaluation» button on its card, once the form is switched on.';

  @override
  String get evaluationAssignNoSeason =>
      'The current season could not be read, and the evaluator cannot be chosen without it';

  @override
  String get evaluationAssignedShow => 'View';

  @override
  String get evaluationAssignSubjects => 'Subjects';

  @override
  String get evaluationAssignEvaluators => 'Evaluators';

  @override
  String get evaluationAssignPickSubjects => 'Choose the subjects';

  @override
  String get evaluationAssignPickEvaluators => 'Choose the employees';

  @override
  String get evaluationAssignAddMore => 'Add';

  @override
  String evaluationAssignPlanned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count evaluations will be opened',
      one: '1 evaluation will be opened',
      zero: 'No evaluation will be opened',
    );
    return '$_temp0';
  }

  @override
  String evaluationAssignCross(int targets, int evaluators) {
    return 'One per subject per evaluator — $targets × $evaluators';
  }

  @override
  String evaluationAssignedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count evaluations opened and their evaluators notified',
      one: '1 evaluation opened and its evaluator notified',
    );
    return '$_temp0';
  }

  @override
  String get evaluationFormShowEvaluations => 'Show the evaluations on it';

  @override
  String evaluationSubjectEvaluators(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count evaluators',
      one: '1 evaluator',
      zero: 'No evaluator',
    );
    return '$_temp0';
  }

  @override
  String get evaluationSubjectProgressLabel => 'Progress';

  @override
  String get evaluationStatAverage => 'Average';

  @override
  String get evaluationStatBest => 'Highest';

  @override
  String get evaluationStatWorst => 'Lowest';

  @override
  String get evaluationSubjectNoMarks => 'No marks yet';

  @override
  String get commonOk => 'OK';

  @override
  String get locationResolved => 'Coordinates read from the link';

  @override
  String get seasonMapOnlyThis => 'Tap to show only this';

  @override
  String get seasonMapShowAll => 'Show all';

  @override
  String get seasonMapNoTiles =>
      'The map backdrop could not be loaded — the positions are right, only the pictures are missing';

  @override
  String get seasonMapTitle => 'Season map';

  @override
  String get seasonMapSubtitle =>
      'The season\'s places and open reports on one map';

  @override
  String get seasonMapManned => 'Somebody is there';

  @override
  String get seasonMapUnmanned => 'Nobody checked in';

  @override
  String get seasonMapIncident => 'Open report';

  @override
  String get seasonMapEmpty => 'No members';

  @override
  String get seasonMapPosted => 'Posted here';

  @override
  String get seasonMapPresent => 'Checked in';

  @override
  String get seasonMapOpenIncidents => 'Open incidents';

  @override
  String get seasonMapCopyCoordinates => 'Copy coordinates';

  @override
  String get seasonMapCoordinatesCopied => 'Coordinates copied';

  @override
  String get seasonMapPlaces => 'Places';

  @override
  String get seasonMapIncidents => 'Reports';

  @override
  String seasonMapCounts(int places, int incidents) {
    return '$places places · $incidents reports';
  }

  @override
  String get seasonMapEmptyState => 'No place in this season has a position';

  @override
  String get seasonMapEmptyStateHint =>
      'A place appears here once its position is set on the hotels or camps list';

  @override
  String get incidentTitle => 'Urgent report';

  @override
  String get incidentHint =>
      'For what cannot wait — a breakdown, an accident, a cut-off. It reaches the operations room immediately.';

  @override
  String get incidentBodyHint => 'What has happened?';

  @override
  String get incidentAttach => 'Attach a photo';

  @override
  String get incidentSend => 'Send the report';

  @override
  String get incidentSending => 'Sending…';

  @override
  String get incidentSent => 'The operations room has been alerted';

  @override
  String get incidentWhatIsAttached =>
      'Attached automatically: your name, your position, the time';

  @override
  String get incidentAbout => 'What is it about? (optional)';

  @override
  String get incidentAboutKind => 'What does the report concern?';

  @override
  String get incidentAboutModule => 'An operational file';

  @override
  String get incidentAboutEmployee => 'A member of staff';

  @override
  String get incidentAboutPage => 'A screen in the app';

  @override
  String get incidentAboutClear => 'Nothing in particular';

  @override
  String get incidentAboutNoModules =>
      'No operational files in the current season';

  @override
  String get incidentAboutNoSeason =>
      'The current season could not be determined';

  @override
  String incidentAboutLabel(String what) {
    return 'About: $what';
  }

  @override
  String get incidentOpenPage => 'Open the screen';

  @override
  String get incidentOpenModule => 'Open the file';

  @override
  String get incidentNotInRegister =>
      'That report is no longer in the register';

  @override
  String get incidentsShowAll => 'Show the whole register';

  @override
  String get incidentsOneReport => 'One report';

  @override
  String get incidentNotDeliveredTitle => 'It did not go through';

  @override
  String get incidentNotDeliveredBody =>
      'There is no network. The report is saved on your device and will be sent when it returns — but **nobody has been told yet**. If this cannot wait, telephone the operations room now.';

  @override
  String get incidentsTitle => 'Urgent reports';

  @override
  String get incidentsEmpty => 'No open reports';

  @override
  String get incidentsEmptyHint =>
      'Every urgent report appears here the moment it arrives';

  @override
  String get incidentsShowClosed => 'Show closed';

  @override
  String get incidentStateOpen => 'Open';

  @override
  String get incidentStateInProgress => 'In progress';

  @override
  String get incidentStateClosed => 'Closed';

  @override
  String get incidentTake => 'I\'ll take it';

  @override
  String get incidentClose => 'Close the report';

  @override
  String get incidentReopen => 'Reopen';

  @override
  String get incidentResolutionHint => 'What happened? (optional)';

  @override
  String get incidentCall => 'Call';

  @override
  String get incidentOpenMap => 'Position';

  @override
  String incidentWaited(String duration) {
    return 'Waiting $duration';
  }

  @override
  String incidentHandledBy(String name) {
    return 'Taken by $name';
  }

  @override
  String incidentOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open reports',
      one: '1 open report',
      zero: 'No open reports',
    );
    return '$_temp0';
  }

  @override
  String get attachmentPickFailed =>
      'Couldn\'t open the picker. Try attaching another way.';

  @override
  String get incidentDelete => 'Delete report';

  @override
  String get incidentDeleteConfirm =>
      'The report and anything attached to it are erased for good, and it leaves everyone\'s register. This cannot be undone.';

  @override
  String get incidentDeleted => 'Report deleted';

  @override
  String get incidentsClear => 'Clear the register';

  @override
  String get incidentsClearWhat => 'What should be deleted?';

  @override
  String get incidentsClearClosed => 'Closed ones only';

  @override
  String get incidentsClearClosedHint =>
      'Every open or in-progress report stays exactly as it is';

  @override
  String get incidentsClearAll => 'Every report';

  @override
  String get incidentsClearAllHint =>
      'Open ones included — they vanish from the screen of everyone watching the register right now';

  @override
  String incidentsCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reports deleted',
      one: '1 report deleted',
      zero: 'Nothing was deleted',
    );
    return '$_temp0';
  }

  @override
  String get incidentAlarmTitle => 'Urgent report';

  @override
  String get incidentAlarmOpen => 'Open the register';

  @override
  String get incidentAlarmDismiss => 'Dismiss';

  @override
  String incidentAlarmMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more',
      one: 'and 1 more',
    );
    return '$_temp0';
  }

  @override
  String get navMyIncidentsSubtitle =>
      'The urgent reports you raised, and their status now';

  @override
  String get myIncidentsTitle => 'My reports';

  @override
  String get myIncidentsEmpty => 'You have not raised an urgent report yet';

  @override
  String get myIncidentsEmptyHint =>
      'Your urgent reports appear here the moment you raise one, with their status';

  @override
  String durationMinutes(int count) {
    return '${count}m';
  }

  @override
  String durationHours(int count) {
    return '${count}h';
  }

  @override
  String get checkInScanTitle => 'Scan the place code';

  @override
  String get checkInScanHint =>
      'Point the camera at the code fixed at the place';

  @override
  String get checkInTorch => 'Torch';

  @override
  String get checkInNoCamera =>
      'The camera could not be opened — the permission may be refused';

  @override
  String get checkInNoCameraHint =>
      'Checking in needs the code and your location together, so there is no way to do it without a camera';

  @override
  String get checkInTitle => 'Check in';

  @override
  String get checkInAction => 'Record my arrival';

  @override
  String get checkInSubtitle =>
      'Scan the code fixed to the hotel or camp while you are standing there';

  @override
  String get checkInPhoneOnly =>
      'Arrivals are filed from a phone — it takes a camera on the place\'s code while you are standing at it. Your record is readable from any device.';

  @override
  String get checkInScan => 'Scan the code';

  @override
  String get checkInNoteHint => 'Note (optional)';

  @override
  String get checkInDone => 'Your arrival was recorded';

  @override
  String checkInDoneAt(String place, String metres) {
    return 'Recorded — $place, $metres m away';
  }

  @override
  String get checkInQueued =>
      'Saved on the device — it will be recorded when the network returns';

  @override
  String checkInDistance(String metres) {
    return '$metres m away';
  }

  @override
  String get checkInNotApproved =>
      'Your account is not approved yet, so you cannot check in';

  @override
  String get checkInNotAPlace => 'That code does not belong to a current place';

  @override
  String get checkInNeedsAPosition =>
      'Not recorded: turn location on, then scan the code again';

  @override
  String get checkInCodeExpired =>
      'This code is no longer valid — look for the new one put up in its place';

  @override
  String get checkInPlaceHasNoLocation =>
      'This place has no location set, so how near you are cannot be checked. Tell the administration.';

  @override
  String get checkInTooFar =>
      'You are too far from this place — you must be at it to check in';

  @override
  String get checkInCodesDenied => 'You may not view place codes';

  @override
  String get checkInRotateDenied => 'You may not regenerate place codes';

  @override
  String get checkInQrTitle => 'Place code';

  @override
  String get checkInQrHint =>
      'Print this and fix it at the place — whoever arrives scans it to record their arrival';

  @override
  String get checkInQrPrint => 'Print or share';

  @override
  String get checkInQrShare => 'Share';

  @override
  String get checkInQrShareFailed => 'Sharing failed — use print instead';

  @override
  String get checkInQrSave => 'Save to this device';

  @override
  String checkInQrSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String get checkInQrSavedPlain => 'File saved';

  @override
  String get checkInQrSaveFailed => 'Could not save the file';

  @override
  String checkInQrRotatesOn(String when) {
    return 'Rotates automatically: $when';
  }

  @override
  String checkInQrRotatesSoon(String when) {
    return 'Rotates automatically on $when — print the replacement and put it up before that day, or nobody can check in here';
  }

  @override
  String get checkInQrCard => 'Check-in code';

  @override
  String checkInQrRotatedAt(String when) {
    return 'Last regenerated: $when';
  }

  @override
  String get checkInQrNoLocation =>
      'This place has no location — nobody can check in here until one is set';

  @override
  String get checkInQrRotate => 'Regenerate the code';

  @override
  String get checkInQrRotateConfirm =>
      'Every printed code for this place stops working immediately. The new one must be printed and put up before anybody can check in here.';

  @override
  String get checkInQrRotated => 'Regenerated — print it and put it up now';

  @override
  String get checkInQrPrintAll => 'Print the list\'s codes';

  @override
  String get checkInQrPrintingAll => 'Preparing the codes…';

  @override
  String get navMyCheckInsSubtitle =>
      'Where you checked in and when — and where you check in';

  @override
  String get myCheckInsTitle => 'My attendance';

  @override
  String get myCheckInsEmpty => 'You have not checked in yet';

  @override
  String get myCheckInsEmptyHint =>
      'Scan a place code with the button below while standing at it, and it appears here';

  @override
  String get myCheckInsWindowDay => 'Today';

  @override
  String get myCheckInsWindowWeek => 'This week';

  @override
  String get myCheckInsWindowAll => 'All';

  @override
  String get myCheckInsAllPlaces => 'All places';

  @override
  String myCheckInsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins',
      one: '1 check-in',
      zero: 'no check-ins',
    );
    return '$_temp0';
  }

  @override
  String get presenceTitle => 'Attendance record';

  @override
  String get presenceSubtitle =>
      'The latest arrivals across the season\'s places';

  @override
  String get presenceEmpty => 'Nobody has checked in yet';

  @override
  String get presenceTabPresent => 'Present';

  @override
  String get presenceTabGaps => 'Not checked in';

  @override
  String get presenceGapsEmpty => 'Every post is confirmed';

  @override
  String get presenceGapsEmptyHint =>
      'No post at a place is without a check-in within the chosen window';

  @override
  String get presenceGapNeverSeen => 'Never checked in';

  @override
  String presenceGapLastSeen(String time) {
    return 'Last seen $time';
  }

  @override
  String presenceGapCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
      zero: 'none',
    );
    return '$_temp0';
  }

  @override
  String get presenceEmptyHint =>
      'Whoever scans a place code while standing at it appears here';

  @override
  String get presenceWindow4h => '4 hours';

  @override
  String get presenceWindow12h => '12 hours';

  @override
  String get presenceWindow24h => '24 hours';

  @override
  String presenceCounts(int people, int places) {
    return '$people people in $places places';
  }

  @override
  String get exportTitle => 'Export data';

  @override
  String get exportSubtitle =>
      'Take any list out as a file — with the columns you choose';

  @override
  String get exportWhat => 'What do you want to export?';

  @override
  String get exportPickFirst => 'Choose one above';

  @override
  String get exportPickFirstHint =>
      'Once you have, what can be taken from it, the shape of the file, and the save and send buttons appear here.';

  @override
  String get exportWhichColumns => 'Columns';

  @override
  String get exportWholeRecord => 'Exported in full';

  @override
  String get exportWholeRecordHint =>
      'Nothing to tick here: the document is prose written in its own order, so it is printed whole — its details, its content block by block, its tables and what was attached.';

  @override
  String get exportColumnsDefault => 'Default';

  @override
  String get exportColumnsAll => 'All';

  @override
  String get exportPickAtLeastOne => 'Choose at least one column';

  @override
  String exportSensitiveNotice(String column) {
    return '\"$column\" is internal: whoever holds it can tie the person to their records in any other table. The file leaves under your name and outlives this screen — let it reach only whoever needs it.';
  }

  @override
  String get exportOptionAny => 'Leave empty to include all';

  @override
  String get exportFormat => 'File format';

  @override
  String get exportFormatCsv => 'CSV (Excel)';

  @override
  String get exportFormatPdf => 'PDF (for printing)';

  @override
  String get exportSave => 'Save to device';

  @override
  String get exportShare => 'Share';

  @override
  String exportSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get exportSaveFailed => 'Could not save the file';

  @override
  String get exportRunning => 'Preparing…';

  @override
  String exportDoneRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows exported',
      one: '1 row exported',
    );
    return '$_temp0';
  }

  @override
  String exportDoneRecords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count complete records exported',
      one: '1 complete record exported',
    );
    return '$_temp0';
  }

  @override
  String get exportNothingMatched =>
      'Nothing matched — check the options above';

  @override
  String get exportNothingAvailable => 'There is nothing you can export';

  @override
  String get exportNothingAvailableHint =>
      'Export covers what you are allowed to see';

  @override
  String get exportGeneratedBy => 'From the Hajj Mission management system';

  @override
  String get exportPage => 'Page';

  @override
  String get accountStatusIncomplete => 'Incomplete';

  @override
  String get accountStatusPending => 'Pending';

  @override
  String get accountStatusApproved => 'Approved';

  @override
  String get accountStatusRejected => 'Rejected';

  @override
  String get outboxSavedOffline =>
      'Saved on the device — it will be sent when the network returns';

  @override
  String offlineShowingSaved(String time) {
    return 'No network — showing a saved copy, last updated $time';
  }

  @override
  String get outboxTitle => 'Waiting to be sent';

  @override
  String get outboxEmpty => 'Nothing is waiting to be sent';

  @override
  String get outboxEmptyHint => 'Everything you wrote has reached the server';

  @override
  String outboxPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items waiting to be sent',
      one: '1 item waiting to be sent',
    );
    return '$_temp0';
  }

  @override
  String get outboxStateWaiting => 'Waiting for a network';

  @override
  String get outboxStateSending => 'Sending…';

  @override
  String get outboxStateBlocked => 'Not accepted';

  @override
  String outboxAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts',
      one: '1 attempt',
    );
    return '$_temp0';
  }

  @override
  String get outboxRetry => 'Try again';

  @override
  String get outboxDiscard => 'Delete';

  @override
  String get outboxDiscardTitle => 'Delete this item?';

  @override
  String get outboxDiscardBody =>
      'It will never reach the server, and cannot be brought back.';

  @override
  String get outboxKindTaskState => 'Duty state';

  @override
  String get outboxKindReport => 'File report';

  @override
  String outboxBlockedNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items were not accepted',
      one: '1 item was not accepted',
    );
    return '$_temp0';
  }

  @override
  String get settingsInApp => 'In the app';

  @override
  String get sidebarExpand => 'Expand the sidebar';

  @override
  String get sidebarCollapse => 'Collapse the sidebar';

  @override
  String get sidebarMenu => 'Menu';

  @override
  String get roadmapTitle => 'Operational roadmap';

  @override
  String get roadmapIntroTitle => 'How a season is run';

  @override
  String get roadmapIntroBody =>
      'Every other screen in this app answers where something is. This one answers when. A season is laid out below from the week before it opens to the week after it closes: five phases, each step saying what is done at it and what it is waiting on. The whole map is drawn for everybody — the steps that are not yours are marked so, because knowing that somebody had to fill in the master data before your file existed is part of knowing your own place in the season.';

  @override
  String get roadmapOpen => 'Open';

  @override
  String get roadmapLocked => 'In the Administration\'s hands';

  @override
  String get roadmapEveryone => 'Open to everyone';

  @override
  String roadmapPhaseLabel(int number) {
    return 'Phase $number';
  }

  @override
  String roadmapStepsOpen(int open, int total) {
    return '$open of $total steps are yours';
  }

  @override
  String get roadmapPhaseSetup => 'Laying the ground';

  @override
  String get roadmapPhaseSetupWhen => 'Weeks before the season';

  @override
  String get roadmapPhaseSetupBody =>
      'Nothing in this app stands on its own: every file, every task and every urgent report is filed against a season and built out of the reference lists. This phase is set once a year, and everything after it rests on it.';

  @override
  String get roadmapPhaseBuild => 'Building the work';

  @override
  String get roadmapPhaseBuildWhen => 'The month before';

  @override
  String get roadmapPhaseBuildBody =>
      'The paperwork the season will actually be worked through: which files exist, who is in them and in what role, what each person is told to do, and what the whole mission is to be told.';

  @override
  String get roadmapPhaseRun => 'Running the season';

  @override
  String get roadmapPhaseRunWhen => 'Dhul Hijjah itself';

  @override
  String get roadmapPhaseRunBody =>
      'The only phase most of the mission ever touches, and the only one measured in hours rather than weeks. Everything in it is open to everybody, and that is its whole character: the season is not run by the people holding permissions, it is run by whoever is standing in Mina at three in the morning.';

  @override
  String get roadmapPhaseWatch => 'Watching it happen';

  @override
  String get roadmapPhaseWatchWhen => 'Alongside the phase above';

  @override
  String get roadmapPhaseWatchBody =>
      'The operations room\'s half of the same days. Some of it is the season seen whole while it is still moving; the rest is read back afterwards, act by act.';

  @override
  String get roadmapPhaseClose => 'Closing the year';

  @override
  String get roadmapPhaseCloseWhen => 'The weeks after';

  @override
  String get roadmapPhaseCloseBody =>
      'What is harvested from a season once the buses have gone home: the marks people were asked to give, the records taken out of the app, and the year put away so the next one can be opened.';

  @override
  String get roadmapStepSeason =>
      'Name the year the Administration is working through and make it the current one. Every file, task, report and check-in that follows is filed against it, which is why nothing else in this map can be done first.';

  @override
  String get roadmapNoteSeason =>
      'Only one season is current at a time. Changing it changes what every other screen in the app is showing.';

  @override
  String get roadmapStepReference =>
      'The lists everything else is assembled from: hotels, clusters, the places of the rites, and the rest of the master data. A file names a hotel rather than describing one, so a hotel that is not on this list cannot be put in a file.';

  @override
  String get roadmapNoteReference =>
      'A place only becomes scannable once it is here with a position and a radius — which is what makes attendance work at all.';

  @override
  String get roadmapStepApprovals =>
      'Nobody reaches the app before their account is approved. Registrations queue here, and each is admitted, refused, or left waiting.';

  @override
  String get roadmapStepEmployees =>
      'Who is working this season: their details, their photographs and the numbers they are reached on. It is filled here once, and read from here by every other screen that has to contact somebody.';

  @override
  String get roadmapStepPermissions =>
      'What each person may do. Being approved lets somebody in; this decides what they find once inside — and the sections nobody grants them stay both hidden and shut.';

  @override
  String get roadmapNotePermissions =>
      'A permission granted now reaches the holder when their session next refreshes — a pull on any list will do it.';

  @override
  String get roadmapStepFiles =>
      'Open the season\'s operational files, put people into them and give each a role. This is the step that turns a directory of staff into an organisation: a file reaches its members by assignment, and it is here that the assigning happens.';

  @override
  String get roadmapNoteFiles =>
      'A member sees a file because he was put in it, never because of a permission — which is why every file has to be built here before anybody can work one.';

  @override
  String get roadmapStepAssign =>
      'Write duties onto other people\'s lists and follow them up. Separate from the files on purpose: a task is aimed at a person, not at a folder, and most of them have no file behind them at all.';

  @override
  String get roadmapStepForms =>
      'Write the evaluation papers the season will be judged with: the stages, the questions, and what each is worth. Written before anybody is asked to fill one, because the paper cannot change under a mark that has already been given.';

  @override
  String get roadmapNoteForms =>
      'Writing the questions and reading the answers are two different trusts, and two different permissions.';

  @override
  String get roadmapStepCirculars =>
      'Enter and publish the decisions, timetables and notices the whole mission reads — meal times, movement orders, anything that has to reach everybody at once.';

  @override
  String get roadmapStepMyFiles =>
      'The files you were put into, and your role in each. Whatever your rank, this shows your own work: being allowed to open every file does not make every file yours.';

  @override
  String get roadmapStepMyTasks =>
      'Your own list, and what was written onto it by somebody else. Mark a duty done as you go rather than at the end of the day — the follow-up screens read exactly this.';

  @override
  String get roadmapNoteOffline =>
      'Written with no network, it is kept on the device and sent by itself when the network returns. Do not write it twice.';

  @override
  String get roadmapStepCheckIn =>
      'Scan the code fixed at the place and your arrival is recorded there, with the time and the place on it. Your own record is yours to read from any device.';

  @override
  String get roadmapNoteCheckIn =>
      'The phone\'s own position is checked as well as the code, so an arrival cannot be filed from the other end of the street.';

  @override
  String get roadmapStepIncident =>
      'Say that something has gone wrong — a coach broken down, a pilgrim lost, a hotel refusing a group — and it reaches the operations room at once. There is a red button for it on nearly every screen in the app.';

  @override
  String get roadmapNoteIncident =>
      'Deliberately open to everybody: a system in which only certain people may report a broken-down coach is a system that does not find out about the coach.';

  @override
  String get roadmapStepReadCirculars =>
      'What the Administration has published to the whole mission this season. Read rather than written — entering one is the step above, in the other hands.';

  @override
  String get roadmapStepComplain =>
      'File a complaint and read what came back on it. Complaining is not an authority somebody grants, so this is open to every approved account.';

  @override
  String get roadmapStepDashboard =>
      'The season from above: how many files are running, who is where, what is still waiting. Each part of it answers for itself, so you see the sections you hold and no others.';

  @override
  String get roadmapStepMap =>
      'The season drawn on the ground — the hotels, the camps and the places of the rites, with what is happening at each.';

  @override
  String get roadmapStepPresence =>
      'Who is present, everywhere, right now. The map says where the places are and this says who is standing in them.';

  @override
  String get roadmapStepIncidents =>
      'The register of urgent reports as they arrive. The one oversight screen in this app that is read while the thing it is about is still happening.';

  @override
  String get roadmapStepComplaints =>
      'Every complaint filed across the mission: reply to it, dismiss it, or lock it once it is settled.';

  @override
  String get roadmapNoteComplaints =>
      'A complaint can escalate onto a person\'s account with no human in the loop, which is why the register sits with the people rather than with the files.';

  @override
  String get roadmapStepAudit =>
      'The season act by act: who did what, and when. The dashboard is the season from above; this is the same season from the side.';

  @override
  String get roadmapStepEvaluate =>
      'Fill in the evaluations you were asked for. They reach you by name rather than by permission, so this list is empty for anybody who was not asked — which is the true answer, not a missing door.';

  @override
  String get roadmapNoteEvaluate =>
      'What was written about you is not here. It is on your own page, and it arrives with no name on it.';

  @override
  String get roadmapStepExport =>
      'Take any list out of the app as a file, with the columns you choose — for a report, an archive, or anything that has to be worked on outside.';

  @override
  String get roadmapStepArchiveTitle => 'Close the year, open the next';

  @override
  String get roadmapStepArchive =>
      'Nothing is deleted at the end of a season. The year stops being the current one and becomes the archive, and a new season is opened beside it — which puts you back at the first step of this map.';

  @override
  String get roadmapNoteArchive =>
      'Everything filed against a past season stays readable exactly as it was. Closing a year hides nothing.';

  @override
  String get navMyJourney => 'My journey';

  @override
  String get navMyJourneySubtitle =>
      'Your arrival, your movements and when you fly home, from end to end.';

  @override
  String get navTravel => 'Travel and movement';

  @override
  String get navTravelSubtitle =>
      'The season\'s trips, and who is on each of them.';

  @override
  String get perm_travel => 'Travel and movement';

  @override
  String get permTravelView => 'Read a colleague\'s journey on their page';

  @override
  String get permTravelViewAll => 'Read every trip of the season';

  @override
  String get permTravelEdit => 'Create trips and change their details';

  @override
  String get permTravelAssign =>
      'Put people on trips and move them between them';

  @override
  String get permTravelConfirm =>
      'Record what actually happened — departures and arrivals';

  @override
  String get permTravelDelete => 'Delete a trip';

  @override
  String get travelMyJourneyTitle => 'My journey';

  @override
  String get travelJourneyTitle => 'Journey';

  @override
  String get travelSectionTitle => 'Travel and movement';

  @override
  String get travelViewFullJourney => 'See the whole journey';

  @override
  String get travelNoJourney => 'No travel recorded for this season yet';

  @override
  String get travelNoJourneyHint =>
      'The arrival flight, the movements and the return will appear here as they are recorded.';

  @override
  String get travelNotInSeason =>
      'This account is not among this season\'s participants';

  @override
  String travelCurrentlyIn(String place) {
    return 'Now in $place';
  }

  @override
  String get travelCurrentLocation => 'Current location';

  @override
  String travelDays(int count) {
    return '$count days';
  }

  @override
  String travelDaysSoFar(int count) {
    return '$count days so far';
  }

  @override
  String travelSince(String date) {
    return 'since $date';
  }

  @override
  String get travelStayPlaceTitle => 'Where he is staying';

  @override
  String get travelStayHome => 'Home';

  @override
  String get travelStayResidence => 'Stay';

  @override
  String get travelStayRites => 'The rites';

  @override
  String get travelHereNow => 'Here now';

  @override
  String get travelSeasonBreakdown => 'Where the season went';

  @override
  String get travelSeasonBreakdownHint => 'Days based in each city';

  @override
  String get travelNotDepartedYet => 'The journey has not begun';

  @override
  String get travelJourneyComplete => 'The journey is over';

  @override
  String travelDayOf(int day) {
    return 'Day $day of the journey';
  }

  @override
  String travelSinceDays(int days) {
    return 'for $days days';
  }

  @override
  String travelReturnIn(int days) {
    return 'Home in $days days';
  }

  @override
  String get travelReturnTomorrow => 'Flies home tomorrow';

  @override
  String get travelReturnToday => 'Flies home today';

  @override
  String get travelReturnPassed => 'The return date has passed';

  @override
  String get travelNoReturnYet => 'No return flight set yet';

  @override
  String get travelNoReturnYetHint =>
      'A return is usually booked only a few days beforehand.';

  @override
  String travelBetween(String from, String to) {
    return 'From $from to $to';
  }

  @override
  String get travelUntrackedTransferOptional =>
      'No means of travel recorded — optional';

  @override
  String get travelRecordTransferShort => 'Record';

  @override
  String get travelUntrackedTransfer => 'No means of travel recorded';

  @override
  String get travelRecordTransfer => 'Record how he travelled';

  @override
  String get travelSelfArranged => 'Self-arranged';

  @override
  String get travelConfirmArrival => 'Confirm arrival';

  @override
  String travelConfirmedBy(String name) {
    return 'Confirmed by $name';
  }

  @override
  String get travelNeedsYourWord =>
      'Nothing else can confirm this one — it is yours to record';

  @override
  String travelPlannedAt(String time) {
    return 'Planned $time';
  }

  @override
  String travelActualAt(String time) {
    return 'Actual $time';
  }

  @override
  String travelDepartedAt(String time) {
    return 'Left $time';
  }

  @override
  String travelArrivedAt(String time) {
    return 'Arrived $time';
  }

  @override
  String get travelRoleInbound => 'Arrival';

  @override
  String get travelRoleInternal => 'Internal movement';

  @override
  String get travelRoleOutbound => 'Return';

  @override
  String get travelModeAir => 'Flight';

  @override
  String get travelModeRail => 'Train';

  @override
  String get travelModeRoad => 'By road';

  @override
  String get travelModeOther => 'Other';

  @override
  String get travelLegPlanned => 'Planned';

  @override
  String get travelLegConfirmed => 'Confirmed';

  @override
  String get travelLegCompleted => 'Done';

  @override
  String get travelLegMissed => 'Did not travel';

  @override
  String get travelLegCancelled => 'Cancelled';

  @override
  String get travelLegRebooked => 'Moved to another';

  @override
  String get travelTripState => 'Trip status';

  @override
  String get travelTripScheduled => 'On time';

  @override
  String get travelTripDelayed => 'Delayed';

  @override
  String get travelTripDeparted => 'Departed';

  @override
  String get travelTripArrived => 'Arrived';

  @override
  String get travelTripCancelled => 'Cancelled';

  @override
  String get travelTripsTitle => 'Season trips';

  @override
  String get travelNewTrip => 'New trip';

  @override
  String get travelEditTrip => 'Edit trip';

  @override
  String get travelTripDetailTitle => 'Trip';

  @override
  String get travelNoTrips => 'No trips in this season yet';

  @override
  String get travelNoTripsHint =>
      'Create a trip, then assign people to it in one go.';

  @override
  String get travelNoTripsInRole => 'No trips in this part yet';

  @override
  String get travelNoTripsMatch => 'No trip matches the search';

  @override
  String travelAssignedCount(int count) {
    return '$count assigned';
  }

  @override
  String travelConfirmedOf(int done, int total) {
    return '$done of $total confirmed';
  }

  @override
  String get travelAssign => 'Assign people';

  @override
  String get travelPassengers => 'Passengers';

  @override
  String get travelNoPassengers => 'Nobody is on this trip yet';

  @override
  String travelAssignOutcome(int assigned, int rebooked, int skipped) {
    return '$assigned assigned, $rebooked moved, $skipped left alone';
  }

  @override
  String travelAssignNotInSeason(int count) {
    return 'and $count are not participants this season';
  }

  @override
  String get travelConfirmAll => 'Confirm everybody arrived';

  @override
  String travelConfirmAllPrompt(int count) {
    return 'Mark all $count assigned as arrived? This records what happened; it never happens on its own.';
  }

  @override
  String get travelRemoveFromTrip => 'Take off this trip';

  @override
  String travelRemoveFromTripConfirm(String name) {
    return 'Take $name off this trip? The movement is kept in the record, not deleted.';
  }

  @override
  String get travelCancelTrip => 'Cancel the trip';

  @override
  String get travelDeleteTrip => 'Delete the trip';

  @override
  String get travelDeleteTripConfirm =>
      'Delete this trip for good? A trip with passengers cannot be deleted — cancel it instead.';

  @override
  String get travelFieldMode => 'Mode';

  @override
  String get travelFieldRole => 'Kind of movement';

  @override
  String get travelFieldFrom => 'From';

  @override
  String get travelFieldTo => 'To';

  @override
  String get travelFieldNumber => 'Trip number';

  @override
  String get travelFieldDeparture => 'Departs';

  @override
  String get travelFieldArrival => 'Arrives';

  @override
  String get travelFieldNote => 'Note';

  @override
  String get travelFieldTicket => 'Ticket number';

  @override
  String get travelFieldSeat => 'Seat';

  @override
  String get travelFieldRequired => 'This field is required';

  @override
  String get travelPickDateTime => 'Pick a date and time';

  @override
  String get travelSameEndpoints =>
      'The start and the destination cannot be the same';

  @override
  String get travelMustStartWhereHeIs =>
      'A movement starts where the one before it left him';

  @override
  String get travelGapsTitle => 'What is unanswered';

  @override
  String get travelGapsClear => 'Nothing outstanding';

  @override
  String get travelGapsClearHint =>
      'No participant without a flight, and no movement past its hour without a word.';

  @override
  String get travelGapNoInbound => 'No arrival flight';

  @override
  String get travelGapNoOutbound => 'No return flight';

  @override
  String get travelGapUnconfirmed => 'Past its hour, unconfirmed';

  @override
  String get travelGapCancelledTrip => 'On a cancelled trip';

  @override
  String get travelMarkDoesNotTravel => 'Does not travel this season';

  @override
  String travelMarkDoesNotTravelConfirm(String name) {
    return 'Mark $name as not travelling this season? They come off this list, and movements may still be recorded for them.';
  }

  @override
  String get travelRecordTitle => 'Record a movement';

  @override
  String get travelRecordSubtitle =>
      'For movements arranged privately — a car, or anything else.';

  @override
  String get travelRecordAlreadyHappened => 'It has already happened';

  @override
  String get travelRecordSaved => 'Movement recorded';

  @override
  String get travelAttachments => 'Attachments';

  @override
  String get travelNoAttachments => 'No attachments';

  @override
  String get travelNoAttachmentsHint =>
      'Attach a ticket, a manifest or a photograph — PDF or image.';

  @override
  String get travelAddAttachment => 'Add an attachment';
}
