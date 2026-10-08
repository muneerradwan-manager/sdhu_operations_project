import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../auth/application/session_cubit.dart';
import '../../auth/data/auth_repository.dart';
import '../application/profile_completion_cubit.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';
import '../domain/profile_enums.dart';
import '../domain/reference_choice.dart';
import '../../../core/widgets/blocking_progress.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';

/// Where this form stops widening, which is well short of where a page would.
///
/// A form is the one thing on a monitor that must NOT take the room it is
/// offered. A text field five hundred pixels wide is harder to use than one at
/// three hundred, not easier: the eye has to travel back across it to check
/// what was typed, and the pointer has to cross it to reach the next one. So
/// the width here buys a second COLUMN of ordinary fields beside the portrait,
/// and then stops — the space left over is not waste, it is the reason the form
/// is still readable.
class ProfileCompletionScreen extends StatelessWidget {
  const ProfileCompletionScreen({super.key, this.existing});

  /// When provided, the screen edits this profile instead of completing a new one.
  final Profile? existing;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCompletionCubit(
        context.read<ProfileRepository>(),
        existing: existing,
      ),
      child: _ProfileCompletionView(existing: existing),
    );
  }
}

class _ProfileCompletionView extends StatefulWidget {
  const _ProfileCompletionView({this.existing});
  final Profile? existing;

  @override
  State<_ProfileCompletionView> createState() => _ProfileCompletionViewState();
}

class _ProfileCompletionViewState extends State<_ProfileCompletionView> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _surname = TextEditingController();
  final _fatherName = TextEditingController();
  final _phoneSy = TextEditingController();
  final _phoneSa = TextEditingController();

  File? _photo;
  File? _passport;
  File? _visa;
  File? _nusuk;
  String? _jobTitleId;
  String? _cityId;
  Gender? _gender;
  String? _missionTypeId;
  DateTime? _dob;
  bool _photoError = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _firstName.text = e.firstName ?? '';
      _fatherName.text = e.fatherName ?? '';
      _surname.text = e.surname ?? '';
      _phoneSy.text = e.phoneSy ?? '';
      _phoneSa.text = e.phoneSa ?? '';
      _jobTitleId = e.jobTitleId;
      _cityId = e.cityId;
      _gender = e.gender;
      _missionTypeId = e.missionTypeId;
      _dob = e.dateOfBirth;
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _surname.dispose();
    _fatherName.dispose();
    _phoneSy.dispose();
    _phoneSa.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _submit() {
    final formOk = _formKey.currentState?.validate() ?? false;
    // Photo required when creating; in edit mode the existing photo may stay.
    final photoMissing =
        _photo == null && (widget.existing?.photoUrl?.isEmpty ?? true);
    setState(() => _photoError = photoMissing);
    if (!formOk || photoMissing) return;
    // The dropdowns only insist on an answer when their list has one to give
    // (see [_choiceDropdown]); an empty list must not become a crash here.
    if (_jobTitleId == null || _missionTypeId == null) return;

    context.read<ProfileCompletionCubit>().submit(
      firstName: _firstName.text.trim(),
      surname: _surname.text.trim(),
      fatherName: _fatherName.text.trim(),
      photo: _photo,
      jobTitleId: _jobTitleId!,
      gender: _gender!,
      dateOfBirth: _dob!,
      missionTypeId: _missionTypeId!,
      phoneSy: _phoneSy.text.trim(),
      phoneSa: _phoneSa.text.trim().isEmpty ? null : _phoneSa.text.trim(),
      cityId: _cityId,
      passport: _passport,
      visa: _visa,
      nusuk: _nusuk,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: _isEdit,
        title: Text(_isEdit ? l.myProfileEditTitle : l.profileCompleteTitle),
        actions: [
          if (!_isEdit)
            IconButton(
              tooltip: l.commonLogout,
              onPressed: () => runBlocking(
                context,
                context.read<AuthRepository>().signOut,
                message: l.commonLoggingOut,
              ),
              icon: const Icon(AppIcons.logout),
            ),
        ],
      ),
      body: BlocConsumer<ProfileCompletionCubit, ProfileCompletionState>(
        listener: (context, state) {
          if (state.status == ProfileFormStatus.submitted) {
            // Refresh the session so the router / profile view reflect changes.
            context.read<SessionCubit>().reload();
            if (_isEdit) {
              Navigator.of(context).maybePop();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l.myProfileSaved)));
            }
          } else if (state.status == ProfileFormStatus.error &&
              state.error != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(friendlyError(context, state.error))));
          }
        },
        builder: (context, state) {
          if (state.status == ProfileFormStatus.loading) {
            return const AppLoader();
          }
          return _buildForm(context, l, state);
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    dynamic l,
    ProfileCompletionState state,
  ) {
    final submitting = state.status == ProfileFormStatus.submitting;

    final portrait = Center(
      child: ImagePickerField(
        label: l.profilePhoto,
        file: _photo,
        circular: true,
        existingUrl: widget.existing?.photoUrl,
        errorText: _photoError ? l.commonRequired : null,
        onPicked: (f) => setState(() {
          _photo = f;
          _photoError = false;
        }),
      ),
    );

    // The ordinary fields, in the order they are asked in. Handing them to the
    // grid as one list rather than as pre-built rows is what lets the same list
    // be one column on a phone and two on a monitor without being written
    // twice — and it keeps the reading order the tab key follows.
    final fields = <Widget>[
      _text(_firstName, l.profileFirstName, AppIcons.firstName),
      _text(_fatherName, l.profileFatherName, AppIcons.fatherName),
      _text(_surname, l.profileSurname, AppIcons.surname),
      _choiceDropdown(
        l,
        l.profileCity,
        AppIcons.location,
        state.cities,
        _cityId,
        (v) => setState(() => _cityId = v),
      ),
      _choiceDropdown(
        l,
        l.profileJobTitle,
        AppIcons.jobTitle,
        state.jobTitles,
        _jobTitleId,
        (v) => setState(() => _jobTitleId = v),
      ),
      _genderDropdown(l),
      _choiceDropdown(
        l,
        l.profileMissionType,
        AppIcons.mission,
        state.missionTypes,
        _missionTypeId,
        (v) => setState(() => _missionTypeId = v),
      ),
      _dobField(l),
      _text(
        _phoneSy,
        l.profilePhoneSy,
        AppIcons.phoneSy,
        keyboard: TextInputType.phone,
      ),
      _text(
        _phoneSa,
        '${l.profilePhoneSa} (${l.commonOptional})',
        AppIcons.phoneSa,
        keyboard: TextInputType.phone,
        required: false,
      ),
    ];

    final body = <Widget>[
      if (!_isEdit) ...[
        Text(
          l.profileCompleteSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
      // Two columns at most, however wide the window. A form read in more than
      // two columns stops being a sequence of questions and becomes a page to
      // search, and the answer to "which field comes next" stops being obvious.
      AdaptiveGrid(
        spacing: AppSpacing.lg,
        equalHeights: false,
        children: fields,
      ),
      const SizedBox(height: 28),
      _DocumentsSection(
        title: l.profileDocumentsSection,
        passportLabel: l.profilePassportPhoto,
        visaLabel: l.profileVisaPhoto,
        nusukLabel: l.profileNusukPhoto,
        passport: _passport,
        visa: _visa,
        nusuk: _nusuk,
        onPassport: (f) => setState(() => _passport = f),
        onVisa: (f) => setState(() => _visa = f),
        onNusuk: (f) => setState(() => _nusuk = f),
      ),
      const SizedBox(height: 32),
    ];

    final submit = FilledButton(
      onPressed: submitting ? null : _submit,
      child: submitting
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Text(_isEdit ? l.commonSave : l.profileSubmitForApproval),
    );

    return AbsorbPointer(
      absorbing: submitting,
      child: Form(
        key: _formKey,
        // The Form wraps both panes: the portrait is not a field, but the scope
        // has to cover everything the submit button validates.
        child: ResponsivePage(
          width: PageWidth.editor,
          builder: (context, size) {
            final wide = size.isAtLeast(WindowSize.expanded);

            // Full width on a phone, where a button IS the bottom of the
            // screen and the thumb goes wherever it likes. Not on a monitor: a
            // seven-hundred-pixel button reads as a banner, and the pointer has
            // one place to be anyway.
            final action = wide
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220),
                      child: submit,
                    ),
                  )
                : submit;

            // The portrait takes the standing panel here for the same reason it
            // does on the profile itself — this screen is the same person, in
            // the same place, with the fields open.
            return wide
                ? TwoPaneLayout(
                    gutter: size.gutter,
                    bottom: AppSpacing.xxl,
                    keyboardDismiss: ScrollViewKeyboardDismissBehavior.onDrag,
                    panel: FadeSlideIn(child: portrait),
                    children: staggered([...body, action]),
                  )
                : SinglePaneLayout(
                    gutter: size.gutter,
                    bottom: AppSpacing.xxl,
                    keyboardDismiss: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: staggered([
                      portrait,
                      const SizedBox(height: 28),
                      ...body,
                      action,
                    ]),
                  );
          },
        ),
      ),
    );
  }

  Widget _text(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    bool required = true,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: required
          ? (v) => (v ?? '').trim().isEmpty ? context.l10n.commonRequired : null
          : null,
    );
  }

  /// The city, the post and the mission are one question asked three times: pick
  /// an entry of a list the admin owns. One widget for all three, since 0085
  /// made them one kind of row.
  ///
  /// Required, but only once there is something to require: if a list came back
  /// empty the field cannot be answered, and blocking the form on it would
  /// strand somebody in the middle of registering.
  Widget _choiceDropdown(
    dynamic l,
    String label,
    IconData icon,
    List<ReferenceChoice> choices,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    // Sorted by the name being READ. The query orders by the Arabic column,
    // which in an English list is no order at all.
    final sorted = [...choices]
      ..sort((a, b) => a.name.of(context).compareTo(b.name.of(context)));

    return DropdownButtonFormField<String>(
      initialValue: sorted.any((c) => c.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: [
        for (final c in sorted)
          DropdownMenuItem(value: c.id, child: Text(c.name.of(context))),
      ],
      validator: (v) =>
          sorted.isNotEmpty && v == null ? l.commonRequired : null,
      onChanged: onChanged,
    );
  }

  Widget _genderDropdown(dynamic l) {
    return DropdownButtonFormField<Gender>(
      initialValue: _gender,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l.profileGender,
        prefixIcon: const Icon(AppIcons.gender),
      ),
      items: [
        DropdownMenuItem(value: Gender.male, child: Text(l.genderMale)),
        DropdownMenuItem(value: Gender.female, child: Text(l.genderFemale)),
      ],
      validator: (v) => v == null ? l.commonRequired : null,
      onChanged: (v) => setState(() => _gender = v),
    );
  }

  Widget _dobField(dynamic l) {
    final text = _dob == null
        ? l.profileSelectDate
        : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: _pickDob,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l.profileDateOfBirth,
          prefixIcon: const Icon(AppIcons.dateOfBirth),
          errorText: null,
        ),
        child: Text(text),
      ),
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({
    required this.title,
    required this.passportLabel,
    required this.visaLabel,
    required this.nusukLabel,
    required this.passport,
    required this.visa,
    required this.nusuk,
    required this.onPassport,
    required this.onVisa,
    required this.onNusuk,
  });

  final String title;
  final String passportLabel;
  final String visaLabel;
  final String nusukLabel;
  final File? passport;
  final File? visa;
  final File? nusuk;
  final ValueChanged<File> onPassport;
  final ValueChanged<File> onVisa;
  final ValueChanged<File> onNusuk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        // Three of the same thing, and nothing to read in any of them — the
        // one place on this form where a row of three is easier to take in
        // than a column of three.
        AdaptiveGrid(
          minTileWidth: CardWidth.stat,
          spacing: AppSpacing.md,
          equalHeights: false,
          children: [
            ImagePickerField(
              label: passportLabel,
              file: passport,
              onPicked: onPassport,
            ),
            ImagePickerField(label: visaLabel, file: visa, onPicked: onVisa),
            ImagePickerField(label: nusukLabel, file: nusuk, onPicked: onNusuk),
          ],
        ),
      ],
    );
  }
}
