import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/password_field.dart';
import '../../../core/widgets/responsive.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/reference_choice.dart';
import '../../profile/domain/profile_enums.dart';
import '../application/create_employee_cubit.dart';
import '../data/employees_repository.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/states.dart';

class CreateEmployeeScreen extends StatelessWidget {
  const CreateEmployeeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CreateEmployeeCubit(
        EmployeesRepository(),
        context.read<ProfileRepository>(),
      ),
      child: const _View(),
    );
  }
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _fatherName = TextEditingController();
  final _surname = TextEditingController();
  final _phoneSy = TextEditingController();
  final _phoneSa = TextEditingController();
  final _org = TextEditingController();

  String? _jobTitleId;
  Gender? _gender;
  String? _missionTypeId;
  DateTime? _dob;
  bool _isExternal = false;

  @override
  void dispose() {
    for (final c in [
      _email,
      _password,
      _firstName,
      _fatherName,
      _surname,
      _phoneSy,
      _phoneSa,
      _org,
    ]) {
      c.dispose();
    }
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_jobTitleId == null ||
        _gender == null ||
        _missionTypeId == null ||
        _dob == null) {
      return;
    }
    context.read<CreateEmployeeCubit>().submit(
      email: _email.text,
      password: _password.text,
      firstName: _firstName.text.trim(),
      fatherName: _fatherName.text.trim(),
      surname: _surname.text.trim(),
      jobTitleId: _jobTitleId!,
      gender: _gender!,
      dateOfBirth: _dob!,
      missionTypeId: _missionTypeId!,
      phoneSy: _phoneSy.text.trim(),
      phoneSa: _phoneSa.text.trim().isEmpty ? null : _phoneSa.text.trim(),
      isExternal: _isExternal,
      externalOrganization: _isExternal && _org.text.trim().isNotEmpty
          ? _org.text.trim()
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: GlassAppBar(title: Text(l.createEmployeeTitle)),
      body: SafeArea(
        child: BlocConsumer<CreateEmployeeCubit, CreateEmployeeState>(
          listener: (context, state) {
            if (state.status == CreateEmployeeStatus.created) {
              Navigator.of(context).pop(true);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(l.createEmployeeCreated)),
                );
            } else if (state.error != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(friendlyError(context, state.error))));
            }
          },
          builder: (context, state) {
            if (state.status == CreateEmployeeStatus.loading) {
              return const AppLoader();
            }
            final submitting = state.status == CreateEmployeeStatus.submitting;
            // Two columns of fields at most, and the page stops well short of
            // the window — see profile_completion_screen.dart for why a form is
            // the one thing on a monitor that must not take the room it is
            // offered.
            final account = <Widget>[
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l.authEmail,
                  prefixIcon: const Icon(AppIcons.email),
                ),
                validator: (v) =>
                    Validators.isEmail(v ?? '') ? null : l.authInvalidEmail,
              ),
              PasswordField(
                controller: _password,
                label: l.authPassword,
                validator: (v) =>
                    (v ?? '').length < 8 ? l.authPasswordTooShort : null,
              ),
            ];

            final personal = <Widget>[
              _text(_firstName, l.profileFirstName, AppIcons.firstName),
              _text(_fatherName, l.profileFatherName, AppIcons.fatherName),
              _text(_surname, l.profileSurname, AppIcons.surname),
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

            Widget fields(List<Widget> children) => AdaptiveGrid(
              spacing: AppSpacing.md,
              equalHeights: false,
              children: children,
            );

            return AbsorbPointer(
              absorbing: submitting,
              child: Form(
                key: _formKey,
                child: ResponsivePage(
                  width: PageWidth.editor,
                  builder: (context, size) => SinglePaneLayout(
                    gutter: size.gutter,
                    bottom: AppSpacing.xxl,
                    keyboardDismiss: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: staggered([
                      _label(context, l.createEmployeeAccountSection),
                      const SizedBox(height: 8),
                      fields(account),
                      const SizedBox(height: 24),
                      _label(context, l.profileSectionPersonal),
                      const SizedBox(height: 8),
                      fields(personal),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(AppIcons.external),
                        title: Text(l.employeeIsExternal),
                        subtitle: Text(l.employeeIsExternalHint),
                        value: _isExternal,
                        onChanged: (v) => setState(() => _isExternal = v),
                      ),
                      // The organization, and nothing else: الوصف الوظيفي
                      // above is already his post at that ministry, not a role
                      // held on the mission — see 0138.
                      if (_isExternal) ...[
                        const SizedBox(height: 8),
                        _text(
                          _org,
                          l.employeeOrganization,
                          AppIcons.organization,
                          required: false,
                        ),
                      ],
                      const SizedBox(height: 28),
                      // Full width on a phone, where a button is the bottom of
                      // the screen; a button's width on a monitor.
                      _submitButton(
                        context,
                        label: l.createEmployeeSubmit,
                        submitting: submitting,
                        wide: size.isAtLeast(WindowSize.expanded),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => SectionHeader(text);

  /// Full width on a phone, where the button IS the bottom of the screen and
  /// the thumb goes wherever it likes; a button's width on a monitor, where a
  /// nine-hundred-pixel one reads as a banner.
  Widget _submitButton(
    BuildContext context, {
    required String label,
    required bool submitting,
    required bool wide,
  }) {
    final button = FilledButton(
      onPressed: submitting ? null : _submit,
      child: submitting
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                strokeCap: StrokeCap.round,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : Text(label),
    );

    if (!wide) return button;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220),
        child: button,
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

  /// The post and the mission are the same question over two lists the admin
  /// owns, so they are one widget. (0085 made them one kind of row.)
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
        ),
        child: Text(text),
      ),
    );
  }
}
