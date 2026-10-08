import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/audit_event.dart';
import '../../domain/audit_labels.dart';

/// How each kind of act looks and reads — shared between the list card and
/// the details sheet so the two cannot drift apart.

IconData auditActionIcon(AuditAction action) => switch (action) {
  AuditAction.insert => AppIcons.add,
  AuditAction.update => AppIcons.edit,
  AuditAction.delete => AppIcons.delete,
  AuditAction.login => AppIcons.login,
  AuditAction.logout => AppIcons.logout,
};

Color auditActionColor(BuildContext context, AuditAction action) {
  final scheme = Theme.of(context).colorScheme;
  return switch (action) {
    AuditAction.insert => scheme.primary,
    AuditAction.update => scheme.secondary,
    AuditAction.delete => scheme.error,
    AuditAction.login => scheme.primary,
    AuditAction.logout => scheme.onSurfaceVariant,
  };
}

String auditActionLabel(BuildContext context, AuditAction action) {
  final l = context.l10n;
  return switch (action) {
    AuditAction.insert => l.auditActionInsert,
    AuditAction.update => l.auditActionUpdate,
    AuditAction.delete => l.auditActionDelete,
    AuditAction.login => l.auditActionLogin,
    AuditAction.logout => l.auditActionLogout,
  };
}

/// The verb of the line: an account act (created / password reset / …) when
/// there is one, the plain action otherwise.
String auditVerb(BuildContext context, AuditEvent e) =>
    AuditLabels.authOp(e.authOp)?.of(context) ??
    auditActionLabel(context, e.action);

/// The headline: what the event was about, or — for a bare sign-in — what it
/// was.
String auditTitle(BuildContext context, AuditEvent e) =>
    e.recordLabel ?? auditVerb(context, e);

/// The line under the headline: the verb (unless the headline already IS the
/// verb), where it happened, and how far it reached.
String auditSubtitle(BuildContext context, AuditEvent e) {
  final verb = auditVerb(context, e);
  final parts = [
    if (auditTitle(context, e) != verb) verb,
    AuditLabels.table(e.tableName).of(context),
    if (e.recipients != null) context.l10n.auditRecipients(e.recipients!),
  ];
  return parts.join(' • ');
}

String auditFmtTime(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}';
}

final _uuidRe = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final _isoRe = RegExp(r'^\d{4}-\d{2}-\d{2}');

/// A stored value, made readable: booleans speak, timestamps land in local
/// time, ids shrink to a stub, structures collapse to short JSON. The log
/// shows what the database holds — it does not re-resolve foreign keys, and a
/// stubbed id says "a reference changed" honestly.
String auditFmtValue(BuildContext context, dynamic v) {
  final l = context.l10n;
  if (v == null) return '—';
  if (v is bool) return v ? l.auditYes : l.auditNo;
  if (v is num) return v.toString();
  if (v is Map || v is List) {
    final s = jsonEncode(v);
    return s.length > 300 ? '${s.substring(0, 300)}…' : s;
  }
  final s = v.toString();
  if (s.isEmpty) return '—';
  if (_uuidRe.hasMatch(s)) return '${s.substring(0, 8)}…';
  if (_isoRe.hasMatch(s)) {
    if (s.length == 10) return s; // a plain date stays a date
    final ts = DateTime.tryParse(s);
    if (ts != null) return auditFmtTime(ts.toLocal());
  }
  return s;
}
