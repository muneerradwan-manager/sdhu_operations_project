import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/attachments/attachment_picker.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_cubit.dart';
import '../../home/domain/home_destinations.dart';
import '../../modules/data/modules_repository.dart';
import '../../modules/presentation/employee_picker_screen.dart';
import '../../modules/presentation/widgets/picker_sheet.dart';
import '../../seasons/data/seasons_repository.dart';
import '../application/incidents_cubit.dart';
import '../domain/incident.dart';

/// What an urgent report is about, when the reporter says.
///
/// One object for three kinds rather than three nullable fields on the screen's
/// state, because they are one CHOICE: a report is about a file, or about a
/// person, or about a screen, and never about two of them. Three fields would
/// make "a file and also a person" representable, and something would
/// eventually represent it.
///
/// The label is carried rather than looked up. For the app-page kind it is the
/// only readable form the record will ever have — the database cannot turn
/// `/employees` into a heading in two languages (see 0120) — and for the other
/// two it saves this screen a second fetch to draw what the reader just picked.
class _IncidentTarget {
  const _IncidentTarget({
    required this.label,
    this.moduleId,
    this.nodeId,
    this.subjectProfileId,
    this.appRoute,
  });

  final String label;
  final String? moduleId;
  final String? nodeId;
  final String? subjectProfileId;
  final String? appRoute;

  /// The words the reporter saw, sent only for the kind that has nothing else.
  String? get appLabel => appRoute == null ? null : label;

  /// What to draw on the chip while the name is still being fetched — the KIND
  /// of thing, which is true from the first frame and never wrong.
  String labelOr(AppLocalizations l) =>
      label.isNotEmpty ? label : l.incidentAboutModule;

  IconData get icon {
    if (subjectProfileId != null) return AppIcons.employees;
    if (appRoute != null) return AppIcons.layoutSidebar;
    return AppIcons.modules;
  }
}

/// Which of the three kinds the chooser is offering.
enum _TargetKind { module, employee, page, none }

/// Reporting something that cannot wait.
///
/// Almost nothing on this screen, and the emptiness is the design. There is no
/// category to choose, no severity to rate, nothing marked required but the one
/// line of text. Every field added here is a second added between a man
/// deciding to report and the report arriving, and at some number of seconds he
/// stops and telephones somebody instead — which is the outcome this screen
/// exists to prevent.
///
/// Where he is, who he is and which file he came from are attached by the app
/// without asking. A photograph is offered and never required: it uploads AFTER
/// the alarm has already gone (see IncidentsRepository.raise), so it can never
/// delay the thing that matters.
///
/// ## The one thing that was added, and why it is not a field
///
/// A report may now say what it is ABOUT — a file, a person, or a screen in the
/// app (0120). It is offered the way the photograph is offered: one quiet row
/// below the text, nothing pre-selected, nothing validated, and the send button
/// enabled the whole time whether or not it has been touched. A man who types a
/// line and presses send sends exactly what he sent before.
///
/// It earns the row because of what the operations room does next. "The driver
/// of coach 4 has not turned up" names somebody who has to be telephoned, and a
/// name inside prose cannot be telephoned from the register; "the roster screen
/// is showing yesterday's list" is not an emergency at all, and until there was
/// somewhere to say so it arrived looking exactly like one.
class RaiseIncidentScreen extends StatefulWidget {
  const RaiseIncidentScreen({super.key, this.moduleId, this.nodeId});

  final String? moduleId;
  final String? nodeId;

  @override
  State<RaiseIncidentScreen> createState() => _RaiseIncidentScreenState();
}

class _RaiseIncidentScreenState extends State<RaiseIncidentScreen> {
  final _body = TextEditingController();
  final _added = <PendingAttachment>[];
  bool _busy = false;

  /// What the report is about. Null is the normal state and stays the default.
  _IncidentTarget? _target;

  /// The current season, fetched once and only when something needs it.
  ///
  /// Not fetched on open: both pickers that want it are behind a tap that most
  /// reports never make, and a request fired on `initState` would be a request
  /// this screen makes every single time somebody reports a fire.
  String? _seasonId;

  bool _picking = false;

  @override
  void initState() {
    super.initState();
    // A report raised from inside a file arrives already pointed at it. Named
    // rather than attached silently, which is what it used to be: a chip the
    // reporter can see is a chip he can correct, and a file attached without
    // being shown is a claim the record makes on his behalf.
    //
    // The label is left empty rather than filled with a localised placeholder:
    // `Localizations.of` registers a dependency and may not be read here, and
    // the chip has a translated fallback for exactly this gap — see
    // [_IncidentTarget.labelOr]. [_nameTheFile] replaces it a moment later with
    // the file's own name.
    if (widget.moduleId case final id?) {
      _target = _IncidentTarget(
        label: '',
        moduleId: id,
        nodeId: widget.nodeId,
      );
      _nameTheFile(id);
    }
  }

  /// Puts the file's own name on the chip the route handed us an id for.
  ///
  /// Fire-and-forget on purpose. It is cosmetic — the id is already on the
  /// pending report and the chip already says what KIND of thing it is — so a
  /// failure here must not be reported, retried, or allowed to block a send.
  Future<void> _nameTheFile(String id) async {
    try {
      final module = await ModulesRepository().fetchModule(id);
      if (!mounted) return;
      final name = module?.moduleTypeName?.of(context);
      if (name == null || name.isEmpty) return;
      // Only if he has not since chosen something else himself.
      if (_target?.moduleId != id) return;
      setState(() {
        _target = _IncidentTarget(
          label: name,
          moduleId: id,
          nodeId: widget.nodeId,
        );
      });
    } catch (_) {
      // Deliberately silent — see above.
    }
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    final picked = await pickAttachment(context);
    if (picked != null) setState(() => _added.add(picked));
  }

  /// The season both people-pickers stand on, fetched at most once.
  ///
  /// Returns null when there is none, and the caller says so rather than
  /// opening an empty list: "no current season" is a thing an administrator has
  /// to fix, not a thing this reader can pick his way out of.
  Future<String?> _season() async {
    if (_seasonId != null) return _seasonId;
    final season = await SeasonsRepository().fetchCurrentSeason();
    _seasonId = season?.id;
    return _seasonId;
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Two taps, and the first one is what keeps this off the critical path.
  ///
  /// The kind is asked first — file, person, screen — so that nothing is
  /// fetched until the reader has said which list he wants. Asking with one
  /// long list instead would mean loading the season, its files and its staff
  /// before he had told anybody he wanted any of them.
  Future<void> _chooseTarget() async {
    final l = context.l10n;
    final chosen = await showPickerSheet(
      context,
      title: l.incidentAboutKind,
      selected: const {},
      options: [
        PickerOption(id: _TargetKind.module.name, label: l.incidentAboutModule),
        PickerOption(
          id: _TargetKind.employee.name,
          label: l.incidentAboutEmployee,
        ),
        PickerOption(id: _TargetKind.page.name, label: l.incidentAboutPage),
        if (_target != null)
          PickerOption(id: _TargetKind.none.name, label: l.incidentAboutClear),
      ],
    );
    if (!mounted || chosen == null || chosen.isEmpty) return;

    switch (chosen.first) {
      case 'module':
        await _chooseModule();
      case 'employee':
        await _chooseEmployee();
      case 'page':
        await _choosePage();
      case _:
        setState(() => _target = null);
    }
  }

  Future<void> _chooseModule() async {
    final l = context.l10n;
    setState(() => _picking = true);
    try {
      final seasonId = await _season();
      if (!mounted) return;
      if (seasonId == null) return _say(l.incidentAboutNoSeason);

      final modules = await ModulesRepository().fetchModules(
        seasonId: seasonId,
      );
      if (!mounted) return;

      final names = {
        for (final module in modules)
          module.id: module.moduleTypeName?.of(context) ?? module.id,
      };
      final chosen = await showPickerSheet(
        context,
        title: l.incidentAboutModule,
        selected: {?_target?.moduleId},
        emptyMessage: l.incidentAboutNoModules,
        options: [
          for (final module in modules)
            PickerOption(id: module.id, label: names[module.id]!),
        ],
      );
      if (!mounted || chosen == null || chosen.isEmpty) return;

      final id = chosen.first;
      setState(
        () => _target = _IncidentTarget(label: names[id] ?? id, moduleId: id),
      );
    } catch (e) {
      if (mounted) _say(friendlyError(context, e.toString()));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _chooseEmployee() async {
    final l = context.l10n;
    setState(() => _picking = true);
    try {
      final seasonId = await _season();
      if (!mounted) return;
      if (seasonId == null) return _say(l.incidentAboutNoSeason);

      final person = await showSingleEmployeePicker(
        context,
        title: l.incidentAboutEmployee,
        seasonId: seasonId,
        selected: _target?.subjectProfileId,
      );
      if (!mounted || person == null) return;

      setState(() {
        _target = _IncidentTarget(
          label: person.profile.fullName,
          subjectProfileId: person.profile.id,
        );
      });
    } catch (e) {
      if (mounted) _say(friendlyError(context, e.toString()));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// The screens this reader may actually open, read off the same catalogue the
  /// home page and the rail are built from.
  ///
  /// Nothing is fetched and nothing can be stale: a door hidden from him by
  /// permission is not on this list either, so he cannot file a report against
  /// a screen the register would then invite somebody to open on his behalf.
  Future<void> _choosePage() async {
    final l = context.l10n;
    final session = context.read<SessionCubit>().state;
    final shelves = homeShelves(homeDestinations(session, l));

    final chosen = await showPickerSheet(
      context,
      title: l.incidentAboutPage,
      selected: {?_target?.appRoute},
      options: [
        for (final shelf in shelves)
          for (final destination in shelf.destinations)
            PickerOption(
              id: destination.route,
              label: destination.title,
              subtitle: destination.subtitle,
              group: shelf.group.title(l),
            ),
      ],
    );
    if (!mounted || chosen == null || chosen.isEmpty) return;

    final route = chosen.first;
    final destination = [
      for (final shelf in shelves) ...shelf.destinations,
    ].where((d) => d.route == route).firstOrNull;
    if (destination == null) return;

    setState(() {
      _target = _IncidentTarget(label: destination.title, appRoute: route);
    });
  }

  Future<void> _send() async {
    final body = _body.text.trim();
    if (body.isEmpty) return;

    setState(() => _busy = true);
    final target = _target;
    final outcome = await RaiseIncident.send(
      PendingIncident(
        body: body,
        moduleId: target?.moduleId,
        nodeId: target?.nodeId,
        subjectProfileId: target?.subjectProfileId,
        appRoute: target?.appRoute,
        appLabel: target?.appLabel,
        attachments: _added,
      ),
    );
    if (!mounted) return;

    switch (outcome) {
      case IncidentOutcome.sent:
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.l10n.incidentSent)));
      case IncidentOutcome.waitingForNetwork:
        // A dialog, not a snack bar, and it does not close the screen. This is
        // the one message in the app that must be READ: his report is kept but
        // NOBODY HAS BEEN TOLD, and a line that slides away in four seconds
        // would leave him believing help is coming.
        setState(() => _busy = false);
        await _sayNobodyWasTold();
      case IncidentOutcome.failed:
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(friendlyError(context, null))),
          );
    }
  }

  Future<void> _sayNobodyWasTold() async {
    final l = context.l10n;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          AppIcons.warning,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: Text(l.incidentNotDeliveredTitle),
        content: Text(l.incidentNotDeliveredBody),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).pop(true);
            },
            child: Text(l.commonOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.incidentTitle),
        backgroundColor: scheme.errorContainer,
        foregroundColor: scheme.onErrorContainer,
      ),
      // A form, so it stops narrower than a reading column would: an emergency
      // typed into a text box a metre wide is harder to write, not easier.
      // The bottom padding comes from `scrollPadding`, which clears the
      // Android 15 gesture bar that the send button would otherwise sit under.
      body: ResponsivePage(
        width: PageWidth.form,
        builder: (context, size) => SinglePaneLayout(
          gutter: size.gutter,
          keyboardDismiss: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Text(l.incidentHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _body,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: l.incidentBodyHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            // The two optional things, on one row, at the same weight as each
            // other. Neither is a field: the send button below is enabled
            // whether or not either has been touched, and both are phrased as
            // offers rather than as prompts.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_target case final target?)
                  InputChip(
                    avatar: Icon(target.icon, size: 16),
                    label: Text(target.labelOr(l)),
                    onPressed: _picking ? null : _chooseTarget,
                    onDeleted: _picking
                        ? null
                        : () => setState(() => _target = null),
                  )
                else
                  TextButton.icon(
                    onPressed: _picking ? null : _chooseTarget,
                    icon: _picking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.link, size: 18),
                    label: Text(l.incidentAbout),
                  ),
                TextButton.icon(
                  onPressed: _busy ? null : _attach,
                  icon: const Icon(AppIcons.camera, size: 18),
                  label: Text(l.incidentAttach),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final attachment in _added)
              PendingAttachmentRow(
                attachment: attachment,
                onRemove: () => setState(() => _added.remove(attachment)),
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: (_busy || _body.text.trim().isEmpty) ? null : _send,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.warning),
              label: Text(_busy ? l.incidentSending : l.incidentSend),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.incidentWhatIsAttached,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
