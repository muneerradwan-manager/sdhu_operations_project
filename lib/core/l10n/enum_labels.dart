import '../../features/profile/domain/profile_enums.dart';
import '../../l10n/app_localizations.dart';

/// Locale-aware labels for domain enums.
extension GenderL10n on Gender {
  String label(AppLocalizations l) =>
      this == Gender.male ? l.genderMale : l.genderFemale;
}
