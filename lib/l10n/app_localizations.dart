import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Hajj Operations'**
  String get appTitle;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonConnectionErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server'**
  String get commonConnectionErrorTitle;

  /// No description provided for @commonConnectionErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get commonConnectionErrorBody;

  /// No description provided for @commonGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonGenericError;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get commonLogout;

  /// No description provided for @commonLoggingOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get commonLoggingOut;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @commonMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// No description provided for @moduleNotifyMembers.
  ///
  /// In en, this message translates to:
  /// **'Notify everyone in this file'**
  String get moduleNotifyMembers;

  /// No description provided for @employeeNotify.
  ///
  /// In en, this message translates to:
  /// **'Send a notification'**
  String get employeeNotify;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications on this device'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Turning this off only silences the device — messages still reach your inbox'**
  String get settingsNotificationsHint;

  /// No description provided for @settingsLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log out of this device? The account leaves the quick-switch list, and signing back in will ask for the password.'**
  String get settingsLogoutConfirm;

  /// No description provided for @settingsSolidSurfaces.
  ///
  /// In en, this message translates to:
  /// **'Solid surfaces'**
  String get settingsSolidSurfaces;

  /// No description provided for @settingsSolidSurfacesHint.
  ///
  /// In en, this message translates to:
  /// **'No transparency or blur — clearer in sunlight, lighter on slower phones'**
  String get settingsSolidSurfacesHint;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsTheme;

  /// No description provided for @settingsGroupDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get settingsGroupDevice;

  /// No description provided for @settingsSwitchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch to another account'**
  String get settingsSwitchAccount;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get authLoginSubtitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Register with your email to get started'**
  String get authRegisterSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authSignUp;

  /// No description provided for @authOrContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOrContinueWith;

  /// No description provided for @authGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authGoogle;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHaveAccount;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get authInvalidEmail;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authPasswordTooShort;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordMismatch;

  /// No description provided for @authVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code'**
  String get authVerifyTitle;

  /// No description provided for @authVerifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification code to {email}'**
  String authVerifySubtitle(String email);

  /// No description provided for @authVerifyAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get authVerifyAction;

  /// No description provided for @authVerifyResend.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get authVerifyResend;

  /// No description provided for @authVerifyResendIn.
  ///
  /// In en, this message translates to:
  /// **'Send again in {seconds}s'**
  String authVerifyResendIn(int seconds);

  /// No description provided for @authVerifyResent.
  ///
  /// In en, this message translates to:
  /// **'A new code is on its way'**
  String get authVerifyResent;

  /// No description provided for @authVerifyWrongCode.
  ///
  /// In en, this message translates to:
  /// **'That code is wrong or has expired'**
  String get authVerifyWrongCode;

  /// No description provided for @authVerifyChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change the address'**
  String get authVerifyChangeEmail;

  /// No description provided for @authVerifyJunkHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing arrived? Look in the junk folder'**
  String get authVerifyJunkHint;

  /// No description provided for @authVerifyUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'This account was never confirmed. We have sent a new code.'**
  String get authVerifyUnconfirmed;

  /// No description provided for @accountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTitle;

  /// No description provided for @accountsSaved.
  ///
  /// In en, this message translates to:
  /// **'Quick sign-in'**
  String get accountsSaved;

  /// No description provided for @accountsSavedHint.
  ///
  /// In en, this message translates to:
  /// **'Accounts saved on this device — tap one to sign in without a password'**
  String get accountsSavedHint;

  /// No description provided for @accountsCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current account'**
  String get accountsCurrent;

  /// No description provided for @accountsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add another account'**
  String get accountsAdd;

  /// No description provided for @accountsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accountsAddTitle;

  /// No description provided for @accountsAddSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with another account — the one you are using stays saved to return to'**
  String get accountsAddSubtitle;

  /// No description provided for @accountsSwitching.
  ///
  /// In en, this message translates to:
  /// **'Switching account…'**
  String get accountsSwitching;

  /// No description provided for @accountsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from this device'**
  String get accountsRemove;

  /// No description provided for @accountsRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this device\'s list? Signing back in will ask for the password.'**
  String accountsRemoveConfirm(String name);

  /// No description provided for @accountsExpired.
  ///
  /// In en, this message translates to:
  /// **'This account\'s session on this device has expired. Sign in with it again.'**
  String get accountsExpired;

  /// No description provided for @profileCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get profileCompleteTitle;

  /// No description provided for @profileCompleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fill in your details to submit for approval'**
  String get profileCompleteSubtitle;

  /// No description provided for @profileFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get profileFirstName;

  /// No description provided for @profileSurname.
  ///
  /// In en, this message translates to:
  /// **'Surname'**
  String get profileSurname;

  /// No description provided for @profileFatherName.
  ///
  /// In en, this message translates to:
  /// **'Father\'s name'**
  String get profileFatherName;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profilePhoto;

  /// No description provided for @profileJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job title'**
  String get profileJobTitle;

  /// No description provided for @profileCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileCity;

  /// No description provided for @profileGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get profileGender;

  /// No description provided for @profileDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get profileDateOfBirth;

  /// No description provided for @profileMissionType.
  ///
  /// In en, this message translates to:
  /// **'Mission type'**
  String get profileMissionType;

  /// No description provided for @profilePhoneSy.
  ///
  /// In en, this message translates to:
  /// **'Syrian phone number'**
  String get profilePhoneSy;

  /// No description provided for @profilePhoneSa.
  ///
  /// In en, this message translates to:
  /// **'Saudi phone number'**
  String get profilePhoneSa;

  /// No description provided for @profilePassportPhoto.
  ///
  /// In en, this message translates to:
  /// **'Passport photo'**
  String get profilePassportPhoto;

  /// No description provided for @profileVisaPhoto.
  ///
  /// In en, this message translates to:
  /// **'Visa photo'**
  String get profileVisaPhoto;

  /// No description provided for @profileNusukPhoto.
  ///
  /// In en, this message translates to:
  /// **'Nusuk card photo'**
  String get profileNusukPhoto;

  /// No description provided for @profileDocumentsSection.
  ///
  /// In en, this message translates to:
  /// **'Documents (optional)'**
  String get profileDocumentsSection;

  /// No description provided for @profilePickImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get profilePickImage;

  /// No description provided for @profileChangeImage.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get profileChangeImage;

  /// No description provided for @profileSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get profileSelectDate;

  /// No description provided for @profileSubmitForApproval.
  ///
  /// In en, this message translates to:
  /// **'Submit for approval'**
  String get profileSubmitForApproval;

  /// No description provided for @profileCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get profileCamera;

  /// No description provided for @profileGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get profileGallery;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @statusPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get statusPendingTitle;

  /// No description provided for @statusPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account is under review. You\'ll gain access once an administrator approves it.'**
  String get statusPendingMessage;

  /// No description provided for @statusRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account not approved'**
  String get statusRejectedTitle;

  /// No description provided for @statusRejectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account was not approved.'**
  String get statusRejectedMessage;

  /// No description provided for @statusRejectedReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String statusRejectedReason(String reason);

  /// No description provided for @statusEditAndResubmit.
  ///
  /// In en, this message translates to:
  /// **'Edit and resubmit'**
  String get statusEditAndResubmit;

  /// No description provided for @statusSuspendedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account suspended'**
  String get statusSuspendedTitle;

  /// No description provided for @statusSuspendedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been suspended. Please contact an administrator.'**
  String get statusSuspendedMessage;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @homeWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String homeWelcome(String name);

  /// No description provided for @homeHijriDate.
  ///
  /// In en, this message translates to:
  /// **'{date} AH'**
  String homeHijriDate(String date);

  /// No description provided for @homeGregorianDate.
  ///
  /// In en, this message translates to:
  /// **'{date} CE'**
  String homeGregorianDate(String date);

  /// No description provided for @profileTitleBadgeSuffix.
  ///
  /// In en, this message translates to:
  /// **'({badge})'**
  String profileTitleBadgeSuffix(String badge);

  /// No description provided for @homeAdminSection.
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get homeAdminSection;

  /// No description provided for @homeGeneralSection.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get homeGeneralSection;

  /// No description provided for @homeAdminGroupFiles.
  ///
  /// In en, this message translates to:
  /// **'Files, decisions & circulars'**
  String get homeAdminGroupFiles;

  /// No description provided for @homeAdminGroupPeople.
  ///
  /// In en, this message translates to:
  /// **'People & permissions'**
  String get homeAdminGroupPeople;

  /// No description provided for @homeAdminGroupSeason.
  ///
  /// In en, this message translates to:
  /// **'Season & reference data'**
  String get homeAdminGroupSeason;

  /// No description provided for @homeAdminGroupOversight.
  ///
  /// In en, this message translates to:
  /// **'Oversight & records'**
  String get homeAdminGroupOversight;

  /// No description provided for @navApprovals.
  ///
  /// In en, this message translates to:
  /// **'Account approvals'**
  String get navApprovals;

  /// No description provided for @navApprovalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review pending registrations'**
  String get navApprovalsSubtitle;

  /// No description provided for @approvalQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending approvals'**
  String get approvalQueueTitle;

  /// No description provided for @approvalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No accounts are waiting for approval'**
  String get approvalEmpty;

  /// No description provided for @approvalPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String approvalPendingCount(int count);

  /// No description provided for @approvalDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Review account'**
  String get approvalDetailTitle;

  /// No description provided for @approvalApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approvalApprove;

  /// No description provided for @approvalReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get approvalReject;

  /// No description provided for @approvalRejectReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Reason for rejection'**
  String get approvalRejectReasonTitle;

  /// No description provided for @approvalRejectReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — shown to the applicant'**
  String get approvalRejectReasonHint;

  /// No description provided for @approvalApproved.
  ///
  /// In en, this message translates to:
  /// **'Account approved'**
  String get approvalApproved;

  /// No description provided for @approvalRejected.
  ///
  /// In en, this message translates to:
  /// **'Account rejected'**
  String get approvalRejected;

  /// No description provided for @profileSectionPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get profileSectionPersonal;

  /// No description provided for @profileSectionContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get profileSectionContact;

  /// No description provided for @contactWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Message on WhatsApp'**
  String get contactWhatsApp;

  /// No description provided for @profileSectionDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get profileSectionDocuments;

  /// No description provided for @profileBadgeExternal.
  ///
  /// In en, this message translates to:
  /// **'External'**
  String get profileBadgeExternal;

  /// No description provided for @profileBadgeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get profileBadgeAdmin;

  /// No description provided for @profileFieldNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get profileFieldNotProvided;

  /// No description provided for @profileNoPhone.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get profileNoPhone;

  /// No description provided for @navPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get navPermissions;

  /// No description provided for @navPermissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Grant permissions to employees'**
  String get navPermissionsSubtitle;

  /// No description provided for @permissionsEmployeesTitle.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get permissionsEmployeesTitle;

  /// No description provided for @permissionEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissionEditorTitle;

  /// No description provided for @permissionAssignIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose the permissions you need, then assign them to several employees at once. One person\'s permissions are edited from their page in the directory.'**
  String get permissionAssignIntro;

  /// No description provided for @permissionAssignSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No permissions selected yet} =1{1 permission selected} other{{count} permissions selected}}'**
  String permissionAssignSelectedCount(int count);

  /// No description provided for @permissionAssignAction.
  ///
  /// In en, this message translates to:
  /// **'Assign to employees'**
  String get permissionAssignAction;

  /// No description provided for @permissionAssignPickEmployees.
  ///
  /// In en, this message translates to:
  /// **'Choose employees'**
  String get permissionAssignPickEmployees;

  /// No description provided for @permissionAssignDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Permissions assigned to 1 employee} other{Permissions assigned to {count} employees}}'**
  String permissionAssignDone(int count);

  /// No description provided for @permissionAssignNothingNew.
  ///
  /// In en, this message translates to:
  /// **'Nothing to add — they already hold these permissions'**
  String get permissionAssignNothingNew;

  /// No description provided for @employeesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No employees yet'**
  String get employeesEmpty;

  /// No description provided for @permissionSaved.
  ///
  /// In en, this message translates to:
  /// **'Permissions updated'**
  String get permissionSaved;

  /// No description provided for @permissionGrantedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} granted'**
  String permissionGrantedCount(int count, int total);

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get commonClearAll;

  /// No description provided for @pickerSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String pickerSelectedCount(int count);

  /// No description provided for @commonSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get commonSelectAll;

  /// No description provided for @permAllGranted.
  ///
  /// In en, this message translates to:
  /// **'Full access (administrator)'**
  String get permAllGranted;

  /// No description provided for @perm_employees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get perm_employees;

  /// No description provided for @perm_approvals.
  ///
  /// In en, this message translates to:
  /// **'Account approvals'**
  String get perm_approvals;

  /// No description provided for @perm_seasons.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get perm_seasons;

  /// No description provided for @perm_permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get perm_permissions;

  /// No description provided for @permEmployeesView.
  ///
  /// In en, this message translates to:
  /// **'View employees & details'**
  String get permEmployeesView;

  /// No description provided for @permEmployeesCreate.
  ///
  /// In en, this message translates to:
  /// **'Add employees'**
  String get permEmployeesCreate;

  /// No description provided for @permEmployeesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit employee records'**
  String get permEmployeesEdit;

  /// No description provided for @permEmployeesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete employee records'**
  String get permEmployeesDelete;

  /// No description provided for @permEmployeesPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset an employee\'s password'**
  String get permEmployeesPassword;

  /// No description provided for @permEmployeesEmail.
  ///
  /// In en, this message translates to:
  /// **'Change an employee\'s email address'**
  String get permEmployeesEmail;

  /// No description provided for @permEmployeesSuspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend & reactivate accounts'**
  String get permEmployeesSuspend;

  /// No description provided for @permEmployeesExternal.
  ///
  /// In en, this message translates to:
  /// **'Manage external status'**
  String get permEmployeesExternal;

  /// No description provided for @permEmployeesDocuments.
  ///
  /// In en, this message translates to:
  /// **'View employee documents'**
  String get permEmployeesDocuments;

  /// No description provided for @permApprovalsView.
  ///
  /// In en, this message translates to:
  /// **'View registration requests'**
  String get permApprovalsView;

  /// No description provided for @permApprovalsDecide.
  ///
  /// In en, this message translates to:
  /// **'Approve & reject requests'**
  String get permApprovalsDecide;

  /// No description provided for @permSeasonsView.
  ///
  /// In en, this message translates to:
  /// **'View seasons'**
  String get permSeasonsView;

  /// No description provided for @permSeasonsSwitch.
  ///
  /// In en, this message translates to:
  /// **'Set the current season'**
  String get permSeasonsSwitch;

  /// No description provided for @permSeasonsParticipantsView.
  ///
  /// In en, this message translates to:
  /// **'View season participants'**
  String get permSeasonsParticipantsView;

  /// No description provided for @permSeasonsParticipantsManage.
  ///
  /// In en, this message translates to:
  /// **'Add & withdraw participants'**
  String get permSeasonsParticipantsManage;

  /// No description provided for @permPermissionsView.
  ///
  /// In en, this message translates to:
  /// **'View granted permissions'**
  String get permPermissionsView;

  /// No description provided for @permPermissionsManage.
  ///
  /// In en, this message translates to:
  /// **'Grant & revoke permissions'**
  String get permPermissionsManage;

  /// No description provided for @perm_reference.
  ///
  /// In en, this message translates to:
  /// **'Master data'**
  String get perm_reference;

  /// No description provided for @permReferenceView.
  ///
  /// In en, this message translates to:
  /// **'View master data'**
  String get permReferenceView;

  /// No description provided for @permReferenceEdit.
  ///
  /// In en, this message translates to:
  /// **'Add & edit master data'**
  String get permReferenceEdit;

  /// No description provided for @permReferenceDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete master data'**
  String get permReferenceDelete;

  /// No description provided for @permReferenceImport.
  ///
  /// In en, this message translates to:
  /// **'Copy data from another season'**
  String get permReferenceImport;

  /// No description provided for @perm_reports.
  ///
  /// In en, this message translates to:
  /// **'Decisions and circulars'**
  String get perm_reports;

  /// No description provided for @permReportsViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all decisions, including drafts'**
  String get permReportsViewAll;

  /// No description provided for @permReportsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create decisions'**
  String get permReportsCreate;

  /// No description provided for @permReportsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit decisions'**
  String get permReportsEdit;

  /// No description provided for @permReportsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete decisions'**
  String get permReportsDelete;

  /// No description provided for @permReportsPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish & unpublish decisions'**
  String get permReportsPublish;

  /// No description provided for @perm_notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get perm_notifications;

  /// No description provided for @permNotificationsSend.
  ///
  /// In en, this message translates to:
  /// **'Notify an individual employee'**
  String get permNotificationsSend;

  /// No description provided for @permNotificationsBroadcastModule.
  ///
  /// In en, this message translates to:
  /// **'Notify a file\'s members'**
  String get permNotificationsBroadcastModule;

  /// No description provided for @permNotificationsBroadcastAll.
  ///
  /// In en, this message translates to:
  /// **'Notify everyone'**
  String get permNotificationsBroadcastAll;

  /// No description provided for @perm_audit.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get perm_audit;

  /// No description provided for @permAuditView.
  ///
  /// In en, this message translates to:
  /// **'Read the record of who did what'**
  String get permAuditView;

  /// No description provided for @perm_complaints.
  ///
  /// In en, this message translates to:
  /// **'Complaints'**
  String get perm_complaints;

  /// No description provided for @permComplaintsView.
  ///
  /// In en, this message translates to:
  /// **'View every complaint filed'**
  String get permComplaintsView;

  /// No description provided for @permComplaintsReply.
  ///
  /// In en, this message translates to:
  /// **'Take part in any complaint thread'**
  String get permComplaintsReply;

  /// No description provided for @permComplaintsLock.
  ///
  /// In en, this message translates to:
  /// **'Close a complaint to further replies'**
  String get permComplaintsLock;

  /// No description provided for @permComplaintsDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss a complaint as unfounded'**
  String get permComplaintsDismiss;

  /// No description provided for @permComplaintsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete a complaint'**
  String get permComplaintsDelete;

  /// No description provided for @perm_evaluations.
  ///
  /// In en, this message translates to:
  /// **'Evaluations'**
  String get perm_evaluations;

  /// No description provided for @permEvaluationsView.
  ///
  /// In en, this message translates to:
  /// **'View every evaluation and its marks'**
  String get permEvaluationsView;

  /// No description provided for @permEvaluationsTemplates.
  ///
  /// In en, this message translates to:
  /// **'Build and edit the evaluation forms'**
  String get permEvaluationsTemplates;

  /// No description provided for @permEvaluationsAssign.
  ///
  /// In en, this message translates to:
  /// **'Open an evaluation and name its evaluator'**
  String get permEvaluationsAssign;

  /// No description provided for @permEvaluationsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete an evaluation'**
  String get permEvaluationsDelete;

  /// No description provided for @perm_incidents.
  ///
  /// In en, this message translates to:
  /// **'Urgent reports'**
  String get perm_incidents;

  /// No description provided for @permIncidentsReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive and read every urgent report'**
  String get permIncidentsReceive;

  /// No description provided for @permIncidentsHandle.
  ///
  /// In en, this message translates to:
  /// **'Take on an urgent report and close it'**
  String get permIncidentsHandle;

  /// No description provided for @permIncidentsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete urgent reports from the register'**
  String get permIncidentsDelete;

  /// No description provided for @perm_checkin.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get perm_checkin;

  /// No description provided for @permCheckinBoard.
  ///
  /// In en, this message translates to:
  /// **'Read everyone\'s attendance record'**
  String get permCheckinBoard;

  /// No description provided for @permCheckinCodes.
  ///
  /// In en, this message translates to:
  /// **'View, print and share place codes'**
  String get permCheckinCodes;

  /// No description provided for @permCheckinRotate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate a place code, voiding every printed copy'**
  String get permCheckinRotate;

  /// No description provided for @perm_export.
  ///
  /// In en, this message translates to:
  /// **'Data export'**
  String get perm_export;

  /// No description provided for @permExportData.
  ///
  /// In en, this message translates to:
  /// **'Export any dataset, including data you cannot open on screen'**
  String get permExportData;

  /// No description provided for @perm_map.
  ///
  /// In en, this message translates to:
  /// **'Season map'**
  String get perm_map;

  /// No description provided for @permMapView.
  ///
  /// In en, this message translates to:
  /// **'Open the season map'**
  String get permMapView;

  /// No description provided for @perm_tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get perm_tasks;

  /// No description provided for @permTasksAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign tasks to other people'**
  String get permTasksAssign;

  /// No description provided for @permTasksViewAll.
  ///
  /// In en, this message translates to:
  /// **'See every assigned task in the mission'**
  String get permTasksViewAll;

  /// No description provided for @permissionRequires.
  ///
  /// In en, this message translates to:
  /// **'Requires: {names}'**
  String permissionRequires(String names);

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You don\'t hold the permission this action needs'**
  String get permissionDenied;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @notificationTargetGone.
  ///
  /// In en, this message translates to:
  /// **'That file is no longer available'**
  String get notificationTargetGone;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmpty;

  /// No description provided for @notificationSend.
  ///
  /// In en, this message translates to:
  /// **'Send notification'**
  String get notificationSend;

  /// No description provided for @notificationFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationFilterAll;

  /// No description provided for @notificationFilterMessages.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get notificationFilterMessages;

  /// No description provided for @notificationFilterIncidents.
  ///
  /// In en, this message translates to:
  /// **'Urgent reports'**
  String get notificationFilterIncidents;

  /// No description provided for @notificationFilterCount.
  ///
  /// In en, this message translates to:
  /// **'{label} ({count})'**
  String notificationFilterCount(String label, int count);

  /// No description provided for @notificationOpenIncident.
  ///
  /// In en, this message translates to:
  /// **'Open the report'**
  String get notificationOpenIncident;

  /// No description provided for @notificationOpenModule.
  ///
  /// In en, this message translates to:
  /// **'Open the file'**
  String get notificationOpenModule;

  /// No description provided for @notificationsEmptyIncidents.
  ///
  /// In en, this message translates to:
  /// **'No urgent reports in the inbox'**
  String get notificationsEmptyIncidents;

  /// No description provided for @notificationsEmptyMessages.
  ///
  /// In en, this message translates to:
  /// **'No notices'**
  String get notificationsEmptyMessages;

  /// No description provided for @notificationTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get notificationTitleField;

  /// No description provided for @notificationBodyField.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get notificationBodyField;

  /// No description provided for @notificationSent.
  ///
  /// In en, this message translates to:
  /// **'Notification sent'**
  String get notificationSent;

  /// No description provided for @notificationMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationMarkAllRead;

  /// No description provided for @notificationAudience.
  ///
  /// In en, this message translates to:
  /// **'Send to'**
  String get notificationAudience;

  /// No description provided for @notificationAudienceAll.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get notificationAudienceAll;

  /// No description provided for @notificationAudienceModule.
  ///
  /// In en, this message translates to:
  /// **'Members of a file'**
  String get notificationAudienceModule;

  /// No description provided for @notificationChooseModule.
  ///
  /// In en, this message translates to:
  /// **'Choose the file'**
  String get notificationChooseModule;

  /// No description provided for @notificationBroadcastHint.
  ///
  /// In en, this message translates to:
  /// **'Reaches everyone holding a role in the file'**
  String get notificationBroadcastHint;

  /// No description provided for @notificationAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get notificationAttach;

  /// No description provided for @notificationAttachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get notificationAttachPhoto;

  /// No description provided for @notificationAttachCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get notificationAttachCamera;

  /// No description provided for @notificationAttachVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get notificationAttachVideo;

  /// No description provided for @notificationAttachAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get notificationAttachAudio;

  /// No description provided for @notificationAttachFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get notificationAttachFile;

  /// No description provided for @notificationAttachmentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attachment} other{{count} attachments}}'**
  String notificationAttachmentsCount(int count);

  /// No description provided for @attachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is larger than the {limit} limit. Choose a smaller one.'**
  String attachmentTooLarge(String limit);

  /// No description provided for @attachmentImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get attachmentImage;

  /// No description provided for @attachmentVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get attachmentVideo;

  /// No description provided for @attachmentAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get attachmentAudio;

  /// No description provided for @attachmentFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get attachmentFile;

  /// No description provided for @attachmentDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get attachmentDownload;

  /// No description provided for @attachmentOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the attachment'**
  String get attachmentOpenFailed;

  /// No description provided for @modulesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search files'**
  String get modulesSearchHint;

  /// No description provided for @modulesNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No file matches'**
  String get modulesNoMatches;

  /// No description provided for @reportScanCode.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get reportScanCode;

  /// No description provided for @reportCellEntryGone.
  ///
  /// In en, this message translates to:
  /// **'This choice no longer exists'**
  String get reportCellEntryGone;

  /// No description provided for @reportTimeFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get reportTimeFrom;

  /// No description provided for @reportTimeTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get reportTimeTo;

  /// No description provided for @reportTimeRange.
  ///
  /// In en, this message translates to:
  /// **'From {from} to {to}'**
  String reportTimeRange(String from, String to);

  /// No description provided for @reportAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add an item'**
  String get reportAddTag;

  /// No description provided for @reportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get reportSubtitle;

  /// No description provided for @reportShape.
  ///
  /// In en, this message translates to:
  /// **'Document shape'**
  String get reportShape;

  /// No description provided for @reportKindDecision.
  ///
  /// In en, this message translates to:
  /// **'Decision'**
  String get reportKindDecision;

  /// No description provided for @reportKindCircular.
  ///
  /// In en, this message translates to:
  /// **'Circular'**
  String get reportKindCircular;

  /// No description provided for @reportNumber.
  ///
  /// In en, this message translates to:
  /// **'Decision number'**
  String get reportNumber;

  /// No description provided for @reportNumberBadge.
  ///
  /// In en, this message translates to:
  /// **'No. {number}'**
  String reportNumberBadge(String number);

  /// No description provided for @reportContentSection.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get reportContentSection;

  /// No description provided for @reportContentHint.
  ///
  /// In en, this message translates to:
  /// **'Build the decision from the pieces below — a heading, prose, a list, a table, a link, a code to scan. They appear in the order you add them.'**
  String get reportContentHint;

  /// No description provided for @reportNoBlocks.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet'**
  String get reportNoBlocks;

  /// No description provided for @blockHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get blockHeading;

  /// No description provided for @blockSubheading.
  ///
  /// In en, this message translates to:
  /// **'Subheading'**
  String get blockSubheading;

  /// No description provided for @blockParagraph.
  ///
  /// In en, this message translates to:
  /// **'Paragraph'**
  String get blockParagraph;

  /// No description provided for @blockBullets.
  ///
  /// In en, this message translates to:
  /// **'Bulleted list'**
  String get blockBullets;

  /// No description provided for @blockNumbers.
  ///
  /// In en, this message translates to:
  /// **'Numbered list'**
  String get blockNumbers;

  /// No description provided for @blockTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get blockTable;

  /// No description provided for @blockUrl.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get blockUrl;

  /// No description provided for @blockQr.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get blockQr;

  /// No description provided for @blockNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get blockNote;

  /// No description provided for @blockDivider.
  ///
  /// In en, this message translates to:
  /// **'Divider'**
  String get blockDivider;

  /// No description provided for @blockMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get blockMoveUp;

  /// No description provided for @blockMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get blockMoveDown;

  /// No description provided for @blockTextShort.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get blockTextShort;

  /// No description provided for @blockTextLong.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get blockTextLong;

  /// No description provided for @blockItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get blockItems;

  /// No description provided for @blockItemsHint.
  ///
  /// In en, this message translates to:
  /// **'One per line'**
  String get blockItemsHint;

  /// No description provided for @blockLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get blockLabel;

  /// No description provided for @blockQrValue.
  ///
  /// In en, this message translates to:
  /// **'What the code carries'**
  String get blockQrValue;

  /// No description provided for @blockQrHint.
  ///
  /// In en, this message translates to:
  /// **'Usually a link'**
  String get blockQrHint;

  /// No description provided for @blockColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get blockColumnLabel;

  /// No description provided for @blockColumnKind.
  ///
  /// In en, this message translates to:
  /// **'Column type'**
  String get blockColumnKind;

  /// No description provided for @blockColumnKindText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get blockColumnKindText;

  /// No description provided for @blockColumnKindNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get blockColumnKindNumber;

  /// No description provided for @blockColumnKindDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get blockColumnKindDate;

  /// No description provided for @blockColumnKindTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get blockColumnKindTime;

  /// No description provided for @blockColumnKindTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Time range'**
  String get blockColumnKindTimeRange;

  /// No description provided for @blockColumnKindReference.
  ///
  /// In en, this message translates to:
  /// **'From master data'**
  String get blockColumnKindReference;

  /// No description provided for @blockColumnKindTags.
  ///
  /// In en, this message translates to:
  /// **'List of items'**
  String get blockColumnKindTags;

  /// No description provided for @blockColumnSet.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get blockColumnSet;

  /// No description provided for @blockColumnSpan.
  ///
  /// In en, this message translates to:
  /// **'Merge repeats'**
  String get blockColumnSpan;

  /// No description provided for @blockColumnRetypeWarning.
  ///
  /// In en, this message translates to:
  /// **'{count} cells cannot be converted and will be emptied'**
  String blockColumnRetypeWarning(int count);

  /// No description provided for @blockAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add an item'**
  String get blockAddItem;

  /// No description provided for @blockAddColumn.
  ///
  /// In en, this message translates to:
  /// **'Add a column'**
  String get blockAddColumn;

  /// No description provided for @blockTableNeedsColumns.
  ///
  /// In en, this message translates to:
  /// **'Name the columns first, then add rows'**
  String get blockTableNeedsColumns;

  /// No description provided for @reportNew.
  ///
  /// In en, this message translates to:
  /// **'New decision'**
  String get reportNew;

  /// No description provided for @reportEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit decision'**
  String get reportEdit;

  /// No description provided for @reportSaved.
  ///
  /// In en, this message translates to:
  /// **'Decision saved'**
  String get reportSaved;

  /// No description provided for @reportIdentity.
  ///
  /// In en, this message translates to:
  /// **'What this decision is'**
  String get reportIdentity;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get reportTitle;

  /// No description provided for @reportScopeHint.
  ///
  /// In en, this message translates to:
  /// **'General decisions stay true whichever season is running'**
  String get reportScopeHint;

  /// No description provided for @reportOncePerSeason.
  ///
  /// In en, this message translates to:
  /// **'This kind of decision is created only once per season, and it already exists — edit the existing one instead of creating another'**
  String get reportOncePerSeason;

  /// No description provided for @reportPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get reportPublished;

  /// No description provided for @reportPublishedHint.
  ///
  /// In en, this message translates to:
  /// **'An unpublished decision is visible only to whoever manages decisions'**
  String get reportPublishedHint;

  /// No description provided for @reportAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add a row'**
  String get reportAddRow;

  /// No description provided for @reportNoRows.
  ///
  /// In en, this message translates to:
  /// **'No rows yet'**
  String get reportNoRows;

  /// No description provided for @reportsManageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No decisions yet'**
  String get reportsManageEmpty;

  /// No description provided for @reportDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {title}? This cannot be undone.'**
  String reportDeleteConfirm(String title);

  /// No description provided for @reportDeleted.
  ///
  /// In en, this message translates to:
  /// **'Decision deleted'**
  String get reportDeleted;

  /// No description provided for @reportRowsSection.
  ///
  /// In en, this message translates to:
  /// **'Rows ({count})'**
  String reportRowsSection(int count);

  /// No description provided for @reportRowNumber.
  ///
  /// In en, this message translates to:
  /// **'Row {number}'**
  String reportRowNumber(int number);

  /// No description provided for @navReportsManage.
  ///
  /// In en, this message translates to:
  /// **'Decisions & circulars management'**
  String get navReportsManage;

  /// No description provided for @navReportsManageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter, correct and publish decisions'**
  String get navReportsManageSubtitle;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Decisions and circulars'**
  String get navReports;

  /// No description provided for @navReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Timetables and notices published to the mission'**
  String get navReportsSubtitle;

  /// No description provided for @reportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been published yet'**
  String get reportsEmpty;

  /// No description provided for @reportsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No decision matches'**
  String get reportsNoMatches;

  /// No description provided for @reportsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search decisions'**
  String get reportsSearchHint;

  /// No description provided for @reportsScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get reportsScopeAll;

  /// No description provided for @reportsScopeSeasonal.
  ///
  /// In en, this message translates to:
  /// **'This season'**
  String get reportsScopeSeasonal;

  /// No description provided for @reportsScopeGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get reportsScopeGeneral;

  /// No description provided for @reportsDraft.
  ///
  /// In en, this message translates to:
  /// **'Unpublished'**
  String get reportsDraft;

  /// No description provided for @reportMissing.
  ///
  /// In en, this message translates to:
  /// **'That decision is no longer available'**
  String get reportMissing;

  /// No description provided for @reportAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About this decision'**
  String get reportAboutSection;

  /// No description provided for @reportKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get reportKind;

  /// No description provided for @reportScope.
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get reportScope;

  /// No description provided for @reportAbout.
  ///
  /// In en, this message translates to:
  /// **'What it covers'**
  String get reportAbout;

  /// No description provided for @reportSource.
  ///
  /// In en, this message translates to:
  /// **'The original document'**
  String get reportSource;

  /// No description provided for @reportQrFailed.
  ///
  /// In en, this message translates to:
  /// **'This code could not be drawn'**
  String get reportQrFailed;

  /// No description provided for @reportUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated {date}'**
  String reportUpdated(String date);

  /// No description provided for @navSeasons.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get navSeasons;

  /// No description provided for @navSeasonsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Current season and archive'**
  String get navSeasonsSubtitle;

  /// No description provided for @seasonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get seasonsTitle;

  /// No description provided for @seasonCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current season'**
  String get seasonCurrentLabel;

  /// No description provided for @seasonUpcomingLabel.
  ///
  /// In en, this message translates to:
  /// **'Upcoming seasons'**
  String get seasonUpcomingLabel;

  /// No description provided for @seasonArchiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous seasons'**
  String get seasonArchiveLabel;

  /// No description provided for @seasonHijriYear.
  ///
  /// In en, this message translates to:
  /// **'{year} AH'**
  String seasonHijriYear(int year);

  /// No description provided for @seasonBadgeCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get seasonBadgeCurrent;

  /// No description provided for @seasonParticipantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get seasonParticipantsTitle;

  /// No description provided for @seasonParticipantsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} participants'**
  String seasonParticipantsCount(int count);

  /// No description provided for @seasonManageParticipants.
  ///
  /// In en, this message translates to:
  /// **'Manage participants'**
  String get seasonManageParticipants;

  /// No description provided for @seasonNoParticipants.
  ///
  /// In en, this message translates to:
  /// **'No participants in this season yet'**
  String get seasonNoParticipants;

  /// No description provided for @seasonSetCurrent.
  ///
  /// In en, this message translates to:
  /// **'Set as current season'**
  String get seasonSetCurrent;

  /// No description provided for @seasonSetCurrentDone.
  ///
  /// In en, this message translates to:
  /// **'Current season updated'**
  String get seasonSetCurrentDone;

  /// No description provided for @seasonArchiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No previous seasons'**
  String get seasonArchiveEmpty;

  /// No description provided for @seasonSelectParticipants.
  ///
  /// In en, this message translates to:
  /// **'Select participants'**
  String get seasonSelectParticipants;

  /// No description provided for @seasonParticipantsSaved.
  ///
  /// In en, this message translates to:
  /// **'Participants updated'**
  String get seasonParticipantsSaved;

  /// No description provided for @navEmployees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get navEmployees;

  /// No description provided for @navEmployeesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Staff directory and externals'**
  String get navEmployeesSubtitle;

  /// No description provided for @employeesPermanentSection.
  ///
  /// In en, this message translates to:
  /// **'Permanent staff'**
  String get employeesPermanentSection;

  /// No description provided for @employeesExternalSection.
  ///
  /// In en, this message translates to:
  /// **'External participants'**
  String get employeesExternalSection;

  /// No description provided for @employeesFilterSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended only'**
  String get employeesFilterSuspended;

  /// No description provided for @employeesExternalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No external employees'**
  String get employeesExternalEmpty;

  /// No description provided for @employeeDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get employeeDetailTitle;

  /// No description provided for @modulePickerOnlyFree.
  ///
  /// In en, this message translates to:
  /// **'Unassigned only'**
  String get modulePickerOnlyFree;

  /// No description provided for @moduleRosterSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or role'**
  String get moduleRosterSearchHint;

  /// No description provided for @moduleRosterAllRoles.
  ///
  /// In en, this message translates to:
  /// **'All roles'**
  String get moduleRosterAllRoles;

  /// No description provided for @moduleRosterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get moduleRosterClear;

  /// No description provided for @moduleRosterShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing {showing} of {total}'**
  String moduleRosterShowing(int showing, int total);

  /// No description provided for @moduleRosterNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Nobody in this file matches'**
  String get moduleRosterNoMatch;

  /// No description provided for @referenceChildCount.
  ///
  /// In en, this message translates to:
  /// **'{list} assigned'**
  String referenceChildCount(String list);

  /// No description provided for @referenceOfCapacity.
  ///
  /// In en, this message translates to:
  /// **'{total} of {capacity}'**
  String referenceOfCapacity(int total, int capacity);

  /// No description provided for @referenceOverCapacity.
  ///
  /// In en, this message translates to:
  /// **'Over capacity by {excess}'**
  String referenceOverCapacity(int excess);

  /// No description provided for @placeOccupants.
  ///
  /// In en, this message translates to:
  /// **'Occupants'**
  String get placeOccupants;

  /// No description provided for @placeOccupantsBreakdown.
  ///
  /// In en, this message translates to:
  /// **'{pilgrims} pilgrims, {staff} staff'**
  String placeOccupantsBreakdown(int pilgrims, int staff);

  /// No description provided for @placeOccupantsStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff housed'**
  String get placeOccupantsStaff;

  /// No description provided for @placeOccupantsPilgrims.
  ///
  /// In en, this message translates to:
  /// **'Pilgrims'**
  String get placeOccupantsPilgrims;

  /// No description provided for @employeePermissionsSection.
  ///
  /// In en, this message translates to:
  /// **'Granted permissions'**
  String get employeePermissionsSection;

  /// No description provided for @employeePermissionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No permissions granted'**
  String get employeePermissionsEmpty;

  /// No description provided for @employeePermissionsAdmin.
  ///
  /// In en, this message translates to:
  /// **'An administrator — holds every permission, without needing to be granted them.'**
  String get employeePermissionsAdmin;

  /// No description provided for @employeePermissionsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit permissions'**
  String get employeePermissionsEdit;

  /// No description provided for @employeeEditDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit employee details'**
  String get employeeEditDetailsTitle;

  /// No description provided for @employeeEditSaved.
  ///
  /// In en, this message translates to:
  /// **'Employee details updated'**
  String get employeeEditSaved;

  /// No description provided for @employeeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get employeeEdit;

  /// No description provided for @employeeDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete employee'**
  String get employeeDelete;

  /// No description provided for @employeeDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this employee?'**
  String get employeeDeleteConfirmTitle;

  /// No description provided for @employeeDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed permanently, along with their account and every assignment they hold. This cannot be undone.'**
  String employeeDeleteConfirmBody(String name);

  /// No description provided for @employeeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Employee deleted'**
  String get employeeDeleted;

  /// No description provided for @employeeDeleteAdminBlocked.
  ///
  /// In en, this message translates to:
  /// **'An administrator cannot be deleted. Remove their admin role first.'**
  String get employeeDeleteAdminBlocked;

  /// No description provided for @employeePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get employeePassword;

  /// No description provided for @employeePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'New password for {name}'**
  String employeePasswordTitle(String name);

  /// No description provided for @employeePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'The employee signs in with the new password from now on. Tell them yourself — no message is sent.'**
  String get employeePasswordHint;

  /// No description provided for @employeePasswordNew.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get employeePasswordNew;

  /// No description provided for @employeePasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get employeePasswordConfirm;

  /// No description provided for @employeePasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get employeePasswordChanged;

  /// No description provided for @employeePasswordAdminBlocked.
  ///
  /// In en, this message translates to:
  /// **'Only an administrator can change another administrator\'s password.'**
  String get employeePasswordAdminBlocked;

  /// No description provided for @employeeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get employeeEmail;

  /// No description provided for @employeeEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'New email for {name}'**
  String employeeEmailTitle(String name);

  /// No description provided for @employeeEmailHint.
  ///
  /// In en, this message translates to:
  /// **'The employee signs in with the new email from now on. Tell them yourself — no message is sent to either address.'**
  String get employeeEmailHint;

  /// No description provided for @employeeEmailNew.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get employeeEmailNew;

  /// No description provided for @employeeEmailChanged.
  ///
  /// In en, this message translates to:
  /// **'Email changed'**
  String get employeeEmailChanged;

  /// No description provided for @employeeEmailAdminBlocked.
  ///
  /// In en, this message translates to:
  /// **'Only an administrator can change another administrator\'s email.'**
  String get employeeEmailAdminBlocked;

  /// No description provided for @employeeEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'This email is already used by another account.'**
  String get employeeEmailTaken;

  /// No description provided for @myProfileChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get myProfileChangeEmail;

  /// No description provided for @myProfileNewEmail.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get myProfileNewEmail;

  /// No description provided for @myProfileEmailChanged.
  ///
  /// In en, this message translates to:
  /// **'Email changed. You sign in with the new address from now on.'**
  String get myProfileEmailChanged;

  /// No description provided for @employeeEditExternalTitle.
  ///
  /// In en, this message translates to:
  /// **'External status'**
  String get employeeEditExternalTitle;

  /// No description provided for @employeeIsExternal.
  ///
  /// In en, this message translates to:
  /// **'External employee'**
  String get employeeIsExternal;

  /// No description provided for @employeeIsExternalHint.
  ///
  /// In en, this message translates to:
  /// **'From another government body — not permanent staff'**
  String get employeeIsExternalHint;

  /// No description provided for @employeeOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization / ministry'**
  String get employeeOrganization;

  /// No description provided for @employeeExternalSaved.
  ///
  /// In en, this message translates to:
  /// **'Employee updated'**
  String get employeeExternalSaved;

  /// No description provided for @employeeSectionOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get employeeSectionOrganization;

  /// No description provided for @employeeSeasonsSection.
  ///
  /// In en, this message translates to:
  /// **'Seasons taken part in'**
  String get employeeSeasonsSection;

  /// No description provided for @employeeSeasonsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Has not taken part in any season yet'**
  String get employeeSeasonsEmpty;

  /// No description provided for @employeeSeasonBadgeCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get employeeSeasonBadgeCurrent;

  /// No description provided for @employeeModulesSection.
  ///
  /// In en, this message translates to:
  /// **'Assigned modules'**
  String get employeeModulesSection;

  /// No description provided for @employeeModulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not assigned to any operational module'**
  String get employeeModulesEmpty;

  /// No description provided for @navMyProfile.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get navMyProfile;

  /// No description provided for @navMyProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View and edit your details'**
  String get navMyProfileSubtitle;

  /// No description provided for @myProfileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get myProfileEdit;

  /// No description provided for @myProfileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get myProfileChangePassword;

  /// No description provided for @myProfileNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get myProfileNewPassword;

  /// No description provided for @myProfileConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get myProfileConfirmPassword;

  /// No description provided for @myProfilePasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get myProfilePasswordChanged;

  /// No description provided for @myProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get myProfileSaved;

  /// No description provided for @myProfileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get myProfileEditTitle;

  /// No description provided for @createEmployeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Create employee'**
  String get createEmployeeTitle;

  /// No description provided for @createEmployeeCreated.
  ///
  /// In en, this message translates to:
  /// **'Employee created'**
  String get createEmployeeCreated;

  /// No description provided for @createEmployeeAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get createEmployeeAccountSection;

  /// No description provided for @createEmployeeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createEmployeeSubmit;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @perm_modules.
  ///
  /// In en, this message translates to:
  /// **'Operational files'**
  String get perm_modules;

  /// No description provided for @permModulesViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all files, including drafts'**
  String get permModulesViewAll;

  /// No description provided for @permModulesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create an operational file'**
  String get permModulesCreate;

  /// No description provided for @permModulesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit a file & its structure'**
  String get permModulesEdit;

  /// No description provided for @permModulesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete an operational file'**
  String get permModulesDelete;

  /// No description provided for @permModulesActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate & deactivate files'**
  String get permModulesActivate;

  /// No description provided for @permModulesMembers.
  ///
  /// In en, this message translates to:
  /// **'Assign members & duties'**
  String get permModulesMembers;

  /// No description provided for @permModulesTasks.
  ///
  /// In en, this message translates to:
  /// **'Write file duties and set any state'**
  String get permModulesTasks;

  /// No description provided for @permModulesReports.
  ///
  /// In en, this message translates to:
  /// **'Read members\' file reports'**
  String get permModulesReports;

  /// No description provided for @navModules.
  ///
  /// In en, this message translates to:
  /// **'Operational modules'**
  String get navModules;

  /// No description provided for @navModulesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The files you were assigned to, and your roles in them'**
  String get navModulesSubtitle;

  /// No description provided for @navReferenceData.
  ///
  /// In en, this message translates to:
  /// **'Master data'**
  String get navReferenceData;

  /// No description provided for @navReferenceDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hotels, clusters and other lists'**
  String get navReferenceDataSubtitle;

  /// No description provided for @modulesManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage operational files'**
  String get modulesManageTitle;

  /// No description provided for @modulesEmptyMine.
  ///
  /// In en, this message translates to:
  /// **'No files were assigned to you this season'**
  String get modulesEmptyMine;

  /// No description provided for @navModulesManage.
  ///
  /// In en, this message translates to:
  /// **'Manage operational files'**
  String get navModulesManage;

  /// No description provided for @navModulesManageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every file of the season, and opening a new one'**
  String get navModulesManageSubtitle;

  /// No description provided for @modulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Operational files'**
  String get modulesTitle;

  /// No description provided for @modulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No files have been assigned to you yet'**
  String get modulesEmpty;

  /// No description provided for @modulesEmptyManager.
  ///
  /// In en, this message translates to:
  /// **'No files created yet'**
  String get modulesEmptyManager;

  /// No description provided for @moduleActiveSection.
  ///
  /// In en, this message translates to:
  /// **'Active files'**
  String get moduleActiveSection;

  /// No description provided for @moduleDraftSection.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get moduleDraftSection;

  /// No description provided for @moduleBadgeDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get moduleBadgeDraft;

  /// No description provided for @moduleNew.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get moduleNew;

  /// No description provided for @moduleChooseType.
  ///
  /// In en, this message translates to:
  /// **'Choose a file type'**
  String get moduleChooseType;

  /// No description provided for @moduleNoTypes.
  ///
  /// In en, this message translates to:
  /// **'No file types have been defined yet'**
  String get moduleNoTypes;

  /// No description provided for @moduleAllTypesUsed.
  ///
  /// In en, this message translates to:
  /// **'Every file type has already been opened for this season'**
  String get moduleAllTypesUsed;

  /// No description provided for @moduleOnePerSeason.
  ///
  /// In en, this message translates to:
  /// **'A file of a kind is created once per season, and its type is its name'**
  String get moduleOnePerSeason;

  /// No description provided for @moduleSeasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get moduleSeasonLabel;

  /// No description provided for @moduleDecisionBadge.
  ///
  /// In en, this message translates to:
  /// **'Decision {number}'**
  String moduleDecisionBadge(String number);

  /// No description provided for @moduleDecisionNumber.
  ///
  /// In en, this message translates to:
  /// **'Decision / file number'**
  String get moduleDecisionNumber;

  /// No description provided for @moduleDecisionNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — added when the decision is issued'**
  String get moduleDecisionNumberHint;

  /// No description provided for @moduleEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get moduleEndDate;

  /// No description provided for @moduleEndDateHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — the file ends at the close of this day'**
  String get moduleEndDateHint;

  /// No description provided for @moduleEndDateClear.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get moduleEndDateClear;

  /// No description provided for @moduleEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end date is before the start date'**
  String get moduleEndBeforeStart;

  /// No description provided for @moduleStartDate.
  ///
  /// In en, this message translates to:
  /// **'Work starts on'**
  String get moduleStartDate;

  /// No description provided for @moduleStartNote.
  ///
  /// In en, this message translates to:
  /// **'Start note'**
  String get moduleStartNote;

  /// No description provided for @moduleStartNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — what there is to say about this file\'s start'**
  String get moduleStartNoteHint;

  /// No description provided for @moduleEndNote.
  ///
  /// In en, this message translates to:
  /// **'End note'**
  String get moduleEndNote;

  /// No description provided for @moduleEndNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — what there is to say about this file\'s end'**
  String get moduleEndNoteHint;

  /// No description provided for @moduleReportCadence.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get moduleReportCadence;

  /// No description provided for @moduleReportCadenceHint.
  ///
  /// In en, this message translates to:
  /// **'How often the people in this file file one'**
  String get moduleReportCadenceHint;

  /// No description provided for @cadenceNone.
  ///
  /// In en, this message translates to:
  /// **'No reports'**
  String get cadenceNone;

  /// No description provided for @cadenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get cadenceDaily;

  /// No description provided for @cadenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get cadenceWeekly;

  /// No description provided for @cadenceOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get cadenceOnce;

  /// No description provided for @moduleRatingNone.
  ///
  /// In en, this message translates to:
  /// **'Nobody has rated you in this file yet'**
  String get moduleRatingNone;

  /// No description provided for @moduleRatingValue.
  ///
  /// In en, this message translates to:
  /// **'{average} of 5 · {count, plural, =1{1 rating} other{{count} ratings}}'**
  String moduleRatingValue(String average, int count);

  /// No description provided for @moduleRatingAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Ratings are anonymous — a colleague sees his average and how many rated him, never who gave what'**
  String get moduleRatingAnonymous;

  /// No description provided for @moduleRatingSaved.
  ///
  /// In en, this message translates to:
  /// **'Rating saved'**
  String get moduleRatingSaved;

  /// No description provided for @moduleRatingCleared.
  ///
  /// In en, this message translates to:
  /// **'Rating withdrawn'**
  String get moduleRatingCleared;

  /// No description provided for @moduleReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get moduleReports;

  /// No description provided for @moduleReportWrite.
  ///
  /// In en, this message translates to:
  /// **'File a report'**
  String get moduleReportWrite;

  /// No description provided for @moduleReportEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit my report'**
  String get moduleReportEdit;

  /// No description provided for @moduleReportNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get moduleReportNotes;

  /// No description provided for @moduleReportNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — anything to add about what you attached'**
  String get moduleReportNotesHint;

  /// No description provided for @moduleReportAttachHint.
  ///
  /// In en, this message translates to:
  /// **'The report is what you upload: photos, files or a voice note'**
  String get moduleReportAttachHint;

  /// No description provided for @moduleReportNothingAttached.
  ///
  /// In en, this message translates to:
  /// **'Nothing attached'**
  String get moduleReportNothingAttached;

  /// No description provided for @moduleReportSaved.
  ///
  /// In en, this message translates to:
  /// **'Report filed'**
  String get moduleReportSaved;

  /// No description provided for @moduleReportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reports filed yet'**
  String get moduleReportsEmpty;

  /// No description provided for @moduleReportPeriodDay.
  ///
  /// In en, this message translates to:
  /// **'Report for {date}'**
  String moduleReportPeriodDay(String date);

  /// No description provided for @moduleReportPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String moduleReportPeriodWeek(String date);

  /// No description provided for @moduleStartCondition.
  ///
  /// In en, this message translates to:
  /// **'Work begins'**
  String get moduleStartCondition;

  /// No description provided for @moduleEndCondition.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get moduleEndCondition;

  /// No description provided for @moduleStepInfo.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get moduleStepInfo;

  /// No description provided for @moduleStepSectors.
  ///
  /// In en, this message translates to:
  /// **'Sectors'**
  String get moduleStepSectors;

  /// No description provided for @moduleStepTowers.
  ///
  /// In en, this message translates to:
  /// **'Towers'**
  String get moduleStepTowers;

  /// No description provided for @moduleStepMembers.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get moduleStepMembers;

  /// No description provided for @moduleNodeName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get moduleNodeName;

  /// No description provided for @moduleNodeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add {level}'**
  String moduleNodeAdd(String level);

  /// No description provided for @moduleNodeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit {level}'**
  String moduleNodeEdit(String level);

  /// No description provided for @moduleNodeDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete {level}'**
  String moduleNodeDelete(String level);

  /// No description provided for @moduleNodeDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? Everything inside it goes with it.'**
  String moduleNodeDeleteConfirm(String name);

  /// No description provided for @moduleNodeSuggestedName.
  ///
  /// In en, this message translates to:
  /// **'{level} {number}'**
  String moduleNodeSuggestedName(String level, int number);

  /// No description provided for @moduleSectorsImport.
  ///
  /// In en, this message translates to:
  /// **'Import sectors'**
  String get moduleSectorsImport;

  /// No description provided for @moduleSectorsImportPick.
  ///
  /// In en, this message translates to:
  /// **'Copy the sectors from another file in this season — the name, the supervisor and his deputy. The copies are independent: deleting a sector here does not touch the other file.'**
  String get moduleSectorsImportPick;

  /// No description provided for @moduleSectorsImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No new sectors} =1{Imported 1 sector} other{Imported {count} sectors}}'**
  String moduleSectorsImported(int count);

  /// No description provided for @moduleSectorsImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import the sectors'**
  String get moduleSectorsImportFailed;

  /// No description provided for @moduleSectorsImportNoSources.
  ///
  /// In en, this message translates to:
  /// **'No other file in this season has sectors'**
  String get moduleSectorsImportNoSources;

  /// No description provided for @moduleNoNodes.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been added yet'**
  String get moduleNoNodes;

  /// No description provided for @moduleSectorsFirst.
  ///
  /// In en, this message translates to:
  /// **'Add the sectors first, then place the hotels in them'**
  String get moduleSectorsFirst;

  /// No description provided for @moduleBuildTree.
  ///
  /// In en, this message translates to:
  /// **'Add sectors & towers'**
  String get moduleBuildTree;

  /// No description provided for @moduleNoLevels.
  ///
  /// In en, this message translates to:
  /// **'This file type has no structure defined yet'**
  String get moduleNoLevels;

  /// No description provided for @moduleSectionWhen.
  ///
  /// In en, this message translates to:
  /// **'Work period'**
  String get moduleSectionWhen;

  /// No description provided for @moduleSectionPaperwork.
  ///
  /// In en, this message translates to:
  /// **'Decision and reports'**
  String get moduleSectionPaperwork;

  /// No description provided for @moduleSectionTypeFields.
  ///
  /// In en, this message translates to:
  /// **'Fields of this type'**
  String get moduleSectionTypeFields;

  /// No description provided for @moduleNotesShow.
  ///
  /// In en, this message translates to:
  /// **'Add a note to the start or the end'**
  String get moduleNotesShow;

  /// No description provided for @moduleNotesHide.
  ///
  /// In en, this message translates to:
  /// **'Hide the notes'**
  String get moduleNotesHide;

  /// No description provided for @moduleSectionInfo.
  ///
  /// In en, this message translates to:
  /// **'File information'**
  String get moduleSectionInfo;

  /// No description provided for @moduleSectionTasks.
  ///
  /// In en, this message translates to:
  /// **'My role'**
  String get moduleSectionTasks;

  /// No description provided for @moduleSectionTasksOf.
  ///
  /// In en, this message translates to:
  /// **'{name} — role'**
  String moduleSectionTasksOf(String name);

  /// No description provided for @moduleJobDescription.
  ///
  /// In en, this message translates to:
  /// **'Job description'**
  String get moduleJobDescription;

  /// No description provided for @moduleTasksSection.
  ///
  /// In en, this message translates to:
  /// **'Duties'**
  String get moduleTasksSection;

  /// No description provided for @moduleTasksFile.
  ///
  /// In en, this message translates to:
  /// **'File duties'**
  String get moduleTasksFile;

  /// No description provided for @moduleTasksFileHint.
  ///
  /// In en, this message translates to:
  /// **'The whole file\'s work — its members divide it among themselves'**
  String get moduleTasksFileHint;

  /// No description provided for @moduleTasksRole.
  ///
  /// In en, this message translates to:
  /// **'Role duties'**
  String get moduleTasksRole;

  /// No description provided for @moduleTasksRoleOf.
  ///
  /// In en, this message translates to:
  /// **'{name} duties'**
  String moduleTasksRoleOf(String name);

  /// No description provided for @moduleTasksRoleHint.
  ///
  /// In en, this message translates to:
  /// **'Attached to the post, not the person — replacing the holder leaves them standing'**
  String get moduleTasksRoleHint;

  /// No description provided for @moduleTasksNone.
  ///
  /// In en, this message translates to:
  /// **'This file has no duties written yet'**
  String get moduleTasksNone;

  /// No description provided for @taskStateNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get taskStateNotStarted;

  /// No description provided for @taskStateInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get taskStateInProgress;

  /// No description provided for @taskStateBlocked.
  ///
  /// In en, this message translates to:
  /// **'Stuck'**
  String get taskStateBlocked;

  /// No description provided for @taskStateSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Awaiting acceptance'**
  String get taskStateSubmitted;

  /// No description provided for @taskStateDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskStateDone;

  /// No description provided for @taskStateReturned.
  ///
  /// In en, this message translates to:
  /// **'Sent back'**
  String get taskStateReturned;

  /// No description provided for @taskStateCancelled.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get taskStateCancelled;

  /// No description provided for @moduleTaskDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String moduleTaskDue(String date);

  /// No description provided for @moduleTaskAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a duty'**
  String get moduleTaskAdd;

  /// No description provided for @moduleTaskEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit duty'**
  String get moduleTaskEdit;

  /// No description provided for @moduleTaskDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete duty'**
  String get moduleTaskDelete;

  /// No description provided for @moduleTaskDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this duty from the file\'s list?'**
  String get moduleTaskDeleteConfirm;

  /// No description provided for @moduleTaskScope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get moduleTaskScope;

  /// No description provided for @moduleTaskScopeFile.
  ///
  /// In en, this message translates to:
  /// **'File duty'**
  String get moduleTaskScopeFile;

  /// No description provided for @moduleTaskScopeFileHint.
  ///
  /// In en, this message translates to:
  /// **'The whole file\'s — members share it among themselves'**
  String get moduleTaskScopeFileHint;

  /// No description provided for @moduleTaskScopeRole.
  ///
  /// In en, this message translates to:
  /// **'Role duty'**
  String get moduleTaskScopeRole;

  /// No description provided for @moduleTaskScopeRoleHint.
  ///
  /// In en, this message translates to:
  /// **'What holding the post means, whoever holds it'**
  String get moduleTaskScopeRoleHint;

  /// No description provided for @moduleTaskRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get moduleTaskRoleLabel;

  /// No description provided for @moduleTaskTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Duty'**
  String get moduleTaskTitleLabel;

  /// No description provided for @moduleTaskTitleEnLabel.
  ///
  /// In en, this message translates to:
  /// **'English title'**
  String get moduleTaskTitleEnLabel;

  /// No description provided for @moduleTaskDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get moduleTaskDescriptionLabel;

  /// No description provided for @moduleTaskNoDue.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get moduleTaskNoDue;

  /// No description provided for @moduleTaskPickRole.
  ///
  /// In en, this message translates to:
  /// **'Choose a role'**
  String get moduleTaskPickRole;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'My tasks'**
  String get navTasks;

  /// No description provided for @navTasksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your own list, and what was assigned to you'**
  String get navTasksSubtitle;

  /// No description provided for @tasksTitle.
  ///
  /// In en, this message translates to:
  /// **'My tasks'**
  String get tasksTitle;

  /// No description provided for @tasksOwnSection.
  ///
  /// In en, this message translates to:
  /// **'My own tasks'**
  String get tasksOwnSection;

  /// No description provided for @tasksOwnHint.
  ///
  /// In en, this message translates to:
  /// **'You wrote these for yourself — edit, delete and move them freely'**
  String get tasksOwnHint;

  /// No description provided for @tasksAssignedSection.
  ///
  /// In en, this message translates to:
  /// **'Assigned to me'**
  String get tasksAssignedSection;

  /// No description provided for @tasksAssignedHint.
  ///
  /// In en, this message translates to:
  /// **'Written for you — you change only how they are going'**
  String get tasksAssignedHint;

  /// No description provided for @tasksIAssignedSection.
  ///
  /// In en, this message translates to:
  /// **'Assigned by me'**
  String get tasksIAssignedSection;

  /// No description provided for @tasksIAssignedHint.
  ///
  /// In en, this message translates to:
  /// **'What you wrote onto other people\'s lists, followed up from here'**
  String get tasksIAssignedHint;

  /// No description provided for @tasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get tasksEmpty;

  /// No description provided for @tasksEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Write your first task with the button below'**
  String get tasksEmptyHint;

  /// No description provided for @tasksNew.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get tasksNew;

  /// No description provided for @tasksAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign a task'**
  String get tasksAssign;

  /// No description provided for @navTasksManage.
  ///
  /// In en, this message translates to:
  /// **'Task assignment'**
  String get navTasksManage;

  /// No description provided for @navTasksManageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write tasks onto other people\'s lists, and follow them up'**
  String get navTasksManageSubtitle;

  /// No description provided for @tasksManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Task assignment'**
  String get tasksManageTitle;

  /// No description provided for @tasksManageEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have assigned nothing yet'**
  String get tasksManageEmpty;

  /// No description provided for @tasksManageEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Assign a task with the button below — its owner is told, and changes only how it is going'**
  String get tasksManageEmptyHint;

  /// No description provided for @taskPickPerson.
  ///
  /// In en, this message translates to:
  /// **'Choose an employee'**
  String get taskPickPerson;

  /// No description provided for @taskAssignedBy.
  ///
  /// In en, this message translates to:
  /// **'Assigned by {name}'**
  String taskAssignedBy(String name);

  /// No description provided for @taskAssignedTo.
  ///
  /// In en, this message translates to:
  /// **'For {name}'**
  String taskAssignedTo(String name);

  /// No description provided for @taskTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskTitleLabel;

  /// No description provided for @taskDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get taskDescriptionLabel;

  /// No description provided for @taskDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String taskDue(String date);

  /// No description provided for @taskNoDue.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get taskNoDue;

  /// No description provided for @taskState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get taskState;

  /// No description provided for @taskNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get taskNote;

  /// No description provided for @taskNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Anything worth saying about it?'**
  String get taskNoteHint;

  /// No description provided for @taskEvidence.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get taskEvidence;

  /// No description provided for @taskUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update state'**
  String get taskUpdate;

  /// No description provided for @taskStateSaved.
  ///
  /// In en, this message translates to:
  /// **'State updated'**
  String get taskStateSaved;

  /// No description provided for @taskSaved.
  ///
  /// In en, this message translates to:
  /// **'Task saved'**
  String get taskSaved;

  /// No description provided for @taskReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Assigned to you — move it and talk about it; its wording is its author\'s'**
  String get taskReadOnly;

  /// No description provided for @taskEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get taskEdit;

  /// No description provided for @taskDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get taskDelete;

  /// No description provided for @taskDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this task? Whatever was filed against it goes with it.'**
  String get taskDeleteConfirm;

  /// No description provided for @taskProgress.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total}'**
  String taskProgress(int done, int total);

  /// No description provided for @taskKey.
  ///
  /// In en, this message translates to:
  /// **'T-{seq}'**
  String taskKey(int seq);

  /// No description provided for @taskMoveStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get taskMoveStart;

  /// No description provided for @taskMoveBlock.
  ///
  /// In en, this message translates to:
  /// **'I\'m stuck'**
  String get taskMoveBlock;

  /// No description provided for @taskMoveSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send for acceptance'**
  String get taskMoveSubmit;

  /// No description provided for @taskMoveDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskMoveDone;

  /// No description provided for @taskMoveAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get taskMoveAccept;

  /// No description provided for @taskMoveReturn.
  ///
  /// In en, this message translates to:
  /// **'Send back'**
  String get taskMoveReturn;

  /// No description provided for @taskMoveReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get taskMoveReopen;

  /// No description provided for @taskMoveCancel.
  ///
  /// In en, this message translates to:
  /// **'Withdraw task'**
  String get taskMoveCancel;

  /// No description provided for @taskMoveRestore.
  ///
  /// In en, this message translates to:
  /// **'Put it back'**
  String get taskMoveRestore;

  /// No description provided for @taskNoActions.
  ///
  /// In en, this message translates to:
  /// **'Nothing here is yours to move right now'**
  String get taskNoActions;

  /// No description provided for @taskPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get taskPriority;

  /// No description provided for @taskPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get taskPriorityHigh;

  /// No description provided for @taskPriorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get taskPriorityNormal;

  /// No description provided for @taskPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get taskPriorityLow;

  /// No description provided for @taskKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get taskKind;

  /// No description provided for @taskKindTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskKindTask;

  /// No description provided for @taskKindFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get taskKindFollowUp;

  /// No description provided for @taskKindRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get taskKindRequest;

  /// No description provided for @taskViewToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get taskViewToday;

  /// No description provided for @taskViewWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get taskViewWeek;

  /// No description provided for @taskViewOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get taskViewOverdue;

  /// No description provided for @taskViewOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get taskViewOpen;

  /// No description provided for @taskViewDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskViewDone;

  /// No description provided for @taskViewAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get taskViewAll;

  /// No description provided for @taskLateDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day late} other{{days} days late}}'**
  String taskLateDays(int days);

  /// No description provided for @taskDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get taskDueToday;

  /// No description provided for @taskDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get taskDueTomorrow;

  /// No description provided for @taskThread.
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get taskThread;

  /// No description provided for @taskThreadEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing said yet'**
  String get taskThreadEmpty;

  /// No description provided for @taskCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Say what is worth saying'**
  String get taskCommentHint;

  /// No description provided for @taskCommentSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get taskCommentSend;

  /// No description provided for @taskCommentAdded.
  ///
  /// In en, this message translates to:
  /// **'Comment added'**
  String get taskCommentAdded;

  /// No description provided for @taskCommentRequired.
  ///
  /// In en, this message translates to:
  /// **'This move needs a reason in words'**
  String get taskCommentRequired;

  /// No description provided for @taskBySystem.
  ///
  /// In en, this message translates to:
  /// **'The system'**
  String get taskBySystem;

  /// No description provided for @taskEventCreated.
  ///
  /// In en, this message translates to:
  /// **'created the task'**
  String get taskEventCreated;

  /// No description provided for @taskEventAssigned.
  ///
  /// In en, this message translates to:
  /// **'assigned the task'**
  String get taskEventAssigned;

  /// No description provided for @taskEventStateTo.
  ///
  /// In en, this message translates to:
  /// **'moved it to: {state}'**
  String taskEventStateTo(String state);

  /// No description provided for @taskEventReassigned.
  ///
  /// In en, this message translates to:
  /// **'handed it to somebody else'**
  String get taskEventReassigned;

  /// No description provided for @taskEventDue.
  ///
  /// In en, this message translates to:
  /// **'moved the deadline to {date}'**
  String taskEventDue(String date);

  /// No description provided for @taskEventDueCleared.
  ///
  /// In en, this message translates to:
  /// **'removed the deadline'**
  String get taskEventDueCleared;

  /// No description provided for @taskEventPriority.
  ///
  /// In en, this message translates to:
  /// **'changed the priority to {priority}'**
  String taskEventPriority(String priority);

  /// No description provided for @taskEventEscalated.
  ///
  /// In en, this message translates to:
  /// **'reported as late'**
  String get taskEventEscalated;

  /// No description provided for @taskSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get taskSteps;

  /// No description provided for @taskStepsProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String taskStepsProgress(int done, int total);

  /// No description provided for @taskStepsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit steps'**
  String get taskStepsEdit;

  /// No description provided for @taskStepAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a step'**
  String get taskStepAdd;

  /// No description provided for @taskStepHint.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get taskStepHint;

  /// No description provided for @taskStepsSaved.
  ///
  /// In en, this message translates to:
  /// **'Steps saved'**
  String get taskStepsSaved;

  /// No description provided for @taskStepsOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Steps are written by whoever assigned the task'**
  String get taskStepsOwnerOnly;

  /// No description provided for @taskBatchOf.
  ///
  /// In en, this message translates to:
  /// **'Part of: {title}'**
  String taskBatchOf(String title);

  /// No description provided for @taskBatchCarriers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String taskBatchCarriers(int count);

  /// No description provided for @taskBatchAcceptReady.
  ///
  /// In en, this message translates to:
  /// **'Accept the ready ({count})'**
  String taskBatchAcceptReady(int count);

  /// No description provided for @taskBatchNudge.
  ///
  /// In en, this message translates to:
  /// **'Nudge the rest'**
  String get taskBatchNudge;

  /// No description provided for @taskBatchAccepted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task accepted} other{{count} tasks accepted}}'**
  String taskBatchAccepted(int count);

  /// No description provided for @taskBatchNudged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person reminded} other{{count} people reminded}}'**
  String taskBatchNudged(int count);

  /// No description provided for @tasksBatchesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No batches yet'**
  String get tasksBatchesEmpty;

  /// No description provided for @tasksBatchesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'A batch is written when one task goes to more than one person'**
  String get tasksBatchesEmptyHint;

  /// No description provided for @taskReassign.
  ///
  /// In en, this message translates to:
  /// **'Reassign'**
  String get taskReassign;

  /// No description provided for @taskReassignHint.
  ///
  /// In en, this message translates to:
  /// **'It moves with its thread and its evidence, and returns to Not started'**
  String get taskReassignHint;

  /// No description provided for @taskReassigned.
  ///
  /// In en, this message translates to:
  /// **'Task handed over'**
  String get taskReassigned;

  /// No description provided for @taskCancel.
  ///
  /// In en, this message translates to:
  /// **'Withdraw task'**
  String get taskCancel;

  /// No description provided for @taskCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Withdraw this task? It stays in the record, its owner is told, and nothing is deleted.'**
  String get taskCancelConfirm;

  /// No description provided for @taskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Task withdrawn'**
  String get taskCancelled;

  /// No description provided for @taskGone.
  ///
  /// In en, this message translates to:
  /// **'This task is no longer there'**
  String get taskGone;

  /// No description provided for @taskGoneHint.
  ///
  /// In en, this message translates to:
  /// **'It was probably withdrawn or deleted'**
  String get taskGoneHint;

  /// No description provided for @taskStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Started {date}'**
  String taskStartedAt(String date);

  /// No description provided for @taskSubmittedAt.
  ///
  /// In en, this message translates to:
  /// **'Sent for acceptance {date}'**
  String taskSubmittedAt(String date);

  /// No description provided for @taskAcceptedAt.
  ///
  /// In en, this message translates to:
  /// **'Accepted {date}'**
  String taskAcceptedAt(String date);

  /// No description provided for @tasksSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by title or number'**
  String get tasksSearch;

  /// No description provided for @tasksNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches what you searched for'**
  String get tasksNoMatch;

  /// No description provided for @tasksClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get tasksClearFilters;

  /// No description provided for @tasksBoardTitle.
  ///
  /// In en, this message translates to:
  /// **'Task board'**
  String get tasksBoardTitle;

  /// No description provided for @tasksBoardView.
  ///
  /// In en, this message translates to:
  /// **'By state'**
  String get tasksBoardView;

  /// No description provided for @tasksBatchesView.
  ///
  /// In en, this message translates to:
  /// **'By task'**
  String get tasksBatchesView;

  /// No description provided for @tasksPeopleView.
  ///
  /// In en, this message translates to:
  /// **'By person'**
  String get tasksPeopleView;

  /// No description provided for @tasksAssignTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Who is the task for?'**
  String get tasksAssignTargetTitle;

  /// No description provided for @tasksAssignToPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get tasksAssignToPeople;

  /// No description provided for @tasksAssignToPeopleHint.
  ///
  /// In en, this message translates to:
  /// **'A tracked task on each chosen person\'s list, sent back to you for acceptance'**
  String get tasksAssignToPeopleHint;

  /// No description provided for @tasksAssignToFile.
  ///
  /// In en, this message translates to:
  /// **'An operational file'**
  String get tasksAssignToFile;

  /// No description provided for @tasksAssignToFileHint.
  ///
  /// In en, this message translates to:
  /// **'A duty written on the file itself, read and shared by all its members'**
  String get tasksAssignToFileHint;

  /// No description provided for @tasksAssignToRole.
  ///
  /// In en, this message translates to:
  /// **'A role in a file'**
  String get tasksAssignToRole;

  /// No description provided for @tasksAssignToRoleHint.
  ///
  /// In en, this message translates to:
  /// **'A duty on one post — the tower supervisor, say — whoever holds it'**
  String get tasksAssignToRoleHint;

  /// No description provided for @tasksAssignPickModule.
  ///
  /// In en, this message translates to:
  /// **'Choose the file'**
  String get tasksAssignPickModule;

  /// No description provided for @tasksAssignPickRole.
  ///
  /// In en, this message translates to:
  /// **'Choose the role'**
  String get tasksAssignPickRole;

  /// No description provided for @tasksAssignNoRoles.
  ///
  /// In en, this message translates to:
  /// **'This file\'s type defines no roles'**
  String get tasksAssignNoRoles;

  /// No description provided for @tasksAssignDutySaved.
  ///
  /// In en, this message translates to:
  /// **'The duty was written on the file'**
  String get tasksAssignDutySaved;

  /// No description provided for @tasksScopeMine.
  ///
  /// In en, this message translates to:
  /// **'Assigned by me'**
  String get tasksScopeMine;

  /// No description provided for @tasksScopeAll.
  ///
  /// In en, this message translates to:
  /// **'The whole mission'**
  String get tasksScopeAll;

  /// No description provided for @tasksReviewQueue.
  ///
  /// In en, this message translates to:
  /// **'Awaiting your acceptance'**
  String get tasksReviewQueue;

  /// No description provided for @tasksReviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting on you'**
  String get tasksReviewEmpty;

  /// No description provided for @taskStatsOpen.
  ///
  /// In en, this message translates to:
  /// **'On me'**
  String get taskStatsOpen;

  /// No description provided for @taskStatsOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get taskStatsOverdue;

  /// No description provided for @taskStatsReview.
  ///
  /// In en, this message translates to:
  /// **'Awaiting my acceptance'**
  String get taskStatsReview;

  /// No description provided for @taskStatsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskStatsDone;

  /// No description provided for @moduleTeamPick.
  ///
  /// In en, this message translates to:
  /// **'Choose members'**
  String get moduleTeamPick;

  /// No description provided for @moduleTeamPickFor.
  ///
  /// In en, this message translates to:
  /// **'Choose: {role}'**
  String moduleTeamPickFor(String role);

  /// No description provided for @moduleNoTeamMembers.
  ///
  /// In en, this message translates to:
  /// **'No one has been put on this team yet'**
  String get moduleNoTeamMembers;

  /// No description provided for @moduleNoRoles.
  ///
  /// In en, this message translates to:
  /// **'This file type has no roles defined yet'**
  String get moduleNoRoles;

  /// No description provided for @moduleMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String moduleMembersCount(int count);

  /// No description provided for @moduleNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No one has been assigned here yet'**
  String get moduleNoMembers;

  /// No description provided for @moduleRoleUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get moduleRoleUnassigned;

  /// No description provided for @moduleMemberHousing.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get moduleMemberHousing;

  /// No description provided for @moduleHousingUnset.
  ///
  /// In en, this message translates to:
  /// **'No housing set'**
  String get moduleHousingUnset;

  /// No description provided for @moduleHousedHere.
  ///
  /// In en, this message translates to:
  /// **'Housed here'**
  String get moduleHousedHere;

  /// No description provided for @moduleSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get moduleSaved;

  /// No description provided for @moduleActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate file'**
  String get moduleActivate;

  /// No description provided for @moduleDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate file'**
  String get moduleDeactivate;

  /// No description provided for @moduleActivated.
  ///
  /// In en, this message translates to:
  /// **'File activated — members have been notified'**
  String get moduleActivated;

  /// No description provided for @moduleDeactivated.
  ///
  /// In en, this message translates to:
  /// **'File deactivated'**
  String get moduleDeactivated;

  /// No description provided for @moduleAttachPdf.
  ///
  /// In en, this message translates to:
  /// **'Attach PDF'**
  String get moduleAttachPdf;

  /// No description provided for @moduleReplacePdf.
  ///
  /// In en, this message translates to:
  /// **'Replace file'**
  String get moduleReplacePdf;

  /// No description provided for @moduleOpenPdf.
  ///
  /// In en, this message translates to:
  /// **'Open PDF'**
  String get moduleOpenPdf;

  /// No description provided for @moduleNoPdf.
  ///
  /// In en, this message translates to:
  /// **'No file attached'**
  String get moduleNoPdf;

  /// No description provided for @modulePdfOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file'**
  String get modulePdfOpenFailed;

  /// No description provided for @moduleDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete file'**
  String get moduleDelete;

  /// No description provided for @moduleDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this file? Everything in it — its members, the duties they were handed, and its attachments — goes with it.'**
  String get moduleDeleteConfirm;

  /// No description provided for @moduleDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted'**
  String get moduleDeleted;

  /// No description provided for @moduleNoCurrentSeason.
  ///
  /// In en, this message translates to:
  /// **'Set a current season before creating files'**
  String get moduleNoCurrentSeason;

  /// No description provided for @moduleNoParticipants.
  ///
  /// In en, this message translates to:
  /// **'The current season has no participants yet'**
  String get moduleNoParticipants;

  /// No description provided for @moduleContactSy.
  ///
  /// In en, this message translates to:
  /// **'Syrian number'**
  String get moduleContactSy;

  /// No description provided for @moduleContactSa.
  ///
  /// In en, this message translates to:
  /// **'Saudi number'**
  String get moduleContactSa;

  /// No description provided for @modulePickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or job title'**
  String get modulePickerSearchHint;

  /// No description provided for @modulePickerAll.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get modulePickerAll;

  /// No description provided for @modulePickerInternal.
  ///
  /// In en, this message translates to:
  /// **'Mission staff'**
  String get modulePickerInternal;

  /// No description provided for @modulePickerExternal.
  ///
  /// In en, this message translates to:
  /// **'External'**
  String get modulePickerExternal;

  /// No description provided for @modulePickerNoMatches.
  ///
  /// In en, this message translates to:
  /// **'Nobody matches that search'**
  String get modulePickerNoMatches;

  /// No description provided for @modulePickerFree.
  ///
  /// In en, this message translates to:
  /// **'Not in any file'**
  String get modulePickerFree;

  /// No description provided for @modulePickerAlreadyIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Already in 1 file} other{Already in {count} files}}'**
  String modulePickerAlreadyIn(int count);

  /// No description provided for @modulePickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Confirm with nobody chosen} =1{Confirm 1 person} other{Confirm {count} people}}'**
  String modulePickerConfirm(int count);

  /// No description provided for @referenceShelfPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get referenceShelfPlaces;

  /// No description provided for @referenceShelfStructure.
  ///
  /// In en, this message translates to:
  /// **'File divisions'**
  String get referenceShelfStructure;

  /// No description provided for @referenceShelfMission.
  ///
  /// In en, this message translates to:
  /// **'The mission'**
  String get referenceShelfMission;

  /// No description provided for @referenceShelfReports.
  ///
  /// In en, this message translates to:
  /// **'Report inputs'**
  String get referenceShelfReports;

  /// No description provided for @referenceShelfOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get referenceShelfOther;

  /// No description provided for @referenceDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Master data'**
  String get referenceDataTitle;

  /// No description provided for @referenceItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} entries'**
  String referenceItemsCount(int count);

  /// No description provided for @referenceImport.
  ///
  /// In en, this message translates to:
  /// **'Import from another season'**
  String get referenceImport;

  /// No description provided for @referenceImportPick.
  ///
  /// In en, this message translates to:
  /// **'Copy the list from an earlier season. The copies are independent — deleting one here does not touch the other season.'**
  String get referenceImportPick;

  /// No description provided for @referenceImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} entries'**
  String referenceImported(int count);

  /// No description provided for @referenceImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get referenceImportFailed;

  /// No description provided for @referenceImportNoSeasons.
  ///
  /// In en, this message translates to:
  /// **'No other seasons'**
  String get referenceImportNoSeasons;

  /// No description provided for @referenceAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get referenceAddItem;

  /// No description provided for @referenceItemName.
  ///
  /// In en, this message translates to:
  /// **'Name (Arabic)'**
  String get referenceItemName;

  /// No description provided for @referenceItemNameEn.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get referenceItemNameEn;

  /// No description provided for @referenceItemSaved.
  ///
  /// In en, this message translates to:
  /// **'Entry saved'**
  String get referenceItemSaved;

  /// No description provided for @referenceItemDeleted.
  ///
  /// In en, this message translates to:
  /// **'Entry deleted'**
  String get referenceItemDeleted;

  /// No description provided for @referenceDivisionAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get referenceDivisionAll;

  /// No description provided for @referenceDivisionNone.
  ///
  /// In en, this message translates to:
  /// **'Unclassified'**
  String get referenceDivisionNone;

  /// No description provided for @referenceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No entries yet'**
  String get referenceEmpty;

  /// No description provided for @referenceDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String referenceDeleteConfirm(String name);

  /// No description provided for @referenceInUse.
  ///
  /// In en, this message translates to:
  /// **'This entry is used by a module and cannot be deleted'**
  String get referenceInUse;

  /// No description provided for @referenceDuplicate.
  ///
  /// In en, this message translates to:
  /// **'An entry with this name already exists in the list'**
  String get referenceDuplicate;

  /// No description provided for @referenceDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get referenceDeleteAll;

  /// No description provided for @referenceDeleteAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes {count} entries from “{name}”. It cannot be undone.'**
  String referenceDeleteAllConfirm(int count, String name);

  /// No description provided for @referenceDeleteAllDone.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} entries'**
  String referenceDeleteAllDone(int count);

  /// No description provided for @referenceDeleteAllPartial.
  ///
  /// In en, this message translates to:
  /// **'Deleted {deleted}; {kept} kept because they are used by modules or other lists'**
  String referenceDeleteAllPartial(int deleted, int kept);

  /// No description provided for @referenceDeleteAllNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing was deleted: every entry is used by a module or another list'**
  String get referenceDeleteAllNone;

  /// No description provided for @referenceDeletingAll.
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get referenceDeletingAll;

  /// No description provided for @referenceOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get referenceOpenLink;

  /// No description provided for @locationPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Set location'**
  String get locationPickerTitle;

  /// No description provided for @locationPickOnMap.
  ///
  /// In en, this message translates to:
  /// **'On the map'**
  String get locationPickOnMap;

  /// No description provided for @locationUseCurrent.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get locationUseCurrent;

  /// No description provided for @locationOrPasteLink.
  ///
  /// In en, this message translates to:
  /// **'Or paste a map link'**
  String get locationOrPasteLink;

  /// No description provided for @locationTapToPlace.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to place the pin'**
  String get locationTapToPlace;

  /// No description provided for @locationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm this location'**
  String get locationConfirm;

  /// No description provided for @locationCaptured.
  ///
  /// In en, this message translates to:
  /// **'Current location captured'**
  String get locationCaptured;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location access was not granted'**
  String get locationPermissionDenied;

  /// No description provided for @locationServiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off'**
  String get locationServiceDisabled;

  /// No description provided for @locationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not determine your location'**
  String get locationFailed;

  /// No description provided for @locationOpenMap.
  ///
  /// In en, this message translates to:
  /// **'Open on map'**
  String get locationOpenMap;

  /// No description provided for @referenceCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get referenceCall;

  /// No description provided for @referenceLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link'**
  String get referenceLinkFailed;

  /// No description provided for @referenceDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get referenceDetailsTitle;

  /// No description provided for @profileSectionPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get profileSectionPermissions;

  /// No description provided for @profilePermissionsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator — every permission'**
  String get profilePermissionsAdmin;

  /// No description provided for @profilePermissionsNone.
  ///
  /// In en, this message translates to:
  /// **'No administrative permissions'**
  String get profilePermissionsNone;

  /// No description provided for @profilePermissionsNoneHint.
  ///
  /// In en, this message translates to:
  /// **'Which is the ordinary case: an operational file reaches you by assignment, not by permission.'**
  String get profilePermissionsNoneHint;

  /// No description provided for @profilePermissionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{one permission} other{{count} permissions}}'**
  String profilePermissionsCount(int count);

  /// No description provided for @navAuditLog.
  ///
  /// In en, this message translates to:
  /// **'Activity log'**
  String get navAuditLog;

  /// No description provided for @navAuditLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Who did what, and when'**
  String get navAuditLogSubtitle;

  /// No description provided for @auditEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get auditEmptyTitle;

  /// No description provided for @auditEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Every change made in the app is recorded here.'**
  String get auditEmptyBody;

  /// No description provided for @auditPulseTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get auditPulseTitle;

  /// No description provided for @auditPulseByAction.
  ///
  /// In en, this message translates to:
  /// **'By kind of act'**
  String get auditPulseByAction;

  /// No description provided for @auditPulseEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing happened in this window'**
  String get auditPulseEmpty;

  /// No description provided for @auditPulseEvents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no events} =1{1 event} other{{count} events}}'**
  String auditPulseEvents(int count);

  /// No description provided for @auditPulseActors.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{nobody} =1{1 person} other{{count} people}}'**
  String auditPulseActors(int count);

  /// No description provided for @auditSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by person or record…'**
  String get auditSearchHint;

  /// No description provided for @auditActionInsert.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get auditActionInsert;

  /// No description provided for @auditActionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get auditActionUpdate;

  /// No description provided for @auditActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get auditActionDelete;

  /// No description provided for @auditActionLogin.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get auditActionLogin;

  /// No description provided for @auditActionLogout.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get auditActionLogout;

  /// No description provided for @auditFilterAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get auditFilterAction;

  /// No description provided for @auditFilterEntity.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get auditFilterEntity;

  /// No description provided for @auditFilterActor.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get auditFilterActor;

  /// No description provided for @auditFilterSeason.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get auditFilterSeason;

  /// No description provided for @auditSeasonNone.
  ///
  /// In en, this message translates to:
  /// **'No season'**
  String get auditSeasonNone;

  /// No description provided for @auditSeasonCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No events} =1{1 event} other{{count} events}}'**
  String auditSeasonCount(int count);

  /// No description provided for @auditFilterDate.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get auditFilterDate;

  /// No description provided for @auditClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get auditClearFilters;

  /// No description provided for @auditSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get auditSystem;

  /// No description provided for @auditDetails.
  ///
  /// In en, this message translates to:
  /// **'Event details'**
  String get auditDetails;

  /// No description provided for @auditActor.
  ///
  /// In en, this message translates to:
  /// **'Done by'**
  String get auditActor;

  /// No description provided for @auditChanges.
  ///
  /// In en, this message translates to:
  /// **'What changed'**
  String get auditChanges;

  /// No description provided for @auditRecordData.
  ///
  /// In en, this message translates to:
  /// **'Record data'**
  String get auditRecordData;

  /// No description provided for @auditDeletedData.
  ///
  /// In en, this message translates to:
  /// **'Deleted record'**
  String get auditDeletedData;

  /// No description provided for @auditRecipients.
  ///
  /// In en, this message translates to:
  /// **'{count} recipients'**
  String auditRecipients(int count);

  /// No description provided for @auditYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get auditYes;

  /// No description provided for @auditNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get auditNo;

  /// No description provided for @auditNoDetails.
  ///
  /// In en, this message translates to:
  /// **'This event carries no further details.'**
  String get auditNoDetails;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The season from above'**
  String get navDashboardSubtitle;

  /// No description provided for @chartOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get chartOther;

  /// No description provided for @chartTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get chartTotal;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardSeason.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get dashboardSeason;

  /// No description provided for @dashboardNoSeason.
  ///
  /// In en, this message translates to:
  /// **'No season yet'**
  String get dashboardNoSeason;

  /// No description provided for @dashboardNothingToShow.
  ///
  /// In en, this message translates to:
  /// **'You hold no permission that shows figures here'**
  String get dashboardNothingToShow;

  /// No description provided for @dashboardSectionPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get dashboardSectionPeople;

  /// No description provided for @dashboardSectionModules.
  ///
  /// In en, this message translates to:
  /// **'Operational files'**
  String get dashboardSectionModules;

  /// No description provided for @dashboardSectionWork.
  ///
  /// In en, this message translates to:
  /// **'The work'**
  String get dashboardSectionWork;

  /// No description provided for @dashboardSectionQueue.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get dashboardSectionQueue;

  /// No description provided for @dashboardSectionCentralReports.
  ///
  /// In en, this message translates to:
  /// **'Decisions'**
  String get dashboardSectionCentralReports;

  /// No description provided for @dashboardCentralPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get dashboardCentralPublished;

  /// No description provided for @dashboardCentralDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get dashboardCentralDrafts;

  /// No description provided for @dashboardCentralGeneral.
  ///
  /// In en, this message translates to:
  /// **'General (all seasons)'**
  String get dashboardCentralGeneral;

  /// No description provided for @dashboardCentralByType.
  ///
  /// In en, this message translates to:
  /// **'By type'**
  String get dashboardCentralByType;

  /// No description provided for @dashboardCentralSplit.
  ///
  /// In en, this message translates to:
  /// **'Published vs drafts'**
  String get dashboardCentralSplit;

  /// No description provided for @dashboardSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get dashboardSectionNotifications;

  /// No description provided for @dashboardNotifMessages30.
  ///
  /// In en, this message translates to:
  /// **'Messages (30 days)'**
  String get dashboardNotifMessages30;

  /// No description provided for @dashboardNotifRecipients.
  ///
  /// In en, this message translates to:
  /// **'Recipients'**
  String get dashboardNotifRecipients;

  /// No description provided for @dashboardNotifReadShare.
  ///
  /// In en, this message translates to:
  /// **'Read rate'**
  String get dashboardNotifReadShare;

  /// No description provided for @dashboardNotifReadOf.
  ///
  /// In en, this message translates to:
  /// **'{read} of {total} opened'**
  String dashboardNotifReadOf(int read, int total);

  /// No description provided for @dashboardNotifTrend.
  ///
  /// In en, this message translates to:
  /// **'Messages, last 30 days'**
  String get dashboardNotifTrend;

  /// No description provided for @dashboardNotifTrendEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages in the last 30 days'**
  String get dashboardNotifTrendEmpty;

  /// No description provided for @dashboardNotifAllTime.
  ///
  /// In en, this message translates to:
  /// **'{n} messages all-time'**
  String dashboardNotifAllTime(Object n);

  /// No description provided for @dashboardNotSeasonScoped.
  ///
  /// In en, this message translates to:
  /// **'All seasons — not filtered by the one selected'**
  String get dashboardNotSeasonScoped;

  /// No description provided for @dashboardSectionIncidents.
  ///
  /// In en, this message translates to:
  /// **'Urgent reports'**
  String get dashboardSectionIncidents;

  /// No description provided for @dashboardIncidentsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open reports'**
  String get dashboardIncidentsOpen;

  /// No description provided for @dashboardIncidentsInProgress.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{none in progress} =1{and 1 in progress} other{and {count} in progress}}'**
  String dashboardIncidentsInProgress(int count);

  /// No description provided for @dashboardIncidentsRecent.
  ///
  /// In en, this message translates to:
  /// **'Reports, last 30 days'**
  String get dashboardIncidentsRecent;

  /// No description provided for @dashboardIncidentsAllTime.
  ///
  /// In en, this message translates to:
  /// **'{count} all time'**
  String dashboardIncidentsAllTime(int count);

  /// No description provided for @dashboardIncidentsAvgHandle.
  ///
  /// In en, this message translates to:
  /// **'Average time to pick up'**
  String get dashboardIncidentsAvgHandle;

  /// No description provided for @dashboardIncidentsAvgHandleCaption.
  ///
  /// In en, this message translates to:
  /// **'From raised to taken on'**
  String get dashboardIncidentsAvgHandleCaption;

  /// No description provided for @dashboardIncidentsSplit.
  ///
  /// In en, this message translates to:
  /// **'Reports by state'**
  String get dashboardIncidentsSplit;

  /// No description provided for @dashboardIncidentsTrend.
  ///
  /// In en, this message translates to:
  /// **'Reports per day'**
  String get dashboardIncidentsTrend;

  /// No description provided for @dashboardIncidentsTrendEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reports in this period'**
  String get dashboardIncidentsTrendEmpty;

  /// No description provided for @dashboardSectionCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get dashboardSectionCheckIn;

  /// No description provided for @dashboardCheckInToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s arrivals'**
  String get dashboardCheckInToday;

  /// No description provided for @dashboardCheckInPeople.
  ///
  /// In en, this message translates to:
  /// **'People who filed'**
  String get dashboardCheckInPeople;

  /// No description provided for @dashboardCheckInPlaces.
  ///
  /// In en, this message translates to:
  /// **'at {count} places'**
  String dashboardCheckInPlaces(int count);

  /// No description provided for @dashboardCheckInTotal.
  ///
  /// In en, this message translates to:
  /// **'Arrivals this season'**
  String get dashboardCheckInTotal;

  /// No description provided for @dashboardCheckInTrend.
  ///
  /// In en, this message translates to:
  /// **'Arrivals per day'**
  String get dashboardCheckInTrend;

  /// No description provided for @dashboardCheckInTrendEmpty.
  ///
  /// In en, this message translates to:
  /// **'No arrivals in this period'**
  String get dashboardCheckInTrendEmpty;

  /// No description provided for @dashboardSectionTasks.
  ///
  /// In en, this message translates to:
  /// **'Assigned tasks'**
  String get dashboardSectionTasks;

  /// No description provided for @dashboardTasksOpen.
  ///
  /// In en, this message translates to:
  /// **'Open tasks'**
  String get dashboardTasksOpen;

  /// No description provided for @dashboardTasksLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get dashboardTasksLate;

  /// No description provided for @dashboardTasksEscalated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{none escalated} =1{1 escalated} other{{count} escalated}}'**
  String dashboardTasksEscalated(int count);

  /// No description provided for @dashboardTasksAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting review'**
  String get dashboardTasksAwaiting;

  /// No description provided for @dashboardTasksAssignees.
  ///
  /// In en, this message translates to:
  /// **'Assignees'**
  String get dashboardTasksAssignees;

  /// No description provided for @dashboardTasksAllTime.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks all time'**
  String dashboardTasksAllTime(int count);

  /// No description provided for @dashboardTasksByState.
  ///
  /// In en, this message translates to:
  /// **'Tasks by state'**
  String get dashboardTasksByState;

  /// No description provided for @dashboardTasksByPriority.
  ///
  /// In en, this message translates to:
  /// **'Open tasks by priority'**
  String get dashboardTasksByPriority;

  /// No description provided for @dashboardSectionEvaluations.
  ///
  /// In en, this message translates to:
  /// **'Evaluations'**
  String get dashboardSectionEvaluations;

  /// No description provided for @dashboardEvalSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Sheets submitted'**
  String get dashboardEvalSubmitted;

  /// No description provided for @dashboardEvalOf.
  ///
  /// In en, this message translates to:
  /// **'of {count}'**
  String dashboardEvalOf(int count);

  /// No description provided for @dashboardEvalLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get dashboardEvalLate;

  /// No description provided for @dashboardEvalDrafts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no drafts} =1{1 draft} other{{count} drafts}}'**
  String dashboardEvalDrafts(int count);

  /// No description provided for @dashboardEvalAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get dashboardEvalAverage;

  /// No description provided for @dashboardEvalAverageCaption.
  ///
  /// In en, this message translates to:
  /// **'As a share of each form\'s total'**
  String get dashboardEvalAverageCaption;

  /// No description provided for @dashboardEvalEvaluators.
  ///
  /// In en, this message translates to:
  /// **'Evaluators'**
  String get dashboardEvalEvaluators;

  /// No description provided for @dashboardSectionComplaints.
  ///
  /// In en, this message translates to:
  /// **'Complaints'**
  String get dashboardSectionComplaints;

  /// No description provided for @dashboardComplaintsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open complaints'**
  String get dashboardComplaintsOpen;

  /// No description provided for @dashboardComplaintsRecent.
  ///
  /// In en, this message translates to:
  /// **'Complaints, last 30 days'**
  String get dashboardComplaintsRecent;

  /// No description provided for @dashboardComplaintsAllTime.
  ///
  /// In en, this message translates to:
  /// **'{count} all time'**
  String dashboardComplaintsAllTime(int count);

  /// No description provided for @dashboardComplaintsDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get dashboardComplaintsDismissed;

  /// No description provided for @dashboardComplaintsLocked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{none locked} =1{and 1 locked} other{and {count} locked}}'**
  String dashboardComplaintsLocked(int count);

  /// No description provided for @dashboardComplaintsByTarget.
  ///
  /// In en, this message translates to:
  /// **'Complaints by subject'**
  String get dashboardComplaintsByTarget;

  /// No description provided for @dashboardSectionReference.
  ///
  /// In en, this message translates to:
  /// **'Master data'**
  String get dashboardSectionReference;

  /// No description provided for @dashboardRefSets.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get dashboardRefSets;

  /// No description provided for @dashboardRefItems.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get dashboardRefItems;

  /// No description provided for @dashboardRefActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get dashboardRefActive;

  /// No description provided for @dashboardRefSeasonSplit.
  ///
  /// In en, this message translates to:
  /// **'Seasonal vs general'**
  String get dashboardRefSeasonSplit;

  /// No description provided for @dashboardRefSeasonItems.
  ///
  /// In en, this message translates to:
  /// **'This season'**
  String get dashboardRefSeasonItems;

  /// No description provided for @dashboardRefGeneralItems.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get dashboardRefGeneralItems;

  /// No description provided for @dashboardRefBySet.
  ///
  /// In en, this message translates to:
  /// **'Entries per list'**
  String get dashboardRefBySet;

  /// No description provided for @dashboardSectionPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get dashboardSectionPermissions;

  /// No description provided for @dashboardPermAdmins.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get dashboardPermAdmins;

  /// No description provided for @dashboardPermGrantees.
  ///
  /// In en, this message translates to:
  /// **'Employees with grants'**
  String get dashboardPermGrantees;

  /// No description provided for @dashboardPermGrants.
  ///
  /// In en, this message translates to:
  /// **'Grants held'**
  String get dashboardPermGrants;

  /// No description provided for @dashboardPermBySection.
  ///
  /// In en, this message translates to:
  /// **'Grants by section'**
  String get dashboardPermBySection;

  /// No description provided for @dashboardParticipants.
  ///
  /// In en, this message translates to:
  /// **'On this season'**
  String get dashboardParticipants;

  /// No description provided for @dashboardWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get dashboardWithdrawn;

  /// No description provided for @dashboardWithdrawnCaption.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{nobody withdrew} =1{and one withdrew} other{and {count} withdrew}}'**
  String dashboardWithdrawnCaption(int count);

  /// No description provided for @dashboardInternalSplit.
  ///
  /// In en, this message translates to:
  /// **'Mission and outside'**
  String get dashboardInternalSplit;

  /// No description provided for @dashboardInternal.
  ///
  /// In en, this message translates to:
  /// **'Of the mission'**
  String get dashboardInternal;

  /// No description provided for @dashboardExternal.
  ///
  /// In en, this message translates to:
  /// **'From outside'**
  String get dashboardExternal;

  /// No description provided for @dashboardUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not stated'**
  String get dashboardUnknown;

  /// No description provided for @dashboardByMission.
  ///
  /// In en, this message translates to:
  /// **'By mission type'**
  String get dashboardByMission;

  /// No description provided for @dashboardByGender.
  ///
  /// In en, this message translates to:
  /// **'By gender'**
  String get dashboardByGender;

  /// No description provided for @dashboardByJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Largest trades'**
  String get dashboardByJobTitle;

  /// No description provided for @dashboardFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get dashboardFiles;

  /// No description provided for @dashboardFilesCaption.
  ///
  /// In en, this message translates to:
  /// **'{active} active, {draft} draft'**
  String dashboardFilesCaption(int active, int draft);

  /// No description provided for @dashboardRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get dashboardRunning;

  /// No description provided for @dashboardEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get dashboardEnded;

  /// No description provided for @dashboardNodes.
  ///
  /// In en, this message translates to:
  /// **'Sectors and towers'**
  String get dashboardNodes;

  /// No description provided for @dashboardMembers.
  ///
  /// In en, this message translates to:
  /// **'Hold a posting'**
  String get dashboardMembers;

  /// No description provided for @dashboardUnstaffed.
  ///
  /// In en, this message translates to:
  /// **'Files with nobody in them'**
  String get dashboardUnstaffed;

  /// No description provided for @dashboardUnstaffedCaption.
  ///
  /// In en, this message translates to:
  /// **'Nobody assigned yet'**
  String get dashboardUnstaffedCaption;

  /// No description provided for @dashboardByType.
  ///
  /// In en, this message translates to:
  /// **'By file type'**
  String get dashboardByType;

  /// No description provided for @dashboardActiveDraft.
  ///
  /// In en, this message translates to:
  /// **'Active against draft'**
  String get dashboardActiveDraft;

  /// No description provided for @dashboardReports.
  ///
  /// In en, this message translates to:
  /// **'Decisions'**
  String get dashboardReports;

  /// No description provided for @dashboardReportsCaption.
  ///
  /// In en, this message translates to:
  /// **'{authors, plural, =0{from nobody} =1{from one author} other{from {authors} authors}}'**
  String dashboardReportsCaption(int authors);

  /// No description provided for @dashboardReportsTrend.
  ///
  /// In en, this message translates to:
  /// **'Decisions over 30 days'**
  String get dashboardReportsTrend;

  /// No description provided for @dashboardReportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reports filed in this stretch'**
  String get dashboardReportsEmpty;

  /// No description provided for @dashboardRatings.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get dashboardRatings;

  /// No description provided for @dashboardAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get dashboardAverage;

  /// No description provided for @dashboardRatedPeople.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{nobody rated} =1{about one person} other{about {count} people}}'**
  String dashboardRatedPeople(int count);

  /// No description provided for @dashboardRatingDistribution.
  ///
  /// In en, this message translates to:
  /// **'Star distribution'**
  String get dashboardRatingDistribution;

  /// No description provided for @dashboardPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval'**
  String get dashboardPending;

  /// No description provided for @dashboardApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get dashboardApproved;

  /// No description provided for @dashboardRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get dashboardRejected;

  /// No description provided for @dashboardIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Profile incomplete'**
  String get dashboardIncomplete;

  /// No description provided for @prayerTimesTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer times'**
  String get prayerTimesTitle;

  /// No description provided for @prayerFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayerFajr;

  /// No description provided for @prayerSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get prayerSunrise;

  /// No description provided for @prayerDhuhr.
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get prayerDhuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayerAsr;

  /// No description provided for @prayerMaghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayerIsha;

  /// No description provided for @prayerNextLabel.
  ///
  /// In en, this message translates to:
  /// **'Next prayer'**
  String get prayerNextLabel;

  /// No description provided for @prayerFajrEndsLabel.
  ///
  /// In en, this message translates to:
  /// **'Fajr time ends'**
  String get prayerFajrEndsLabel;

  /// No description provided for @prayerRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get prayerRemainingLabel;

  /// No description provided for @prayerNowLabel.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get prayerNowLabel;

  /// No description provided for @prayerAm.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get prayerAm;

  /// No description provided for @prayerPm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get prayerPm;

  /// No description provided for @prayerTomorrow.
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get prayerTomorrow;

  /// No description provided for @prayerSunriseGapNote.
  ///
  /// In en, this message translates to:
  /// **'Sunrise — no prayer is due until Dhuhr'**
  String get prayerSunriseGapNote;

  /// No description provided for @prayerLocating.
  ///
  /// In en, this message translates to:
  /// **'Finding you…'**
  String get prayerLocating;

  /// No description provided for @prayerApproximate.
  ///
  /// In en, this message translates to:
  /// **'Approximate'**
  String get prayerApproximate;

  /// No description provided for @prayerYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get prayerYourLocation;

  /// No description provided for @prayerPlaceMakkah.
  ///
  /// In en, this message translates to:
  /// **'Makkah'**
  String get prayerPlaceMakkah;

  /// No description provided for @prayerPlaceMina.
  ///
  /// In en, this message translates to:
  /// **'Mina'**
  String get prayerPlaceMina;

  /// No description provided for @prayerPlaceMuzdalifah.
  ///
  /// In en, this message translates to:
  /// **'Muzdalifah'**
  String get prayerPlaceMuzdalifah;

  /// No description provided for @prayerPlaceArafat.
  ///
  /// In en, this message translates to:
  /// **'Arafat'**
  String get prayerPlaceArafat;

  /// No description provided for @prayerPlaceMadinah.
  ///
  /// In en, this message translates to:
  /// **'Madinah'**
  String get prayerPlaceMadinah;

  /// No description provided for @prayerPlaceJeddah.
  ///
  /// In en, this message translates to:
  /// **'Jeddah'**
  String get prayerPlaceJeddah;

  /// No description provided for @prayerAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer alerts'**
  String get prayerAlertsTitle;

  /// No description provided for @prayerAlertsEnable.
  ///
  /// In en, this message translates to:
  /// **'Announce the prayers'**
  String get prayerAlertsEnable;

  /// No description provided for @prayerAlertsHint.
  ///
  /// In en, this message translates to:
  /// **'This phone alone. Times are worked out on the device from where it is standing — nothing is sent from a server.'**
  String get prayerAlertsHint;

  /// No description provided for @prayerAlertsWhich.
  ///
  /// In en, this message translates to:
  /// **'Which prayers'**
  String get prayerAlertsWhich;

  /// No description provided for @prayerAlertsBefore.
  ///
  /// In en, this message translates to:
  /// **'Warning before the call'**
  String get prayerAlertsBefore;

  /// No description provided for @prayerAlertsBeforeOff.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get prayerAlertsBeforeOff;

  /// No description provided for @prayerAlertsMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String prayerAlertsMinutes(int count);

  /// No description provided for @prayerAlertsSilent.
  ///
  /// In en, this message translates to:
  /// **'Without a sound'**
  String get prayerAlertsSilent;

  /// No description provided for @prayerAlertsSilentHint.
  ///
  /// In en, this message translates to:
  /// **'It still appears and still vibrates.'**
  String get prayerAlertsSilentHint;

  /// No description provided for @prayerAlertsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are switched off for this app in the system settings.'**
  String get prayerAlertsBlocked;

  /// No description provided for @prayerAlertsInexact.
  ///
  /// In en, this message translates to:
  /// **'Android may hold these back by several minutes. Allow exact alarms so each call arrives on the minute.'**
  String get prayerAlertsInexact;

  /// No description provided for @prayerAlertsGrantExact.
  ///
  /// In en, this message translates to:
  /// **'Allow exact alarms'**
  String get prayerAlertsGrantExact;

  /// No description provided for @prayerAlertsNeedLocation.
  ///
  /// In en, this message translates to:
  /// **'Set your location on the prayer card first — nothing is announced from an approximate position.'**
  String get prayerAlertsNeedLocation;

  /// No description provided for @prayerAlertsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Prayer alerts are an Android feature.'**
  String get prayerAlertsUnsupported;

  /// No description provided for @prayerAlertNow.
  ///
  /// In en, this message translates to:
  /// **'{prayer} is now due'**
  String prayerAlertNow(String prayer);

  /// No description provided for @prayerAlertNowBody.
  ///
  /// In en, this message translates to:
  /// **'The call is at {clock}'**
  String prayerAlertNowBody(String clock);

  /// No description provided for @prayerAlertBefore.
  ///
  /// In en, this message translates to:
  /// **'{prayer} in {count} minutes'**
  String prayerAlertBefore(String prayer, int count);

  /// No description provided for @prayerAlertBeforeBody.
  ///
  /// In en, this message translates to:
  /// **'The call is at {clock}'**
  String prayerAlertBeforeBody(String clock);

  /// No description provided for @navMyComplaints.
  ///
  /// In en, this message translates to:
  /// **'Complaints'**
  String get navMyComplaints;

  /// No description provided for @navMyComplaintsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What you filed, and what came back'**
  String get navMyComplaintsSubtitle;

  /// No description provided for @navComplaints.
  ///
  /// In en, this message translates to:
  /// **'Complaints register'**
  String get navComplaints;

  /// No description provided for @navComplaintsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every complaint filed across the mission'**
  String get navComplaintsSubtitle;

  /// No description provided for @complaintsTitle.
  ///
  /// In en, this message translates to:
  /// **'Complaints'**
  String get complaintsTitle;

  /// No description provided for @complaintsMineTitle.
  ///
  /// In en, this message translates to:
  /// **'My complaints'**
  String get complaintsMineTitle;

  /// No description provided for @complaintsAgainstMeTitle.
  ///
  /// In en, this message translates to:
  /// **'Complaints about me'**
  String get complaintsAgainstMeTitle;

  /// No description provided for @complaintsNew.
  ///
  /// In en, this message translates to:
  /// **'File a complaint'**
  String get complaintsNew;

  /// No description provided for @complaintsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No complaints filed'**
  String get complaintsEmpty;

  /// No description provided for @complaintsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'File your first one with the button below'**
  String get complaintsEmptyHint;

  /// No description provided for @complaintsEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been filed yet'**
  String get complaintsEmptyAll;

  /// No description provided for @complaintsEmptyAllHint.
  ///
  /// In en, this message translates to:
  /// **'What staff file appears here as soon as it is filed'**
  String get complaintsEmptyAllHint;

  /// No description provided for @complaintsAgainstMeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been filed about you'**
  String get complaintsAgainstMeEmpty;

  /// No description provided for @complaintsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No complaint matches this'**
  String get complaintsNoMatches;

  /// No description provided for @complaintsNoMatchesHint.
  ///
  /// In en, this message translates to:
  /// **'Widen the search or clear the filters'**
  String get complaintsNoMatchesHint;

  /// No description provided for @complaintsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search complaints'**
  String get complaintsSearchHint;

  /// No description provided for @complaintsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get complaintsFilterAll;

  /// No description provided for @complaintsShowDismissed.
  ///
  /// In en, this message translates to:
  /// **'Include dismissed'**
  String get complaintsShowDismissed;

  /// No description provided for @complaintTarget.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get complaintTarget;

  /// No description provided for @complaintTargetEmployee.
  ///
  /// In en, this message translates to:
  /// **'An employee'**
  String get complaintTargetEmployee;

  /// No description provided for @complaintTargetModule.
  ///
  /// In en, this message translates to:
  /// **'An operational file'**
  String get complaintTargetModule;

  /// No description provided for @complaintTargetReport.
  ///
  /// In en, this message translates to:
  /// **'A decision'**
  String get complaintTargetReport;

  /// No description provided for @complaintTargetHotel.
  ///
  /// In en, this message translates to:
  /// **'A hotel'**
  String get complaintTargetHotel;

  /// No description provided for @complaintTargetCluster.
  ///
  /// In en, this message translates to:
  /// **'A cluster'**
  String get complaintTargetCluster;

  /// No description provided for @complaintTargetGroup.
  ///
  /// In en, this message translates to:
  /// **'A group'**
  String get complaintTargetGroup;

  /// No description provided for @complaintTargetOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get complaintTargetOther;

  /// No description provided for @complaintTargetPick.
  ///
  /// In en, this message translates to:
  /// **'Choose what this is about'**
  String get complaintTargetPick;

  /// No description provided for @complaintTargetNone.
  ///
  /// In en, this message translates to:
  /// **'No {kind} you can complain about: this lists the files you are posted to and the people you work with in them. Choose “Something else” and explain it in the complaint itself.'**
  String complaintTargetNone(String kind);

  /// No description provided for @complaintTargetPicked.
  ///
  /// In en, this message translates to:
  /// **'Selected: {name}'**
  String complaintTargetPicked(String name);

  /// No description provided for @complaintBody.
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get complaintBody;

  /// No description provided for @complaintBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Describe it in your own words'**
  String get complaintBodyHint;

  /// No description provided for @complaintBodyRequired.
  ///
  /// In en, this message translates to:
  /// **'Write what happened'**
  String get complaintBodyRequired;

  /// No description provided for @complaintTargetRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose what the complaint is about'**
  String get complaintTargetRequired;

  /// No description provided for @complaintSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send the complaint'**
  String get complaintSubmit;

  /// No description provided for @complaintSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Your complaint was filed'**
  String get complaintSubmitted;

  /// No description provided for @complaintAnonymousNote.
  ///
  /// In en, this message translates to:
  /// **'The person you are complaining about will read this, but will not be told who filed it.'**
  String get complaintAnonymousNote;

  /// No description provided for @complaintReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get complaintReply;

  /// No description provided for @complaintReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Write a reply'**
  String get complaintReplyHint;

  /// No description provided for @complaintReplySent.
  ///
  /// In en, this message translates to:
  /// **'Reply sent'**
  String get complaintReplySent;

  /// No description provided for @complaintReplyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No replies} =1{1 reply} other{{count} replies}}'**
  String complaintReplyCount(int count);

  /// No description provided for @complaintRoleComplainant.
  ///
  /// In en, this message translates to:
  /// **'The complainant'**
  String get complaintRoleComplainant;

  /// No description provided for @complaintRoleAccused.
  ///
  /// In en, this message translates to:
  /// **'The employee complained about'**
  String get complaintRoleAccused;

  /// No description provided for @complaintRoleManager.
  ///
  /// In en, this message translates to:
  /// **'Oversight'**
  String get complaintRoleManager;

  /// No description provided for @complaintLocked.
  ///
  /// In en, this message translates to:
  /// **'This complaint is closed to replies'**
  String get complaintLocked;

  /// No description provided for @complaintLock.
  ///
  /// In en, this message translates to:
  /// **'Close to replies'**
  String get complaintLock;

  /// No description provided for @complaintUnlock.
  ///
  /// In en, this message translates to:
  /// **'Reopen for replies'**
  String get complaintUnlock;

  /// No description provided for @complaintDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get complaintDismissed;

  /// No description provided for @complaintDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss as unfounded'**
  String get complaintDismiss;

  /// No description provided for @complaintUndismiss.
  ///
  /// In en, this message translates to:
  /// **'Reinstate'**
  String get complaintUndismiss;

  /// No description provided for @complaintDismissReason.
  ///
  /// In en, this message translates to:
  /// **'Why it is being dismissed (optional)'**
  String get complaintDismissReason;

  /// No description provided for @complaintDismissConfirm.
  ///
  /// In en, this message translates to:
  /// **'A dismissed complaint no longer counts toward an automatic suspension, and may lift one already in force. Dismiss it?'**
  String get complaintDismissConfirm;

  /// No description provided for @complaintDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete the complaint'**
  String get complaintDelete;

  /// No description provided for @complaintDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this complaint and everything attached to it? This cannot be undone.'**
  String get complaintDeleteConfirm;

  /// No description provided for @complaintDeleted.
  ///
  /// In en, this message translates to:
  /// **'Complaint deleted'**
  String get complaintDeleted;

  /// No description provided for @complaintWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get complaintWithdraw;

  /// No description provided for @complaintMissing.
  ///
  /// In en, this message translates to:
  /// **'This complaint is no longer there'**
  String get complaintMissing;

  /// No description provided for @complaintFiledOn.
  ///
  /// In en, this message translates to:
  /// **'Filed {date}'**
  String complaintFiledOn(String date);

  /// No description provided for @complaintsSectionAgainst.
  ///
  /// In en, this message translates to:
  /// **'Complaints about this employee'**
  String get complaintsSectionAgainst;

  /// No description provided for @complaintsAgainstCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} =1{1 complaint} other{{count} complaints}}'**
  String complaintsAgainstCount(int count);

  /// No description provided for @complaintsDistinctComplainants.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no one} =1{1 person} other{{count} different people}}'**
  String complaintsDistinctComplainants(int count);

  /// No description provided for @complaintsAutoSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended automatically by complaints'**
  String get complaintsAutoSuspended;

  /// No description provided for @complaintsAutoSuspendNear.
  ///
  /// In en, this message translates to:
  /// **'One more complainant suspends this account automatically'**
  String get complaintsAutoSuspendNear;

  /// No description provided for @complaintsDismissedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} dismissed'**
  String complaintsDismissedCount(int count);

  /// No description provided for @navEvaluations.
  ///
  /// In en, this message translates to:
  /// **'Evaluations'**
  String get navEvaluations;

  /// No description provided for @navEvaluationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What you were asked to evaluate'**
  String get navEvaluationsSubtitle;

  /// No description provided for @navEvaluationsManage.
  ///
  /// In en, this message translates to:
  /// **'Evaluation register'**
  String get navEvaluationsManage;

  /// No description provided for @navEvaluationsManageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every evaluation across the mission and its marks'**
  String get navEvaluationsManageSubtitle;

  /// No description provided for @navEvaluationForms.
  ///
  /// In en, this message translates to:
  /// **'Evaluation forms'**
  String get navEvaluationForms;

  /// No description provided for @navEvaluationFormsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The forms, their questions and their marks'**
  String get navEvaluationFormsSubtitle;

  /// No description provided for @evaluationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Evaluation register'**
  String get evaluationsTitle;

  /// No description provided for @evaluationsMineTitle.
  ///
  /// In en, this message translates to:
  /// **'My evaluations'**
  String get evaluationsMineTitle;

  /// No description provided for @evaluationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have not been asked to evaluate anything yet'**
  String get evaluationsEmpty;

  /// No description provided for @evaluationsEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'No evaluation has been opened yet'**
  String get evaluationsEmptyAll;

  /// No description provided for @evaluationsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get evaluationsNoMatches;

  /// No description provided for @evaluationsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by form or subject'**
  String get evaluationsSearchHint;

  /// No description provided for @evaluationsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get evaluationsFilterAll;

  /// No description provided for @evaluationsNew.
  ///
  /// In en, this message translates to:
  /// **'New evaluation'**
  String get evaluationsNew;

  /// No description provided for @evaluationsOpenCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{nothing outstanding} =1{1 outstanding} other{{count} outstanding}}'**
  String evaluationsOpenCount(int count);

  /// No description provided for @evaluationsOverdueCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{none overdue} =1{1 overdue} other{{count} overdue}}'**
  String evaluationsOverdueCount(int count);

  /// No description provided for @evaluationStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get evaluationStatusDraft;

  /// No description provided for @evaluationStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get evaluationStatusSubmitted;

  /// No description provided for @evaluationOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get evaluationOverdue;

  /// No description provided for @evaluationDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String evaluationDueOn(String date);

  /// No description provided for @evaluationOpenedOn.
  ///
  /// In en, this message translates to:
  /// **'Opened {date}'**
  String evaluationOpenedOn(String date);

  /// No description provided for @evaluationSubmittedOn.
  ///
  /// In en, this message translates to:
  /// **'Completed {date}'**
  String evaluationSubmittedOn(String date);

  /// No description provided for @evaluationEvaluator.
  ///
  /// In en, this message translates to:
  /// **'Evaluator'**
  String get evaluationEvaluator;

  /// No description provided for @evaluationEvaluatorHidden.
  ///
  /// In en, this message translates to:
  /// **'Evaluator not disclosed'**
  String get evaluationEvaluatorHidden;

  /// No description provided for @evaluationSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get evaluationSubject;

  /// No description provided for @evaluationNote.
  ///
  /// In en, this message translates to:
  /// **'Note from the office'**
  String get evaluationNote;

  /// No description provided for @evaluationProgress.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total}'**
  String evaluationProgress(int answered, int total);

  /// No description provided for @evaluationScore.
  ///
  /// In en, this message translates to:
  /// **'{score} of {total}'**
  String evaluationScore(String score, String total);

  /// No description provided for @evaluationPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String evaluationPercent(String percent);

  /// No description provided for @evaluationTargetEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get evaluationTargetEmployee;

  /// No description provided for @evaluationTargetModule.
  ///
  /// In en, this message translates to:
  /// **'Operational file'**
  String get evaluationTargetModule;

  /// No description provided for @evaluationTargetReport.
  ///
  /// In en, this message translates to:
  /// **'Decision'**
  String get evaluationTargetReport;

  /// No description provided for @evaluationTargetHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get evaluationTargetHotel;

  /// No description provided for @evaluationTargetCluster.
  ///
  /// In en, this message translates to:
  /// **'Cluster'**
  String get evaluationTargetCluster;

  /// No description provided for @evaluationTargetGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get evaluationTargetGroup;

  /// No description provided for @evaluationTargetOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get evaluationTargetOther;

  /// No description provided for @evaluationSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Evaluation'**
  String get evaluationSheetTitle;

  /// No description provided for @evaluationStageOf.
  ///
  /// In en, this message translates to:
  /// **'Stage {index} of {total}'**
  String evaluationStageOf(int index, int total);

  /// No description provided for @evaluationStageScore.
  ///
  /// In en, this message translates to:
  /// **'Stage mark {score} of {total}'**
  String evaluationStageScore(String score, String total);

  /// No description provided for @evaluationQuestionRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get evaluationQuestionRequired;

  /// No description provided for @evaluationQuestionOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get evaluationQuestionOptional;

  /// No description provided for @evaluationQuestionUnanswered.
  ///
  /// In en, this message translates to:
  /// **'Not answered'**
  String get evaluationQuestionUnanswered;

  /// No description provided for @evaluationWriteHint.
  ///
  /// In en, this message translates to:
  /// **'Write your answer'**
  String get evaluationWriteHint;

  /// No description provided for @evaluationSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get evaluationSaveDraft;

  /// No description provided for @evaluationSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit evaluation'**
  String get evaluationSubmit;

  /// No description provided for @evaluationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Evaluation submitted'**
  String get evaluationSubmitted;

  /// No description provided for @evaluationDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Answers saved'**
  String get evaluationDraftSaved;

  /// No description provided for @evaluationIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Answer every required question first'**
  String get evaluationIncomplete;

  /// No description provided for @evaluationReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get evaluationReopen;

  /// No description provided for @evaluationReopened.
  ///
  /// In en, this message translates to:
  /// **'Evaluation reopened'**
  String get evaluationReopened;

  /// No description provided for @evaluationReopenConfirm.
  ///
  /// In en, this message translates to:
  /// **'This returns the evaluation to in-progress and keeps the answers. Continue?'**
  String get evaluationReopenConfirm;

  /// No description provided for @evaluationNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get evaluationNext;

  /// No description provided for @evaluationBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get evaluationBack;

  /// No description provided for @evaluationLocked.
  ///
  /// In en, this message translates to:
  /// **'This evaluation is read-only'**
  String get evaluationLocked;

  /// No description provided for @evaluationDiscardChanges.
  ///
  /// In en, this message translates to:
  /// **'There are unsaved answers. Leave without saving?'**
  String get evaluationDiscardChanges;

  /// No description provided for @evaluationMissing.
  ///
  /// In en, this message translates to:
  /// **'Evaluation not found'**
  String get evaluationMissing;

  /// No description provided for @evaluationAlreadySubmitted.
  ///
  /// In en, this message translates to:
  /// **'This evaluation was already submitted'**
  String get evaluationAlreadySubmitted;

  /// No description provided for @evaluationDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete evaluation'**
  String get evaluationDelete;

  /// No description provided for @evaluationDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'This evaluation and its answers are deleted permanently. Continue?'**
  String get evaluationDeleteConfirm;

  /// No description provided for @evaluationDeleted.
  ///
  /// In en, this message translates to:
  /// **'Evaluation deleted'**
  String get evaluationDeleted;

  /// No description provided for @evaluationAssignTitle.
  ///
  /// In en, this message translates to:
  /// **'Open an evaluation'**
  String get evaluationAssignTitle;

  /// No description provided for @evaluationAssignForm.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get evaluationAssignForm;

  /// No description provided for @evaluationAssignPickForm.
  ///
  /// In en, this message translates to:
  /// **'Choose an evaluation form'**
  String get evaluationAssignPickForm;

  /// No description provided for @evaluationAssignNoForms.
  ///
  /// In en, this message translates to:
  /// **'No active forms. Create one and switch it on first.'**
  String get evaluationAssignNoForms;

  /// No description provided for @evaluationAssignSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get evaluationAssignSubject;

  /// No description provided for @evaluationAssignPickSubject.
  ///
  /// In en, this message translates to:
  /// **'Choose the subject'**
  String get evaluationAssignPickSubject;

  /// No description provided for @evaluationAssignSubjectPicked.
  ///
  /// In en, this message translates to:
  /// **'About: {name}'**
  String evaluationAssignSubjectPicked(String name);

  /// No description provided for @evaluationAssignEvaluator.
  ///
  /// In en, this message translates to:
  /// **'Evaluator'**
  String get evaluationAssignEvaluator;

  /// No description provided for @evaluationAssignPickEvaluator.
  ///
  /// In en, this message translates to:
  /// **'Choose the employee'**
  String get evaluationAssignPickEvaluator;

  /// No description provided for @evaluationAssignNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What should they look at? (optional)'**
  String get evaluationAssignNoteHint;

  /// No description provided for @evaluationAssignDue.
  ///
  /// In en, this message translates to:
  /// **'Due date (optional)'**
  String get evaluationAssignDue;

  /// No description provided for @evaluationAssignDueClear.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get evaluationAssignDueClear;

  /// No description provided for @evaluationAssignSubmit.
  ///
  /// In en, this message translates to:
  /// **'Open and send'**
  String get evaluationAssignSubmit;

  /// No description provided for @evaluationAssigned.
  ///
  /// In en, this message translates to:
  /// **'Evaluation opened and the evaluator notified'**
  String get evaluationAssigned;

  /// No description provided for @evaluationAssignAnonymousNote.
  ///
  /// In en, this message translates to:
  /// **'The employee sees their mark and never learns who wrote it.'**
  String get evaluationAssignAnonymousNote;

  /// No description provided for @evaluationFormsTitle.
  ///
  /// In en, this message translates to:
  /// **'Evaluation forms'**
  String get evaluationFormsTitle;

  /// No description provided for @evaluationFormsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No evaluation forms yet'**
  String get evaluationFormsEmpty;

  /// No description provided for @evaluationFormsNew.
  ///
  /// In en, this message translates to:
  /// **'New form'**
  String get evaluationFormsNew;

  /// No description provided for @evaluationFormsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search the forms'**
  String get evaluationFormsSearchHint;

  /// No description provided for @evaluationFormActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get evaluationFormActive;

  /// No description provided for @evaluationFormInactive.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get evaluationFormInactive;

  /// No description provided for @evaluationFormActivate.
  ///
  /// In en, this message translates to:
  /// **'Switch on'**
  String get evaluationFormActivate;

  /// No description provided for @evaluationFormDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Switch off'**
  String get evaluationFormDeactivate;

  /// No description provided for @evaluationFormStages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stage} other{{count} stages}}'**
  String evaluationFormStages(int count);

  /// No description provided for @evaluationFormQuestions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question} other{{count} questions}}'**
  String evaluationFormQuestions(int count);

  /// No description provided for @evaluationFormTotal.
  ///
  /// In en, this message translates to:
  /// **'out of {total}'**
  String evaluationFormTotal(String total);

  /// No description provided for @evaluationFormInUse.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 evaluation open on it} other{{count} evaluations open on it}}'**
  String evaluationFormInUse(int count);

  /// No description provided for @evaluationFormDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete form'**
  String get evaluationFormDelete;

  /// No description provided for @evaluationFormDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'This form, its stages and its questions are deleted. Continue?'**
  String get evaluationFormDeleteConfirm;

  /// No description provided for @evaluationFormDeleted.
  ///
  /// In en, this message translates to:
  /// **'Form deleted'**
  String get evaluationFormDeleted;

  /// No description provided for @evaluationFormInUseDelete.
  ///
  /// In en, this message translates to:
  /// **'A form with evaluations open on it cannot be deleted. Switch it off instead.'**
  String get evaluationFormInUseDelete;

  /// No description provided for @evaluationEditorNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New evaluation form'**
  String get evaluationEditorNewTitle;

  /// No description provided for @evaluationEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit form'**
  String get evaluationEditorTitle;

  /// No description provided for @evaluationEditorName.
  ///
  /// In en, this message translates to:
  /// **'Form name'**
  String get evaluationEditorName;

  /// No description provided for @evaluationEditorNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Operational file evaluation - Tarwiyah and catering'**
  String get evaluationEditorNameHint;

  /// No description provided for @evaluationEditorDescription.
  ///
  /// In en, this message translates to:
  /// **'Short description (optional)'**
  String get evaluationEditorDescription;

  /// No description provided for @evaluationEditorFor.
  ///
  /// In en, this message translates to:
  /// **'Evaluates'**
  String get evaluationEditorFor;

  /// No description provided for @evaluationEditorForLocked.
  ///
  /// In en, this message translates to:
  /// **'The subject kind cannot change once evaluations have been opened on the form'**
  String get evaluationEditorForLocked;

  /// No description provided for @evaluationEditorPublish.
  ///
  /// In en, this message translates to:
  /// **'Active for use'**
  String get evaluationEditorPublish;

  /// No description provided for @evaluationEditorPublishHint.
  ///
  /// In en, this message translates to:
  /// **'A form that is switched off takes no new evaluations; the ones already open keep working'**
  String get evaluationEditorPublishHint;

  /// No description provided for @evaluationEditorStages.
  ///
  /// In en, this message translates to:
  /// **'Stages'**
  String get evaluationEditorStages;

  /// No description provided for @evaluationEditorAddStage.
  ///
  /// In en, this message translates to:
  /// **'Add stage'**
  String get evaluationEditorAddStage;

  /// No description provided for @evaluationEditorStageName.
  ///
  /// In en, this message translates to:
  /// **'Stage name'**
  String get evaluationEditorStageName;

  /// No description provided for @evaluationEditorStageNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Tarwiyah team'**
  String get evaluationEditorStageNameHint;

  /// No description provided for @evaluationEditorStageDescription.
  ///
  /// In en, this message translates to:
  /// **'Stage description (optional)'**
  String get evaluationEditorStageDescription;

  /// No description provided for @evaluationEditorRemoveStage.
  ///
  /// In en, this message translates to:
  /// **'Delete stage'**
  String get evaluationEditorRemoveStage;

  /// No description provided for @evaluationEditorRemoveStageConfirm.
  ///
  /// In en, this message translates to:
  /// **'The stage and all its questions are deleted. Continue?'**
  String get evaluationEditorRemoveStageConfirm;

  /// No description provided for @evaluationEditorAddChoice.
  ///
  /// In en, this message translates to:
  /// **'Multiple-choice question'**
  String get evaluationEditorAddChoice;

  /// No description provided for @evaluationEditorAddWritten.
  ///
  /// In en, this message translates to:
  /// **'Written question'**
  String get evaluationEditorAddWritten;

  /// No description provided for @evaluationEditorQuestionText.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get evaluationEditorQuestionText;

  /// No description provided for @evaluationEditorQuestionPoints.
  ///
  /// In en, this message translates to:
  /// **'Question mark'**
  String get evaluationEditorQuestionPoints;

  /// No description provided for @evaluationEditorRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get evaluationEditorRequired;

  /// No description provided for @evaluationEditorAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add answer'**
  String get evaluationEditorAddOption;

  /// No description provided for @evaluationEditorOptionText.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get evaluationEditorOptionText;

  /// No description provided for @evaluationEditorOptionPoints.
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get evaluationEditorOptionPoints;

  /// No description provided for @evaluationEditorNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'No questions in this stage yet'**
  String get evaluationEditorNoQuestions;

  /// No description provided for @evaluationEditorWrittenNote.
  ///
  /// In en, this message translates to:
  /// **'A written question carries no mark - neither the question nor its answer'**
  String get evaluationEditorWrittenNote;

  /// No description provided for @evaluationEditorUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The best answer gives {best} while the question is worth {points}'**
  String evaluationEditorUnreachable(String best, String points);

  /// No description provided for @evaluationEditorNeedsTwoOptions.
  ///
  /// In en, this message translates to:
  /// **'A multiple-choice question needs at least two answers'**
  String get evaluationEditorNeedsTwoOptions;

  /// No description provided for @evaluationEditorTotal.
  ///
  /// In en, this message translates to:
  /// **'Form total: {total}'**
  String evaluationEditorTotal(String total);

  /// No description provided for @evaluationEditorSave.
  ///
  /// In en, this message translates to:
  /// **'Save form'**
  String get evaluationEditorSave;

  /// No description provided for @evaluationEditorSaved.
  ///
  /// In en, this message translates to:
  /// **'Form saved'**
  String get evaluationEditorSaved;

  /// No description provided for @evaluationEditorCannotPublish.
  ///
  /// In en, this message translates to:
  /// **'Finish the form before switching it on: every stage needs a name, every question needs text, and every multiple-choice question needs at least two answers'**
  String get evaluationEditorCannotPublish;

  /// No description provided for @evaluationEditorMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get evaluationEditorMoveUp;

  /// No description provided for @evaluationEditorMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get evaluationEditorMoveDown;

  /// No description provided for @evaluationsAboutMeTitle.
  ///
  /// In en, this message translates to:
  /// **'Evaluations about me'**
  String get evaluationsAboutMeTitle;

  /// No description provided for @evaluationsAboutMeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No evaluation has been written about you'**
  String get evaluationsAboutMeEmpty;

  /// No description provided for @evaluationsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'Evaluations of this subject'**
  String get evaluationsSectionAbout;

  /// No description provided for @evaluationsAboutCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No evaluations} =1{1 evaluation} other{{count} evaluations}}'**
  String evaluationsAboutCount(int count);

  /// No description provided for @evaluationsAboutPending.
  ///
  /// In en, this message translates to:
  /// **'{count} in progress'**
  String evaluationsAboutPending(int count);

  /// No description provided for @evaluationsAboutAverage.
  ///
  /// In en, this message translates to:
  /// **'Average {percent}%'**
  String evaluationsAboutAverage(String percent);

  /// No description provided for @evaluationsAboutAnonymousNote.
  ///
  /// In en, this message translates to:
  /// **'Marks are shown without the names of who wrote them.'**
  String get evaluationsAboutAnonymousNote;

  /// No description provided for @evaluationErrorOptionTooHigh.
  ///
  /// In en, this message translates to:
  /// **'An answer is worth more than the question it answers'**
  String get evaluationErrorOptionTooHigh;

  /// No description provided for @evaluationErrorWrittenHasOptions.
  ///
  /// In en, this message translates to:
  /// **'A written question takes no preset answers'**
  String get evaluationErrorWrittenHasOptions;

  /// No description provided for @evaluationsOpenFromForms.
  ///
  /// In en, this message translates to:
  /// **'Evaluations are opened from إدارة التقييم, standing on the form they will be filled on'**
  String get evaluationsOpenFromForms;

  /// No description provided for @evaluationAssignNoTargets.
  ///
  /// In en, this message translates to:
  /// **'There is nothing of kind «{kind}» to open an evaluation about'**
  String evaluationAssignNoTargets(String kind);

  /// No description provided for @evaluationAssignNoEvaluators.
  ///
  /// In en, this message translates to:
  /// **'There is no employee who can be assigned'**
  String get evaluationAssignNoEvaluators;

  /// No description provided for @evaluationFormMustBeActive.
  ///
  /// In en, this message translates to:
  /// **'Switch the form on before an evaluation can be opened on it'**
  String get evaluationFormMustBeActive;

  /// No description provided for @evaluationEditorForHint.
  ///
  /// In en, this message translates to:
  /// **'This picks the KIND of subject only. The particular file or employee is named when an evaluation is opened on this form — from the «New evaluation» button on its card, once the form is switched on.'**
  String get evaluationEditorForHint;

  /// No description provided for @evaluationAssignNoSeason.
  ///
  /// In en, this message translates to:
  /// **'The current season could not be read, and the evaluator cannot be chosen without it'**
  String get evaluationAssignNoSeason;

  /// No description provided for @evaluationAssignedShow.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get evaluationAssignedShow;

  /// No description provided for @evaluationAssignSubjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get evaluationAssignSubjects;

  /// No description provided for @evaluationAssignEvaluators.
  ///
  /// In en, this message translates to:
  /// **'Evaluators'**
  String get evaluationAssignEvaluators;

  /// No description provided for @evaluationAssignPickSubjects.
  ///
  /// In en, this message translates to:
  /// **'Choose the subjects'**
  String get evaluationAssignPickSubjects;

  /// No description provided for @evaluationAssignPickEvaluators.
  ///
  /// In en, this message translates to:
  /// **'Choose the employees'**
  String get evaluationAssignPickEvaluators;

  /// No description provided for @evaluationAssignAddMore.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get evaluationAssignAddMore;

  /// No description provided for @evaluationAssignPlanned.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No evaluation will be opened} =1{1 evaluation will be opened} other{{count} evaluations will be opened}}'**
  String evaluationAssignPlanned(int count);

  /// No description provided for @evaluationAssignCross.
  ///
  /// In en, this message translates to:
  /// **'One per subject per evaluator — {targets} × {evaluators}'**
  String evaluationAssignCross(int targets, int evaluators);

  /// No description provided for @evaluationAssignedMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 evaluation opened and its evaluator notified} other{{count} evaluations opened and their evaluators notified}}'**
  String evaluationAssignedMany(int count);

  /// No description provided for @evaluationFormShowEvaluations.
  ///
  /// In en, this message translates to:
  /// **'Show the evaluations on it'**
  String get evaluationFormShowEvaluations;

  /// No description provided for @evaluationSubjectEvaluators.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No evaluator} =1{1 evaluator} other{{count} evaluators}}'**
  String evaluationSubjectEvaluators(int count);

  /// No description provided for @evaluationSubjectProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get evaluationSubjectProgressLabel;

  /// No description provided for @evaluationStatAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get evaluationStatAverage;

  /// No description provided for @evaluationStatBest.
  ///
  /// In en, this message translates to:
  /// **'Highest'**
  String get evaluationStatBest;

  /// No description provided for @evaluationStatWorst.
  ///
  /// In en, this message translates to:
  /// **'Lowest'**
  String get evaluationStatWorst;

  /// No description provided for @evaluationSubjectNoMarks.
  ///
  /// In en, this message translates to:
  /// **'No marks yet'**
  String get evaluationSubjectNoMarks;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @locationResolved.
  ///
  /// In en, this message translates to:
  /// **'Coordinates read from the link'**
  String get locationResolved;

  /// No description provided for @seasonMapOnlyThis.
  ///
  /// In en, this message translates to:
  /// **'Tap to show only this'**
  String get seasonMapOnlyThis;

  /// No description provided for @seasonMapShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get seasonMapShowAll;

  /// No description provided for @seasonMapNoTiles.
  ///
  /// In en, this message translates to:
  /// **'The map backdrop could not be loaded — the positions are right, only the pictures are missing'**
  String get seasonMapNoTiles;

  /// No description provided for @seasonMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Season map'**
  String get seasonMapTitle;

  /// No description provided for @seasonMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The season\'s places and open reports on one map'**
  String get seasonMapSubtitle;

  /// No description provided for @seasonMapManned.
  ///
  /// In en, this message translates to:
  /// **'Somebody is there'**
  String get seasonMapManned;

  /// No description provided for @seasonMapUnmanned.
  ///
  /// In en, this message translates to:
  /// **'Nobody checked in'**
  String get seasonMapUnmanned;

  /// No description provided for @seasonMapIncident.
  ///
  /// In en, this message translates to:
  /// **'Open report'**
  String get seasonMapIncident;

  /// No description provided for @seasonMapEmpty.
  ///
  /// In en, this message translates to:
  /// **'No members'**
  String get seasonMapEmpty;

  /// No description provided for @seasonMapPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted here'**
  String get seasonMapPosted;

  /// No description provided for @seasonMapPresent.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get seasonMapPresent;

  /// No description provided for @seasonMapOpenIncidents.
  ///
  /// In en, this message translates to:
  /// **'Open incidents'**
  String get seasonMapOpenIncidents;

  /// No description provided for @seasonMapCopyCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Copy coordinates'**
  String get seasonMapCopyCoordinates;

  /// No description provided for @seasonMapCoordinatesCopied.
  ///
  /// In en, this message translates to:
  /// **'Coordinates copied'**
  String get seasonMapCoordinatesCopied;

  /// No description provided for @seasonMapPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get seasonMapPlaces;

  /// No description provided for @seasonMapIncidents.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get seasonMapIncidents;

  /// No description provided for @seasonMapCounts.
  ///
  /// In en, this message translates to:
  /// **'{places} places · {incidents} reports'**
  String seasonMapCounts(int places, int incidents);

  /// No description provided for @seasonMapEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No place in this season has a position'**
  String get seasonMapEmptyState;

  /// No description provided for @seasonMapEmptyStateHint.
  ///
  /// In en, this message translates to:
  /// **'A place appears here once its position is set on the hotels or camps list'**
  String get seasonMapEmptyStateHint;

  /// No description provided for @incidentTitle.
  ///
  /// In en, this message translates to:
  /// **'Urgent report'**
  String get incidentTitle;

  /// No description provided for @incidentHint.
  ///
  /// In en, this message translates to:
  /// **'For what cannot wait — a breakdown, an accident, a cut-off. It reaches the operations room immediately.'**
  String get incidentHint;

  /// No description provided for @incidentBodyHint.
  ///
  /// In en, this message translates to:
  /// **'What has happened?'**
  String get incidentBodyHint;

  /// No description provided for @incidentAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach a photo'**
  String get incidentAttach;

  /// No description provided for @incidentSend.
  ///
  /// In en, this message translates to:
  /// **'Send the report'**
  String get incidentSend;

  /// No description provided for @incidentSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get incidentSending;

  /// No description provided for @incidentSent.
  ///
  /// In en, this message translates to:
  /// **'The operations room has been alerted'**
  String get incidentSent;

  /// No description provided for @incidentWhatIsAttached.
  ///
  /// In en, this message translates to:
  /// **'Attached automatically: your name, your position, the time'**
  String get incidentWhatIsAttached;

  /// No description provided for @incidentAbout.
  ///
  /// In en, this message translates to:
  /// **'What is it about? (optional)'**
  String get incidentAbout;

  /// No description provided for @incidentAboutKind.
  ///
  /// In en, this message translates to:
  /// **'What does the report concern?'**
  String get incidentAboutKind;

  /// No description provided for @incidentAboutModule.
  ///
  /// In en, this message translates to:
  /// **'An operational file'**
  String get incidentAboutModule;

  /// No description provided for @incidentAboutEmployee.
  ///
  /// In en, this message translates to:
  /// **'A member of staff'**
  String get incidentAboutEmployee;

  /// No description provided for @incidentAboutPage.
  ///
  /// In en, this message translates to:
  /// **'A screen in the app'**
  String get incidentAboutPage;

  /// No description provided for @incidentAboutClear.
  ///
  /// In en, this message translates to:
  /// **'Nothing in particular'**
  String get incidentAboutClear;

  /// No description provided for @incidentAboutNoModules.
  ///
  /// In en, this message translates to:
  /// **'No operational files in the current season'**
  String get incidentAboutNoModules;

  /// No description provided for @incidentAboutNoSeason.
  ///
  /// In en, this message translates to:
  /// **'The current season could not be determined'**
  String get incidentAboutNoSeason;

  /// No description provided for @incidentAboutLabel.
  ///
  /// In en, this message translates to:
  /// **'About: {what}'**
  String incidentAboutLabel(String what);

  /// No description provided for @incidentOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Open the screen'**
  String get incidentOpenPage;

  /// No description provided for @incidentOpenModule.
  ///
  /// In en, this message translates to:
  /// **'Open the file'**
  String get incidentOpenModule;

  /// No description provided for @incidentNotInRegister.
  ///
  /// In en, this message translates to:
  /// **'That report is no longer in the register'**
  String get incidentNotInRegister;

  /// No description provided for @incidentsShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show the whole register'**
  String get incidentsShowAll;

  /// No description provided for @incidentsOneReport.
  ///
  /// In en, this message translates to:
  /// **'One report'**
  String get incidentsOneReport;

  /// No description provided for @incidentNotDeliveredTitle.
  ///
  /// In en, this message translates to:
  /// **'It did not go through'**
  String get incidentNotDeliveredTitle;

  /// No description provided for @incidentNotDeliveredBody.
  ///
  /// In en, this message translates to:
  /// **'There is no network. The report is saved on your device and will be sent when it returns — but **nobody has been told yet**. If this cannot wait, telephone the operations room now.'**
  String get incidentNotDeliveredBody;

  /// No description provided for @incidentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Urgent reports'**
  String get incidentsTitle;

  /// No description provided for @incidentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No open reports'**
  String get incidentsEmpty;

  /// No description provided for @incidentsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Every urgent report appears here the moment it arrives'**
  String get incidentsEmptyHint;

  /// No description provided for @incidentsShowClosed.
  ///
  /// In en, this message translates to:
  /// **'Show closed'**
  String get incidentsShowClosed;

  /// No description provided for @incidentStateOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get incidentStateOpen;

  /// No description provided for @incidentStateInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get incidentStateInProgress;

  /// No description provided for @incidentStateClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get incidentStateClosed;

  /// No description provided for @incidentTake.
  ///
  /// In en, this message translates to:
  /// **'I\'ll take it'**
  String get incidentTake;

  /// No description provided for @incidentClose.
  ///
  /// In en, this message translates to:
  /// **'Close the report'**
  String get incidentClose;

  /// No description provided for @incidentReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get incidentReopen;

  /// No description provided for @incidentResolutionHint.
  ///
  /// In en, this message translates to:
  /// **'What happened? (optional)'**
  String get incidentResolutionHint;

  /// No description provided for @incidentCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get incidentCall;

  /// No description provided for @incidentOpenMap.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get incidentOpenMap;

  /// No description provided for @incidentWaited.
  ///
  /// In en, this message translates to:
  /// **'Waiting {duration}'**
  String incidentWaited(String duration);

  /// No description provided for @incidentHandledBy.
  ///
  /// In en, this message translates to:
  /// **'Taken by {name}'**
  String incidentHandledBy(String name);

  /// No description provided for @incidentOpenCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No open reports} =1{1 open report} other{{count} open reports}}'**
  String incidentOpenCount(int count);

  /// No description provided for @attachmentPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the picker. Try attaching another way.'**
  String get attachmentPickFailed;

  /// No description provided for @incidentDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete report'**
  String get incidentDelete;

  /// No description provided for @incidentDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'The report and anything attached to it are erased for good, and it leaves everyone\'s register. This cannot be undone.'**
  String get incidentDeleteConfirm;

  /// No description provided for @incidentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Report deleted'**
  String get incidentDeleted;

  /// No description provided for @incidentsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear the register'**
  String get incidentsClear;

  /// No description provided for @incidentsClearWhat.
  ///
  /// In en, this message translates to:
  /// **'What should be deleted?'**
  String get incidentsClearWhat;

  /// No description provided for @incidentsClearClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed ones only'**
  String get incidentsClearClosed;

  /// No description provided for @incidentsClearClosedHint.
  ///
  /// In en, this message translates to:
  /// **'Every open or in-progress report stays exactly as it is'**
  String get incidentsClearClosedHint;

  /// No description provided for @incidentsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Every report'**
  String get incidentsClearAll;

  /// No description provided for @incidentsClearAllHint.
  ///
  /// In en, this message translates to:
  /// **'Open ones included — they vanish from the screen of everyone watching the register right now'**
  String get incidentsClearAllHint;

  /// No description provided for @incidentsCleared.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing was deleted} =1{1 report deleted} other{{count} reports deleted}}'**
  String incidentsCleared(int count);

  /// No description provided for @incidentAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Urgent report'**
  String get incidentAlarmTitle;

  /// No description provided for @incidentAlarmOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the register'**
  String get incidentAlarmOpen;

  /// No description provided for @incidentAlarmDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get incidentAlarmDismiss;

  /// No description provided for @incidentAlarmMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{and 1 more} other{and {count} more}}'**
  String incidentAlarmMore(int count);

  /// No description provided for @navMyIncidentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The urgent reports you raised, and their status now'**
  String get navMyIncidentsSubtitle;

  /// No description provided for @myIncidentsTitle.
  ///
  /// In en, this message translates to:
  /// **'My reports'**
  String get myIncidentsTitle;

  /// No description provided for @myIncidentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have not raised an urgent report yet'**
  String get myIncidentsEmpty;

  /// No description provided for @myIncidentsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Your urgent reports appear here the moment you raise one, with their status'**
  String get myIncidentsEmptyHint;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String durationMinutes(int count);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String durationHours(int count);

  /// No description provided for @checkInScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the place code'**
  String get checkInScanTitle;

  /// No description provided for @checkInScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the code fixed at the place'**
  String get checkInScanHint;

  /// No description provided for @checkInTorch.
  ///
  /// In en, this message translates to:
  /// **'Torch'**
  String get checkInTorch;

  /// No description provided for @checkInNoCamera.
  ///
  /// In en, this message translates to:
  /// **'The camera could not be opened — the permission may be refused'**
  String get checkInNoCamera;

  /// No description provided for @checkInNoCameraHint.
  ///
  /// In en, this message translates to:
  /// **'Checking in needs the code and your location together, so there is no way to do it without a camera'**
  String get checkInNoCameraHint;

  /// No description provided for @checkInTitle.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get checkInTitle;

  /// No description provided for @checkInAction.
  ///
  /// In en, this message translates to:
  /// **'Record my arrival'**
  String get checkInAction;

  /// No description provided for @checkInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the code fixed to the hotel or camp while you are standing there'**
  String get checkInSubtitle;

  /// No description provided for @checkInPhoneOnly.
  ///
  /// In en, this message translates to:
  /// **'Arrivals are filed from a phone — it takes a camera on the place\'s code while you are standing at it. Your record is readable from any device.'**
  String get checkInPhoneOnly;

  /// No description provided for @checkInScan.
  ///
  /// In en, this message translates to:
  /// **'Scan the code'**
  String get checkInScan;

  /// No description provided for @checkInNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get checkInNoteHint;

  /// No description provided for @checkInDone.
  ///
  /// In en, this message translates to:
  /// **'Your arrival was recorded'**
  String get checkInDone;

  /// No description provided for @checkInDoneAt.
  ///
  /// In en, this message translates to:
  /// **'Recorded — {place}, {metres} m away'**
  String checkInDoneAt(String place, String metres);

  /// No description provided for @checkInQueued.
  ///
  /// In en, this message translates to:
  /// **'Saved on the device — it will be recorded when the network returns'**
  String get checkInQueued;

  /// No description provided for @checkInDistance.
  ///
  /// In en, this message translates to:
  /// **'{metres} m away'**
  String checkInDistance(String metres);

  /// No description provided for @checkInNotApproved.
  ///
  /// In en, this message translates to:
  /// **'Your account is not approved yet, so you cannot check in'**
  String get checkInNotApproved;

  /// No description provided for @checkInNotAPlace.
  ///
  /// In en, this message translates to:
  /// **'That code does not belong to a current place'**
  String get checkInNotAPlace;

  /// No description provided for @checkInNeedsAPosition.
  ///
  /// In en, this message translates to:
  /// **'Not recorded: turn location on, then scan the code again'**
  String get checkInNeedsAPosition;

  /// No description provided for @checkInCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'This code is no longer valid — look for the new one put up in its place'**
  String get checkInCodeExpired;

  /// No description provided for @checkInPlaceHasNoLocation.
  ///
  /// In en, this message translates to:
  /// **'This place has no location set, so how near you are cannot be checked. Tell the administration.'**
  String get checkInPlaceHasNoLocation;

  /// No description provided for @checkInTooFar.
  ///
  /// In en, this message translates to:
  /// **'You are too far from this place — you must be at it to check in'**
  String get checkInTooFar;

  /// No description provided for @checkInCodesDenied.
  ///
  /// In en, this message translates to:
  /// **'You may not view place codes'**
  String get checkInCodesDenied;

  /// No description provided for @checkInRotateDenied.
  ///
  /// In en, this message translates to:
  /// **'You may not regenerate place codes'**
  String get checkInRotateDenied;

  /// No description provided for @checkInQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Place code'**
  String get checkInQrTitle;

  /// No description provided for @checkInQrHint.
  ///
  /// In en, this message translates to:
  /// **'Print this and fix it at the place — whoever arrives scans it to record their arrival'**
  String get checkInQrHint;

  /// No description provided for @checkInQrPrint.
  ///
  /// In en, this message translates to:
  /// **'Print or share'**
  String get checkInQrPrint;

  /// No description provided for @checkInQrShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get checkInQrShare;

  /// No description provided for @checkInQrShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Sharing failed — use print instead'**
  String get checkInQrShareFailed;

  /// No description provided for @checkInQrSave.
  ///
  /// In en, this message translates to:
  /// **'Save to this device'**
  String get checkInQrSave;

  /// No description provided for @checkInQrSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String checkInQrSaved(String path);

  /// No description provided for @checkInQrSavedPlain.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get checkInQrSavedPlain;

  /// No description provided for @checkInQrSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the file'**
  String get checkInQrSaveFailed;

  /// No description provided for @checkInQrRotatesOn.
  ///
  /// In en, this message translates to:
  /// **'Rotates automatically: {when}'**
  String checkInQrRotatesOn(String when);

  /// No description provided for @checkInQrRotatesSoon.
  ///
  /// In en, this message translates to:
  /// **'Rotates automatically on {when} — print the replacement and put it up before that day, or nobody can check in here'**
  String checkInQrRotatesSoon(String when);

  /// No description provided for @checkInQrCard.
  ///
  /// In en, this message translates to:
  /// **'Check-in code'**
  String get checkInQrCard;

  /// No description provided for @checkInQrRotatedAt.
  ///
  /// In en, this message translates to:
  /// **'Last regenerated: {when}'**
  String checkInQrRotatedAt(String when);

  /// No description provided for @checkInQrNoLocation.
  ///
  /// In en, this message translates to:
  /// **'This place has no location — nobody can check in here until one is set'**
  String get checkInQrNoLocation;

  /// No description provided for @checkInQrRotate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate the code'**
  String get checkInQrRotate;

  /// No description provided for @checkInQrRotateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Every printed code for this place stops working immediately. The new one must be printed and put up before anybody can check in here.'**
  String get checkInQrRotateConfirm;

  /// No description provided for @checkInQrRotated.
  ///
  /// In en, this message translates to:
  /// **'Regenerated — print it and put it up now'**
  String get checkInQrRotated;

  /// No description provided for @checkInQrPrintAll.
  ///
  /// In en, this message translates to:
  /// **'Print the list\'s codes'**
  String get checkInQrPrintAll;

  /// No description provided for @checkInQrPrintingAll.
  ///
  /// In en, this message translates to:
  /// **'Preparing the codes…'**
  String get checkInQrPrintingAll;

  /// No description provided for @navMyCheckInsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where you checked in and when — and where you check in'**
  String get navMyCheckInsSubtitle;

  /// No description provided for @myCheckInsTitle.
  ///
  /// In en, this message translates to:
  /// **'My attendance'**
  String get myCheckInsTitle;

  /// No description provided for @myCheckInsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have not checked in yet'**
  String get myCheckInsEmpty;

  /// No description provided for @myCheckInsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Scan a place code with the button below while standing at it, and it appears here'**
  String get myCheckInsEmptyHint;

  /// No description provided for @myCheckInsWindowDay.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get myCheckInsWindowDay;

  /// No description provided for @myCheckInsWindowWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get myCheckInsWindowWeek;

  /// No description provided for @myCheckInsWindowAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get myCheckInsWindowAll;

  /// No description provided for @myCheckInsAllPlaces.
  ///
  /// In en, this message translates to:
  /// **'All places'**
  String get myCheckInsAllPlaces;

  /// No description provided for @myCheckInsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no check-ins} =1{1 check-in} other{{count} check-ins}}'**
  String myCheckInsCount(int count);

  /// No description provided for @presenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance record'**
  String get presenceTitle;

  /// No description provided for @presenceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The latest arrivals across the season\'s places'**
  String get presenceSubtitle;

  /// No description provided for @presenceEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody has checked in yet'**
  String get presenceEmpty;

  /// No description provided for @presenceTabPresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get presenceTabPresent;

  /// No description provided for @presenceTabGaps.
  ///
  /// In en, this message translates to:
  /// **'Not checked in'**
  String get presenceTabGaps;

  /// No description provided for @presenceGapsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Every post is confirmed'**
  String get presenceGapsEmpty;

  /// No description provided for @presenceGapsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No post at a place is without a check-in within the chosen window'**
  String get presenceGapsEmptyHint;

  /// No description provided for @presenceGapNeverSeen.
  ///
  /// In en, this message translates to:
  /// **'Never checked in'**
  String get presenceGapNeverSeen;

  /// No description provided for @presenceGapLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {time}'**
  String presenceGapLastSeen(String time);

  /// No description provided for @presenceGapCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{none} =1{1 post} other{{count} posts}}'**
  String presenceGapCount(int count);

  /// No description provided for @presenceEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Whoever scans a place code while standing at it appears here'**
  String get presenceEmptyHint;

  /// No description provided for @presenceWindow4h.
  ///
  /// In en, this message translates to:
  /// **'4 hours'**
  String get presenceWindow4h;

  /// No description provided for @presenceWindow12h.
  ///
  /// In en, this message translates to:
  /// **'12 hours'**
  String get presenceWindow12h;

  /// No description provided for @presenceWindow24h.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get presenceWindow24h;

  /// No description provided for @presenceCounts.
  ///
  /// In en, this message translates to:
  /// **'{people} people in {places} places'**
  String presenceCounts(int people, int places);

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get exportTitle;

  /// No description provided for @exportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take any list out as a file — with the columns you choose'**
  String get exportSubtitle;

  /// No description provided for @exportWhat.
  ///
  /// In en, this message translates to:
  /// **'What do you want to export?'**
  String get exportWhat;

  /// No description provided for @exportPickFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose one above'**
  String get exportPickFirst;

  /// No description provided for @exportPickFirstHint.
  ///
  /// In en, this message translates to:
  /// **'Once you have, what can be taken from it, the shape of the file, and the save and send buttons appear here.'**
  String get exportPickFirstHint;

  /// No description provided for @exportWhichColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get exportWhichColumns;

  /// No description provided for @exportWholeRecord.
  ///
  /// In en, this message translates to:
  /// **'Exported in full'**
  String get exportWholeRecord;

  /// No description provided for @exportWholeRecordHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing to tick here: the document is prose written in its own order, so it is printed whole — its details, its content block by block, its tables and what was attached.'**
  String get exportWholeRecordHint;

  /// No description provided for @exportColumnsDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get exportColumnsDefault;

  /// No description provided for @exportColumnsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get exportColumnsAll;

  /// No description provided for @exportPickAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one column'**
  String get exportPickAtLeastOne;

  /// No description provided for @exportSensitiveNotice.
  ///
  /// In en, this message translates to:
  /// **'\"{column}\" is internal: whoever holds it can tie the person to their records in any other table. The file leaves under your name and outlives this screen — let it reach only whoever needs it.'**
  String exportSensitiveNotice(String column);

  /// No description provided for @exportOptionAny.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to include all'**
  String get exportOptionAny;

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'File format'**
  String get exportFormat;

  /// No description provided for @exportFormatCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV (Excel)'**
  String get exportFormatCsv;

  /// No description provided for @exportFormatPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF (for printing)'**
  String get exportFormatPdf;

  /// No description provided for @exportSave.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get exportSave;

  /// No description provided for @exportShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get exportShare;

  /// No description provided for @exportSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String exportSavedTo(String path);

  /// No description provided for @exportSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the file'**
  String get exportSaveFailed;

  /// No description provided for @exportRunning.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get exportRunning;

  /// No description provided for @exportDoneRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row exported} other{{count} rows exported}}'**
  String exportDoneRows(int count);

  /// No description provided for @exportDoneRecords.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 complete record exported} other{{count} complete records exported}}'**
  String exportDoneRecords(int count);

  /// No description provided for @exportNothingMatched.
  ///
  /// In en, this message translates to:
  /// **'Nothing matched — check the options above'**
  String get exportNothingMatched;

  /// No description provided for @exportNothingAvailable.
  ///
  /// In en, this message translates to:
  /// **'There is nothing you can export'**
  String get exportNothingAvailable;

  /// No description provided for @exportNothingAvailableHint.
  ///
  /// In en, this message translates to:
  /// **'Export covers what you are allowed to see'**
  String get exportNothingAvailableHint;

  /// No description provided for @exportGeneratedBy.
  ///
  /// In en, this message translates to:
  /// **'From the Hajj Mission management system'**
  String get exportGeneratedBy;

  /// No description provided for @exportPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get exportPage;

  /// No description provided for @accountStatusIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get accountStatusIncomplete;

  /// No description provided for @accountStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get accountStatusPending;

  /// No description provided for @accountStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get accountStatusApproved;

  /// No description provided for @accountStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get accountStatusRejected;

  /// No description provided for @outboxSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved on the device — it will be sent when the network returns'**
  String get outboxSavedOffline;

  /// No description provided for @offlineShowingSaved.
  ///
  /// In en, this message translates to:
  /// **'No network — showing a saved copy, last updated {time}'**
  String offlineShowingSaved(String time);

  /// No description provided for @outboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be sent'**
  String get outboxTitle;

  /// No description provided for @outboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting to be sent'**
  String get outboxEmpty;

  /// No description provided for @outboxEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Everything you wrote has reached the server'**
  String get outboxEmptyHint;

  /// No description provided for @outboxPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item waiting to be sent} other{{count} items waiting to be sent}}'**
  String outboxPending(int count);

  /// No description provided for @outboxStateWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a network'**
  String get outboxStateWaiting;

  /// No description provided for @outboxStateSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get outboxStateSending;

  /// No description provided for @outboxStateBlocked.
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get outboxStateBlocked;

  /// No description provided for @outboxAttempts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attempt} other{{count} attempts}}'**
  String outboxAttempts(int count);

  /// No description provided for @outboxRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get outboxRetry;

  /// No description provided for @outboxDiscard.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get outboxDiscard;

  /// No description provided for @outboxDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this item?'**
  String get outboxDiscardTitle;

  /// No description provided for @outboxDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'It will never reach the server, and cannot be brought back.'**
  String get outboxDiscardBody;

  /// No description provided for @outboxKindTaskState.
  ///
  /// In en, this message translates to:
  /// **'Duty state'**
  String get outboxKindTaskState;

  /// No description provided for @outboxKindReport.
  ///
  /// In en, this message translates to:
  /// **'File report'**
  String get outboxKindReport;

  /// No description provided for @outboxBlockedNotice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item was not accepted} other{{count} items were not accepted}}'**
  String outboxBlockedNotice(int count);

  /// No description provided for @settingsInApp.
  ///
  /// In en, this message translates to:
  /// **'In the app'**
  String get settingsInApp;

  /// No description provided for @sidebarExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand the sidebar'**
  String get sidebarExpand;

  /// No description provided for @sidebarCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse the sidebar'**
  String get sidebarCollapse;

  /// No description provided for @sidebarMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get sidebarMenu;

  /// No description provided for @roadmapTitle.
  ///
  /// In en, this message translates to:
  /// **'Operational roadmap'**
  String get roadmapTitle;

  /// No description provided for @roadmapIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'How a season is run'**
  String get roadmapIntroTitle;

  /// No description provided for @roadmapIntroBody.
  ///
  /// In en, this message translates to:
  /// **'Every other screen in this app answers where something is. This one answers when. A season is laid out below from the week before it opens to the week after it closes: five phases, each step saying what is done at it and what it is waiting on. The whole map is drawn for everybody — the steps that are not yours are marked so, because knowing that somebody had to fill in the master data before your file existed is part of knowing your own place in the season.'**
  String get roadmapIntroBody;

  /// No description provided for @roadmapOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get roadmapOpen;

  /// No description provided for @roadmapLocked.
  ///
  /// In en, this message translates to:
  /// **'In the Administration\'s hands'**
  String get roadmapLocked;

  /// No description provided for @roadmapEveryone.
  ///
  /// In en, this message translates to:
  /// **'Open to everyone'**
  String get roadmapEveryone;

  /// No description provided for @roadmapPhaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Phase {number}'**
  String roadmapPhaseLabel(int number);

  /// No description provided for @roadmapStepsOpen.
  ///
  /// In en, this message translates to:
  /// **'{open} of {total} steps are yours'**
  String roadmapStepsOpen(int open, int total);

  /// No description provided for @roadmapPhaseSetup.
  ///
  /// In en, this message translates to:
  /// **'Laying the ground'**
  String get roadmapPhaseSetup;

  /// No description provided for @roadmapPhaseSetupWhen.
  ///
  /// In en, this message translates to:
  /// **'Weeks before the season'**
  String get roadmapPhaseSetupWhen;

  /// No description provided for @roadmapPhaseSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this app stands on its own: every file, every task and every urgent report is filed against a season and built out of the reference lists. This phase is set once a year, and everything after it rests on it.'**
  String get roadmapPhaseSetupBody;

  /// No description provided for @roadmapPhaseBuild.
  ///
  /// In en, this message translates to:
  /// **'Building the work'**
  String get roadmapPhaseBuild;

  /// No description provided for @roadmapPhaseBuildWhen.
  ///
  /// In en, this message translates to:
  /// **'The month before'**
  String get roadmapPhaseBuildWhen;

  /// No description provided for @roadmapPhaseBuildBody.
  ///
  /// In en, this message translates to:
  /// **'The paperwork the season will actually be worked through: which files exist, who is in them and in what role, what each person is told to do, and what the whole mission is to be told.'**
  String get roadmapPhaseBuildBody;

  /// No description provided for @roadmapPhaseRun.
  ///
  /// In en, this message translates to:
  /// **'Running the season'**
  String get roadmapPhaseRun;

  /// No description provided for @roadmapPhaseRunWhen.
  ///
  /// In en, this message translates to:
  /// **'Dhul Hijjah itself'**
  String get roadmapPhaseRunWhen;

  /// No description provided for @roadmapPhaseRunBody.
  ///
  /// In en, this message translates to:
  /// **'The only phase most of the mission ever touches, and the only one measured in hours rather than weeks. Everything in it is open to everybody, and that is its whole character: the season is not run by the people holding permissions, it is run by whoever is standing in Mina at three in the morning.'**
  String get roadmapPhaseRunBody;

  /// No description provided for @roadmapPhaseWatch.
  ///
  /// In en, this message translates to:
  /// **'Watching it happen'**
  String get roadmapPhaseWatch;

  /// No description provided for @roadmapPhaseWatchWhen.
  ///
  /// In en, this message translates to:
  /// **'Alongside the phase above'**
  String get roadmapPhaseWatchWhen;

  /// No description provided for @roadmapPhaseWatchBody.
  ///
  /// In en, this message translates to:
  /// **'The operations room\'s half of the same days. Some of it is the season seen whole while it is still moving; the rest is read back afterwards, act by act.'**
  String get roadmapPhaseWatchBody;

  /// No description provided for @roadmapPhaseClose.
  ///
  /// In en, this message translates to:
  /// **'Closing the year'**
  String get roadmapPhaseClose;

  /// No description provided for @roadmapPhaseCloseWhen.
  ///
  /// In en, this message translates to:
  /// **'The weeks after'**
  String get roadmapPhaseCloseWhen;

  /// No description provided for @roadmapPhaseCloseBody.
  ///
  /// In en, this message translates to:
  /// **'What is harvested from a season once the buses have gone home: the marks people were asked to give, the records taken out of the app, and the year put away so the next one can be opened.'**
  String get roadmapPhaseCloseBody;

  /// No description provided for @roadmapStepSeason.
  ///
  /// In en, this message translates to:
  /// **'Name the year the Administration is working through and make it the current one. Every file, task, report and check-in that follows is filed against it, which is why nothing else in this map can be done first.'**
  String get roadmapStepSeason;

  /// No description provided for @roadmapNoteSeason.
  ///
  /// In en, this message translates to:
  /// **'Only one season is current at a time. Changing it changes what every other screen in the app is showing.'**
  String get roadmapNoteSeason;

  /// No description provided for @roadmapStepReference.
  ///
  /// In en, this message translates to:
  /// **'The lists everything else is assembled from: hotels, clusters, the places of the rites, and the rest of the master data. A file names a hotel rather than describing one, so a hotel that is not on this list cannot be put in a file.'**
  String get roadmapStepReference;

  /// No description provided for @roadmapNoteReference.
  ///
  /// In en, this message translates to:
  /// **'A place only becomes scannable once it is here with a position and a radius — which is what makes attendance work at all.'**
  String get roadmapNoteReference;

  /// No description provided for @roadmapStepApprovals.
  ///
  /// In en, this message translates to:
  /// **'Nobody reaches the app before their account is approved. Registrations queue here, and each is admitted, refused, or left waiting.'**
  String get roadmapStepApprovals;

  /// No description provided for @roadmapStepEmployees.
  ///
  /// In en, this message translates to:
  /// **'Who is working this season: their details, their photographs and the numbers they are reached on. It is filled here once, and read from here by every other screen that has to contact somebody.'**
  String get roadmapStepEmployees;

  /// No description provided for @roadmapStepPermissions.
  ///
  /// In en, this message translates to:
  /// **'What each person may do. Being approved lets somebody in; this decides what they find once inside — and the sections nobody grants them stay both hidden and shut.'**
  String get roadmapStepPermissions;

  /// No description provided for @roadmapNotePermissions.
  ///
  /// In en, this message translates to:
  /// **'A permission granted now reaches the holder when their session next refreshes — a pull on any list will do it.'**
  String get roadmapNotePermissions;

  /// No description provided for @roadmapStepFiles.
  ///
  /// In en, this message translates to:
  /// **'Open the season\'s operational files, put people into them and give each a role. This is the step that turns a directory of staff into an organisation: a file reaches its members by assignment, and it is here that the assigning happens.'**
  String get roadmapStepFiles;

  /// No description provided for @roadmapNoteFiles.
  ///
  /// In en, this message translates to:
  /// **'A member sees a file because he was put in it, never because of a permission — which is why every file has to be built here before anybody can work one.'**
  String get roadmapNoteFiles;

  /// No description provided for @roadmapStepAssign.
  ///
  /// In en, this message translates to:
  /// **'Write duties onto other people\'s lists and follow them up. Separate from the files on purpose: a task is aimed at a person, not at a folder, and most of them have no file behind them at all.'**
  String get roadmapStepAssign;

  /// No description provided for @roadmapStepForms.
  ///
  /// In en, this message translates to:
  /// **'Write the evaluation papers the season will be judged with: the stages, the questions, and what each is worth. Written before anybody is asked to fill one, because the paper cannot change under a mark that has already been given.'**
  String get roadmapStepForms;

  /// No description provided for @roadmapNoteForms.
  ///
  /// In en, this message translates to:
  /// **'Writing the questions and reading the answers are two different trusts, and two different permissions.'**
  String get roadmapNoteForms;

  /// No description provided for @roadmapStepCirculars.
  ///
  /// In en, this message translates to:
  /// **'Enter and publish the decisions, timetables and notices the whole mission reads — meal times, movement orders, anything that has to reach everybody at once.'**
  String get roadmapStepCirculars;

  /// No description provided for @roadmapStepMyFiles.
  ///
  /// In en, this message translates to:
  /// **'The files you were put into, and your role in each. Whatever your rank, this shows your own work: being allowed to open every file does not make every file yours.'**
  String get roadmapStepMyFiles;

  /// No description provided for @roadmapStepMyTasks.
  ///
  /// In en, this message translates to:
  /// **'Your own list, and what was written onto it by somebody else. Mark a duty done as you go rather than at the end of the day — the follow-up screens read exactly this.'**
  String get roadmapStepMyTasks;

  /// No description provided for @roadmapNoteOffline.
  ///
  /// In en, this message translates to:
  /// **'Written with no network, it is kept on the device and sent by itself when the network returns. Do not write it twice.'**
  String get roadmapNoteOffline;

  /// No description provided for @roadmapStepCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Scan the code fixed at the place and your arrival is recorded there, with the time and the place on it. Your own record is yours to read from any device.'**
  String get roadmapStepCheckIn;

  /// No description provided for @roadmapNoteCheckIn.
  ///
  /// In en, this message translates to:
  /// **'The phone\'s own position is checked as well as the code, so an arrival cannot be filed from the other end of the street.'**
  String get roadmapNoteCheckIn;

  /// No description provided for @roadmapStepIncident.
  ///
  /// In en, this message translates to:
  /// **'Say that something has gone wrong — a coach broken down, a pilgrim lost, a hotel refusing a group — and it reaches the operations room at once. There is a red button for it on nearly every screen in the app.'**
  String get roadmapStepIncident;

  /// No description provided for @roadmapNoteIncident.
  ///
  /// In en, this message translates to:
  /// **'Deliberately open to everybody: a system in which only certain people may report a broken-down coach is a system that does not find out about the coach.'**
  String get roadmapNoteIncident;

  /// No description provided for @roadmapStepReadCirculars.
  ///
  /// In en, this message translates to:
  /// **'What the Administration has published to the whole mission this season. Read rather than written — entering one is the step above, in the other hands.'**
  String get roadmapStepReadCirculars;

  /// No description provided for @roadmapStepComplain.
  ///
  /// In en, this message translates to:
  /// **'File a complaint and read what came back on it. Complaining is not an authority somebody grants, so this is open to every approved account.'**
  String get roadmapStepComplain;

  /// No description provided for @roadmapStepDashboard.
  ///
  /// In en, this message translates to:
  /// **'The season from above: how many files are running, who is where, what is still waiting. Each part of it answers for itself, so you see the sections you hold and no others.'**
  String get roadmapStepDashboard;

  /// No description provided for @roadmapStepMap.
  ///
  /// In en, this message translates to:
  /// **'The season drawn on the ground — the hotels, the camps and the places of the rites, with what is happening at each.'**
  String get roadmapStepMap;

  /// No description provided for @roadmapStepPresence.
  ///
  /// In en, this message translates to:
  /// **'Who is present, everywhere, right now. The map says where the places are and this says who is standing in them.'**
  String get roadmapStepPresence;

  /// No description provided for @roadmapStepIncidents.
  ///
  /// In en, this message translates to:
  /// **'The register of urgent reports as they arrive. The one oversight screen in this app that is read while the thing it is about is still happening.'**
  String get roadmapStepIncidents;

  /// No description provided for @roadmapStepComplaints.
  ///
  /// In en, this message translates to:
  /// **'Every complaint filed across the mission: reply to it, dismiss it, or lock it once it is settled.'**
  String get roadmapStepComplaints;

  /// No description provided for @roadmapNoteComplaints.
  ///
  /// In en, this message translates to:
  /// **'A complaint can escalate onto a person\'s account with no human in the loop, which is why the register sits with the people rather than with the files.'**
  String get roadmapNoteComplaints;

  /// No description provided for @roadmapStepAudit.
  ///
  /// In en, this message translates to:
  /// **'The season act by act: who did what, and when. The dashboard is the season from above; this is the same season from the side.'**
  String get roadmapStepAudit;

  /// No description provided for @roadmapStepEvaluate.
  ///
  /// In en, this message translates to:
  /// **'Fill in the evaluations you were asked for. They reach you by name rather than by permission, so this list is empty for anybody who was not asked — which is the true answer, not a missing door.'**
  String get roadmapStepEvaluate;

  /// No description provided for @roadmapNoteEvaluate.
  ///
  /// In en, this message translates to:
  /// **'What was written about you is not here. It is on your own page, and it arrives with no name on it.'**
  String get roadmapNoteEvaluate;

  /// No description provided for @roadmapStepExport.
  ///
  /// In en, this message translates to:
  /// **'Take any list out of the app as a file, with the columns you choose — for a report, an archive, or anything that has to be worked on outside.'**
  String get roadmapStepExport;

  /// No description provided for @roadmapStepArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Close the year, open the next'**
  String get roadmapStepArchiveTitle;

  /// No description provided for @roadmapStepArchive.
  ///
  /// In en, this message translates to:
  /// **'Nothing is deleted at the end of a season. The year stops being the current one and becomes the archive, and a new season is opened beside it — which puts you back at the first step of this map.'**
  String get roadmapStepArchive;

  /// No description provided for @roadmapNoteArchive.
  ///
  /// In en, this message translates to:
  /// **'Everything filed against a past season stays readable exactly as it was. Closing a year hides nothing.'**
  String get roadmapNoteArchive;

  /// No description provided for @navMyJourney.
  ///
  /// In en, this message translates to:
  /// **'My journey'**
  String get navMyJourney;

  /// No description provided for @navMyJourneySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your arrival, your movements and when you fly home, from end to end.'**
  String get navMyJourneySubtitle;

  /// No description provided for @navTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel and movement'**
  String get navTravel;

  /// No description provided for @navTravelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The season\'s trips, and who is on each of them.'**
  String get navTravelSubtitle;

  /// No description provided for @perm_travel.
  ///
  /// In en, this message translates to:
  /// **'Travel and movement'**
  String get perm_travel;

  /// No description provided for @permTravelView.
  ///
  /// In en, this message translates to:
  /// **'Read a colleague\'s journey on their page'**
  String get permTravelView;

  /// No description provided for @permTravelViewAll.
  ///
  /// In en, this message translates to:
  /// **'Read every trip of the season'**
  String get permTravelViewAll;

  /// No description provided for @permTravelEdit.
  ///
  /// In en, this message translates to:
  /// **'Create trips and change their details'**
  String get permTravelEdit;

  /// No description provided for @permTravelAssign.
  ///
  /// In en, this message translates to:
  /// **'Put people on trips and move them between them'**
  String get permTravelAssign;

  /// No description provided for @permTravelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Record what actually happened — departures and arrivals'**
  String get permTravelConfirm;

  /// No description provided for @permTravelDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete a trip'**
  String get permTravelDelete;

  /// No description provided for @travelMyJourneyTitle.
  ///
  /// In en, this message translates to:
  /// **'My journey'**
  String get travelMyJourneyTitle;

  /// No description provided for @travelJourneyTitle.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get travelJourneyTitle;

  /// No description provided for @travelSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Travel and movement'**
  String get travelSectionTitle;

  /// No description provided for @travelViewFullJourney.
  ///
  /// In en, this message translates to:
  /// **'See the whole journey'**
  String get travelViewFullJourney;

  /// No description provided for @travelNoJourney.
  ///
  /// In en, this message translates to:
  /// **'No travel recorded for this season yet'**
  String get travelNoJourney;

  /// No description provided for @travelNoJourneyHint.
  ///
  /// In en, this message translates to:
  /// **'The arrival flight, the movements and the return will appear here as they are recorded.'**
  String get travelNoJourneyHint;

  /// No description provided for @travelNotInSeason.
  ///
  /// In en, this message translates to:
  /// **'This account is not among this season\'s participants'**
  String get travelNotInSeason;

  /// No description provided for @travelCurrentlyIn.
  ///
  /// In en, this message translates to:
  /// **'Now in {place}'**
  String travelCurrentlyIn(String place);

  /// No description provided for @travelCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get travelCurrentLocation;

  /// No description provided for @travelDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String travelDays(int count);

  /// No description provided for @travelDaysSoFar.
  ///
  /// In en, this message translates to:
  /// **'{count} days so far'**
  String travelDaysSoFar(int count);

  /// No description provided for @travelSince.
  ///
  /// In en, this message translates to:
  /// **'since {date}'**
  String travelSince(String date);

  /// No description provided for @travelStayPlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Where he is staying'**
  String get travelStayPlaceTitle;

  /// No description provided for @travelStayHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get travelStayHome;

  /// No description provided for @travelStayResidence.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get travelStayResidence;

  /// No description provided for @travelStayRites.
  ///
  /// In en, this message translates to:
  /// **'The rites'**
  String get travelStayRites;

  /// No description provided for @travelHereNow.
  ///
  /// In en, this message translates to:
  /// **'Here now'**
  String get travelHereNow;

  /// No description provided for @travelSeasonBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Where the season went'**
  String get travelSeasonBreakdown;

  /// No description provided for @travelSeasonBreakdownHint.
  ///
  /// In en, this message translates to:
  /// **'Days based in each city'**
  String get travelSeasonBreakdownHint;

  /// No description provided for @travelNotDepartedYet.
  ///
  /// In en, this message translates to:
  /// **'The journey has not begun'**
  String get travelNotDepartedYet;

  /// No description provided for @travelJourneyComplete.
  ///
  /// In en, this message translates to:
  /// **'The journey is over'**
  String get travelJourneyComplete;

  /// No description provided for @travelDayOf.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of the journey'**
  String travelDayOf(int day);

  /// No description provided for @travelSinceDays.
  ///
  /// In en, this message translates to:
  /// **'for {days} days'**
  String travelSinceDays(int days);

  /// No description provided for @travelReturnIn.
  ///
  /// In en, this message translates to:
  /// **'Home in {days} days'**
  String travelReturnIn(int days);

  /// No description provided for @travelReturnTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Flies home tomorrow'**
  String get travelReturnTomorrow;

  /// No description provided for @travelReturnToday.
  ///
  /// In en, this message translates to:
  /// **'Flies home today'**
  String get travelReturnToday;

  /// No description provided for @travelReturnPassed.
  ///
  /// In en, this message translates to:
  /// **'The return date has passed'**
  String get travelReturnPassed;

  /// No description provided for @travelNoReturnYet.
  ///
  /// In en, this message translates to:
  /// **'No return flight set yet'**
  String get travelNoReturnYet;

  /// No description provided for @travelNoReturnYetHint.
  ///
  /// In en, this message translates to:
  /// **'A return is usually booked only a few days beforehand.'**
  String get travelNoReturnYetHint;

  /// No description provided for @travelBetween.
  ///
  /// In en, this message translates to:
  /// **'From {from} to {to}'**
  String travelBetween(String from, String to);

  /// No description provided for @travelUntrackedTransferOptional.
  ///
  /// In en, this message translates to:
  /// **'No means of travel recorded — optional'**
  String get travelUntrackedTransferOptional;

  /// No description provided for @travelRecordTransferShort.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get travelRecordTransferShort;

  /// No description provided for @travelUntrackedTransfer.
  ///
  /// In en, this message translates to:
  /// **'No means of travel recorded'**
  String get travelUntrackedTransfer;

  /// No description provided for @travelRecordTransfer.
  ///
  /// In en, this message translates to:
  /// **'Record how he travelled'**
  String get travelRecordTransfer;

  /// No description provided for @travelSelfArranged.
  ///
  /// In en, this message translates to:
  /// **'Self-arranged'**
  String get travelSelfArranged;

  /// No description provided for @travelConfirmArrival.
  ///
  /// In en, this message translates to:
  /// **'Confirm arrival'**
  String get travelConfirmArrival;

  /// No description provided for @travelConfirmedBy.
  ///
  /// In en, this message translates to:
  /// **'Confirmed by {name}'**
  String travelConfirmedBy(String name);

  /// No description provided for @travelNeedsYourWord.
  ///
  /// In en, this message translates to:
  /// **'Nothing else can confirm this one — it is yours to record'**
  String get travelNeedsYourWord;

  /// No description provided for @travelPlannedAt.
  ///
  /// In en, this message translates to:
  /// **'Planned {time}'**
  String travelPlannedAt(String time);

  /// No description provided for @travelActualAt.
  ///
  /// In en, this message translates to:
  /// **'Actual {time}'**
  String travelActualAt(String time);

  /// No description provided for @travelDepartedAt.
  ///
  /// In en, this message translates to:
  /// **'Left {time}'**
  String travelDepartedAt(String time);

  /// No description provided for @travelArrivedAt.
  ///
  /// In en, this message translates to:
  /// **'Arrived {time}'**
  String travelArrivedAt(String time);

  /// No description provided for @travelRoleInbound.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get travelRoleInbound;

  /// No description provided for @travelRoleInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal movement'**
  String get travelRoleInternal;

  /// No description provided for @travelRoleOutbound.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get travelRoleOutbound;

  /// No description provided for @travelModeAir.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get travelModeAir;

  /// No description provided for @travelModeRail.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get travelModeRail;

  /// No description provided for @travelModeRoad.
  ///
  /// In en, this message translates to:
  /// **'By road'**
  String get travelModeRoad;

  /// No description provided for @travelModeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get travelModeOther;

  /// No description provided for @travelLegPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get travelLegPlanned;

  /// No description provided for @travelLegConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get travelLegConfirmed;

  /// No description provided for @travelLegCompleted.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get travelLegCompleted;

  /// No description provided for @travelLegMissed.
  ///
  /// In en, this message translates to:
  /// **'Did not travel'**
  String get travelLegMissed;

  /// No description provided for @travelLegCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get travelLegCancelled;

  /// No description provided for @travelLegRebooked.
  ///
  /// In en, this message translates to:
  /// **'Moved to another'**
  String get travelLegRebooked;

  /// No description provided for @travelTripState.
  ///
  /// In en, this message translates to:
  /// **'Trip status'**
  String get travelTripState;

  /// No description provided for @travelTripScheduled.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get travelTripScheduled;

  /// No description provided for @travelTripDelayed.
  ///
  /// In en, this message translates to:
  /// **'Delayed'**
  String get travelTripDelayed;

  /// No description provided for @travelTripDeparted.
  ///
  /// In en, this message translates to:
  /// **'Departed'**
  String get travelTripDeparted;

  /// No description provided for @travelTripArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get travelTripArrived;

  /// No description provided for @travelTripCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get travelTripCancelled;

  /// No description provided for @travelTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'Season trips'**
  String get travelTripsTitle;

  /// No description provided for @travelNewTrip.
  ///
  /// In en, this message translates to:
  /// **'New trip'**
  String get travelNewTrip;

  /// No description provided for @travelEditTrip.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get travelEditTrip;

  /// No description provided for @travelTripDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get travelTripDetailTitle;

  /// No description provided for @travelNoTrips.
  ///
  /// In en, this message translates to:
  /// **'No trips in this season yet'**
  String get travelNoTrips;

  /// No description provided for @travelNoTripsHint.
  ///
  /// In en, this message translates to:
  /// **'Create a trip, then assign people to it in one go.'**
  String get travelNoTripsHint;

  /// No description provided for @travelNoTripsInRole.
  ///
  /// In en, this message translates to:
  /// **'No trips in this part yet'**
  String get travelNoTripsInRole;

  /// No description provided for @travelNoTripsMatch.
  ///
  /// In en, this message translates to:
  /// **'No trip matches the search'**
  String get travelNoTripsMatch;

  /// No description provided for @travelAssignedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} assigned'**
  String travelAssignedCount(int count);

  /// No description provided for @travelConfirmedOf.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} confirmed'**
  String travelConfirmedOf(int done, int total);

  /// No description provided for @travelAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign people'**
  String get travelAssign;

  /// No description provided for @travelPassengers.
  ///
  /// In en, this message translates to:
  /// **'Passengers'**
  String get travelPassengers;

  /// No description provided for @travelNoPassengers.
  ///
  /// In en, this message translates to:
  /// **'Nobody is on this trip yet'**
  String get travelNoPassengers;

  /// No description provided for @travelAssignOutcome.
  ///
  /// In en, this message translates to:
  /// **'{assigned} assigned, {rebooked} moved, {skipped} left alone'**
  String travelAssignOutcome(int assigned, int rebooked, int skipped);

  /// No description provided for @travelAssignNotInSeason.
  ///
  /// In en, this message translates to:
  /// **'and {count} are not participants this season'**
  String travelAssignNotInSeason(int count);

  /// No description provided for @travelConfirmAll.
  ///
  /// In en, this message translates to:
  /// **'Confirm everybody arrived'**
  String get travelConfirmAll;

  /// No description provided for @travelConfirmAllPrompt.
  ///
  /// In en, this message translates to:
  /// **'Mark all {count} assigned as arrived? This records what happened; it never happens on its own.'**
  String travelConfirmAllPrompt(int count);

  /// No description provided for @travelRemoveFromTrip.
  ///
  /// In en, this message translates to:
  /// **'Take off this trip'**
  String get travelRemoveFromTrip;

  /// No description provided for @travelRemoveFromTripConfirm.
  ///
  /// In en, this message translates to:
  /// **'Take {name} off this trip? The movement is kept in the record, not deleted.'**
  String travelRemoveFromTripConfirm(String name);

  /// No description provided for @travelCancelTrip.
  ///
  /// In en, this message translates to:
  /// **'Cancel the trip'**
  String get travelCancelTrip;

  /// No description provided for @travelDeleteTrip.
  ///
  /// In en, this message translates to:
  /// **'Delete the trip'**
  String get travelDeleteTrip;

  /// No description provided for @travelDeleteTripConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this trip for good? A trip with passengers cannot be deleted — cancel it instead.'**
  String get travelDeleteTripConfirm;

  /// No description provided for @travelFieldMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get travelFieldMode;

  /// No description provided for @travelFieldRole.
  ///
  /// In en, this message translates to:
  /// **'Kind of movement'**
  String get travelFieldRole;

  /// No description provided for @travelFieldFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get travelFieldFrom;

  /// No description provided for @travelFieldTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get travelFieldTo;

  /// No description provided for @travelFieldNumber.
  ///
  /// In en, this message translates to:
  /// **'Trip number'**
  String get travelFieldNumber;

  /// No description provided for @travelFieldDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departs'**
  String get travelFieldDeparture;

  /// No description provided for @travelFieldArrival.
  ///
  /// In en, this message translates to:
  /// **'Arrives'**
  String get travelFieldArrival;

  /// No description provided for @travelFieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get travelFieldNote;

  /// No description provided for @travelFieldTicket.
  ///
  /// In en, this message translates to:
  /// **'Ticket number'**
  String get travelFieldTicket;

  /// No description provided for @travelFieldSeat.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get travelFieldSeat;

  /// No description provided for @travelFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get travelFieldRequired;

  /// No description provided for @travelPickDateTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a date and time'**
  String get travelPickDateTime;

  /// No description provided for @travelSameEndpoints.
  ///
  /// In en, this message translates to:
  /// **'The start and the destination cannot be the same'**
  String get travelSameEndpoints;

  /// No description provided for @travelMustStartWhereHeIs.
  ///
  /// In en, this message translates to:
  /// **'A movement starts where the one before it left him'**
  String get travelMustStartWhereHeIs;

  /// No description provided for @travelGapsTitle.
  ///
  /// In en, this message translates to:
  /// **'What is unanswered'**
  String get travelGapsTitle;

  /// No description provided for @travelGapsClear.
  ///
  /// In en, this message translates to:
  /// **'Nothing outstanding'**
  String get travelGapsClear;

  /// No description provided for @travelGapsClearHint.
  ///
  /// In en, this message translates to:
  /// **'No participant without a flight, and no movement past its hour without a word.'**
  String get travelGapsClearHint;

  /// No description provided for @travelGapNoInbound.
  ///
  /// In en, this message translates to:
  /// **'No arrival flight'**
  String get travelGapNoInbound;

  /// No description provided for @travelGapNoOutbound.
  ///
  /// In en, this message translates to:
  /// **'No return flight'**
  String get travelGapNoOutbound;

  /// No description provided for @travelGapUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Past its hour, unconfirmed'**
  String get travelGapUnconfirmed;

  /// No description provided for @travelGapCancelledTrip.
  ///
  /// In en, this message translates to:
  /// **'On a cancelled trip'**
  String get travelGapCancelledTrip;

  /// No description provided for @travelMarkDoesNotTravel.
  ///
  /// In en, this message translates to:
  /// **'Does not travel this season'**
  String get travelMarkDoesNotTravel;

  /// No description provided for @travelMarkDoesNotTravelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Mark {name} as not travelling this season? They come off this list, and movements may still be recorded for them.'**
  String travelMarkDoesNotTravelConfirm(String name);

  /// No description provided for @travelRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record a movement'**
  String get travelRecordTitle;

  /// No description provided for @travelRecordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For movements arranged privately — a car, or anything else.'**
  String get travelRecordSubtitle;

  /// No description provided for @travelRecordAlreadyHappened.
  ///
  /// In en, this message translates to:
  /// **'It has already happened'**
  String get travelRecordAlreadyHappened;

  /// No description provided for @travelRecordSaved.
  ///
  /// In en, this message translates to:
  /// **'Movement recorded'**
  String get travelRecordSaved;

  /// No description provided for @travelAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get travelAttachments;

  /// No description provided for @travelNoAttachments.
  ///
  /// In en, this message translates to:
  /// **'No attachments'**
  String get travelNoAttachments;

  /// No description provided for @travelNoAttachmentsHint.
  ///
  /// In en, this message translates to:
  /// **'Attach a ticket, a manifest or a photograph — PDF or image.'**
  String get travelNoAttachmentsHint;

  /// No description provided for @travelAddAttachment.
  ///
  /// In en, this message translates to:
  /// **'Add an attachment'**
  String get travelAddAttachment;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
