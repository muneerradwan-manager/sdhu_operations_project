import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/complaint.dart';

/// The names and glyphs the seven kinds are shown by.
///
/// Here rather than in the enum: what a complaint is filed against is a fact
/// about the database, and what it is CALLED is a fact about the reader's
/// language. The domain does not import the ARB files.
String complaintTargetLabel(AppLocalizations l, ComplaintTarget target) =>
    switch (target) {
      ComplaintTarget.employee => l.complaintTargetEmployee,
      ComplaintTarget.module => l.complaintTargetModule,
      ComplaintTarget.report => l.complaintTargetReport,
      ComplaintTarget.hotel => l.complaintTargetHotel,
      ComplaintTarget.cluster => l.complaintTargetCluster,
      ComplaintTarget.group => l.complaintTargetGroup,
      ComplaintTarget.other => l.complaintTargetOther,
    };

/// Each kind wears the glyph its own section already wears, so a complaint
/// about a hotel is recognisable from the same shape the master data uses.
IconData complaintTargetIcon(ComplaintTarget target) => switch (target) {
  ComplaintTarget.employee => AppIcons.employees,
  ComplaintTarget.module => AppIcons.modules,
  ComplaintTarget.report => AppIcons.reports,
  ComplaintTarget.hotel => AppIcons.referenceData,
  ComplaintTarget.cluster => AppIcons.referenceData,
  ComplaintTarget.group => AppIcons.participants,
  ComplaintTarget.other => AppIcons.complaints,
};

/// What a bubble's writer was to this complaint, for the anonymous ones that
/// have no name to show.
String complaintRoleLabel(AppLocalizations l, ComplaintRole role) =>
    switch (role) {
      ComplaintRole.complainant => l.complaintRoleComplainant,
      ComplaintRole.accused => l.complaintRoleAccused,
      ComplaintRole.manager => l.complaintRoleManager,
    };
