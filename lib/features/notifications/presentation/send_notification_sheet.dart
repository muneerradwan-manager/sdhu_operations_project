import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/attachments/attachment_picker.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../auth/application/session_cubit.dart';
import '../../modules/data/modules_repository.dart';
import '../../modules/domain/operational_module.dart';
import '../../seasons/data/seasons_repository.dart';
import '../data/notifications_repository.dart';

/// Who a notification is going to.
enum SendAudience { person, module, all }

/// Compose + send a notification.
///
/// With [recipientId] it goes to that one person; with [moduleId] it goes to
/// everyone holding a role in that file. Given neither, the sheet asks who to
/// send to — everyone, or the members of one operational file.
///
/// Opened FROM a file or FROM a person, the audience is already settled by the
/// page the reader is standing on, so the sheet does not ask again.
Future<void> showSendNotificationSheet(
  BuildContext context, {
  String? recipientId,
  String? moduleId,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) =>
        _Form(recipientId: recipientId, moduleId: moduleId),
  );
}

class _Form extends StatefulWidget {
  const _Form({required this.recipientId, required this.moduleId});
  final String? recipientId;
  final String? moduleId;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _repo = NotificationsRepository();
  final _attachments = <PendingAttachment>[];
  bool _busy = false;

  late SendAudience _audience = switch ((widget.recipientId, widget.moduleId)) {
    (final String _, _) => SendAudience.person,
    (_, final String _) => SendAudience.module,
    _ => SendAudience.all,
  };

  /// The season's files, to choose one from. Loaded once when the sheet opens.
  Future<List<OperationalModule>>? _modules;
  late String? _moduleId = widget.moduleId;

  /// Whether the reader still has to be asked. Arriving from a person's page or
  /// a file's page, they do not — the question was answered by getting here.
  bool get _asksAudience =>
      widget.recipientId == null && widget.moduleId == null;

  /// The audiences this sender's permissions actually reach. Each blast radius
  /// is its own permission, so the dropdown offers only what would not be
  /// refused by the server.
  late final List<SendAudience> _allowed;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionCubit>().state;
    _allowed = [
      if (session.can(PermissionCodes.notificationsBroadcastAll))
        SendAudience.all,
      if (session.can(PermissionCodes.notificationsBroadcastModule))
        SendAudience.module,
    ];
    if (_asksAudience) {
      if (!_allowed.contains(_audience) && _allowed.isNotEmpty) {
        _audience = _allowed.first;
      }
      _modules = _loadModules();
    }
  }

  Future<List<OperationalModule>> _loadModules() async {
    final season = await SeasonsRepository().fetchCurrentSeason();
    if (season == null) return const [];
    return ModulesRepository().fetchModules(seasonId: season.id);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    final picked = await pickAttachment(context);
    // The sheet can be dismissed while the picker is up.
    if (!mounted) return;
    if (picked != null) setState(() => _attachments.add(picked));
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final title = _title.text.trim();
      final body = _body.text.trim().isEmpty ? null : _body.text.trim();

      switch (_audience) {
        case SendAudience.person:
          await _repo.send(
            recipientId: widget.recipientId!,
            title: title,
            body: body,
            attachments: _attachments,
          );
        case SendAudience.module:
          if (_moduleId == null) {
            setState(() => _busy = false);
            return;
          }
          await _repo.broadcastToModule(
            moduleId: _moduleId!,
            title: title,
            body: body,
            attachments: _attachments,
          );
        case SendAudience.all:
          await _repo.broadcastToAll(
            title: title,
            body: body,
            attachments: _attachments,
          );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.notificationSent)));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Form(
        key: _formKey,
        // Scrollable, because the sheet has to fit above the keyboard: with
        // two attachments on it and the audience field showing, it does not.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.notificationSend,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_asksAudience) ...[
                _AudienceField(
                  audience: _audience,
                  allowed: _allowed,
                  onChanged: (v) => setState(() => _audience = v),
                ),
                if (_audience == SendAudience.module) ...[
                  const SizedBox(height: 12),
                  FutureBuilder<List<OperationalModule>>(
                    future: _modules,
                    builder: (context, snapshot) {
                      final modules =
                          snapshot.data ?? const <OperationalModule>[];
                      return DropdownButtonFormField<String>(
                        initialValue: _moduleId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l.notificationChooseModule,
                          prefixIcon: const Icon(AppIcons.modules),
                          helperText: l.notificationBroadcastHint,
                        ),
                        items: [
                          for (final m in modules)
                            DropdownMenuItem(
                              value: m.id,
                              child: Text(
                                m.moduleTypeName?.of(context) ?? '—',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        validator: (v) => v == null ? l.commonRequired : null,
                        onChanged: (v) => setState(() => _moduleId = v),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: l.notificationTitleField,
                  prefixIcon: const Icon(AppIcons.notifications),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l.commonRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _body,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l.notificationBodyField,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _busy ? null : _attach,
                  icon: const Icon(AppIcons.attach, size: 18),
                  label: Text(l.notificationAttach),
                ),
              ),
              for (var i = 0; i < _attachments.length; i++)
                PendingAttachmentRow(
                  attachment: _attachments[i],
                  onRemove: _busy
                      ? null
                      : () => setState(() => _attachments.removeAt(i)),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(AppIcons.send),
                label: Text(l.notificationSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everyone, or the members of one file. A person is not offered here — that
/// send starts from their page, where you already know who you mean.
class _AudienceField extends StatelessWidget {
  const _AudienceField({
    required this.audience,
    required this.allowed,
    required this.onChanged,
  });

  final SendAudience audience;
  final List<SendAudience> allowed;
  final ValueChanged<SendAudience> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return DropdownButtonFormField<SendAudience>(
      initialValue: audience,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l.notificationAudience,
        prefixIcon: const Icon(AppIcons.participants),
      ),
      items: [
        if (allowed.contains(SendAudience.all))
          DropdownMenuItem(
            value: SendAudience.all,
            child: Text(l.notificationAudienceAll),
          ),
        if (allowed.contains(SendAudience.module))
          DropdownMenuItem(
            value: SendAudience.module,
            child: Text(l.notificationAudienceModule),
          ),
      ],
      onChanged: (v) => onChanged(v ?? audience),
    );
  }
}
