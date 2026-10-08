import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/info_section.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/domain/profile.dart';
import '../../../profile/domain/profile_enums.dart';
import '../../../profile/domain/reference_choice.dart';
import '../../application/employee_manage_cubit.dart';

/// Bottom sheet for correcting an employee's record.
///
/// Only what describes the person. What they ARE — admin, external, suspended,
/// approved — is decided elsewhere, by permissions of its own, and the database
/// would refuse those columns from an editor anyway. Showing them here would be
/// offering a change that silently does not happen.
Future<void> showEmployeeEditSheet(
  BuildContext context,
  EmployeeManageCubit cubit,
  Profile profile,
) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) =>
        _EmployeeEditForm(cubit: cubit, profile: profile),
  );
}

class _EmployeeEditForm extends StatefulWidget {
  const _EmployeeEditForm({required this.cubit, required this.profile});
  final EmployeeManageCubit cubit;
  final Profile profile;

  @override
  State<_EmployeeEditForm> createState() => _EmployeeEditFormState();
}

class _EmployeeEditFormState extends State<_EmployeeEditForm> {
  final _formKey = GlobalKey<FormState>();
  final _profiles = ProfileRepository();

  late final _first = TextEditingController(text: widget.profile.firstName);
  late final _father = TextEditingController(text: widget.profile.fatherName);
  late final _surname = TextEditingController(text: widget.profile.surname);
  late final _phoneSy = TextEditingController(text: widget.profile.phoneSy);
  late final _phoneSa = TextEditingController(text: widget.profile.phoneSa);

  late String? _jobTitleId = widget.profile.jobTitleId;
  late String? _cityId = widget.profile.cityId;
  late Gender? _gender = widget.profile.gender;
  late String? _missionTypeId = widget.profile.missionTypeId;
  late DateTime? _dob = widget.profile.dateOfBirth;

  List<ReferenceChoice> _titles = const [];
  List<ReferenceChoice> _cities = const [];
  List<ReferenceChoice> _missions = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final titles = await _profiles.fetchActiveJobTitles();
      final cities = await _profiles.fetchSyrianCities();
      final missions = await _profiles.fetchMissionTypes();
      if (!mounted) return;
      setState(() {
        _titles = titles;
        _cities = cities;
        _missions = missions;
        // A job title that has since been deactivated is still this person's
        // title. Dropping it from the list would silently clear it on save.
        if (_jobTitleId != null && !titles.any((t) => t.id == _jobTitleId)) {
          _jobTitleId = null;
        }
        if (_cityId != null && !cities.any((c) => c.id == _cityId)) {
          _cityId = null;
        }
        if (_missionTypeId != null &&
            !missions.any((m) => m.id == _missionTypeId)) {
          _missionTypeId = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _father.dispose();
    _surname.dispose();
    _phoneSy.dispose();
    _phoneSa.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 90),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.cubit.saveDetails(
      firstName: _first.text,
      fatherName: _father.text,
      surname: _surname.text,
      jobTitleId: _jobTitleId,
      gender: _gender,
      missionTypeId: _missionTypeId,
      dateOfBirth: _dob,
      cityId: _cityId,
      phoneSy: _phoneSy.text,
      phoneSa: _phoneSa.text,
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.employeeEditSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? l.commonRequired : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.employeeEditDetailsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _first,
                textInputAction: TextInputAction.next,
                validator: required,
                decoration: InputDecoration(
                  labelText: l.profileFirstName,
                  prefixIcon: const Icon(AppIcons.firstName),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _father,
                textInputAction: TextInputAction.next,
                validator: required,
                decoration: InputDecoration(
                  labelText: l.profileFatherName,
                  prefixIcon: const Icon(AppIcons.fatherName),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _surname,
                textInputAction: TextInputAction.next,
                validator: required,
                decoration: InputDecoration(
                  labelText: l.profileSurname,
                  prefixIcon: const Icon(AppIcons.surname),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _jobTitleId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l.profileJobTitle,
                  prefixIcon: const Icon(AppIcons.jobTitle),
                ),
                items: [
                  for (final t in _titles)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text(t.name.of(context)),
                    ),
                ],
                onChanged: (v) => setState(() => _jobTitleId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _cityId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l.profileCity,
                  prefixIcon: const Icon(AppIcons.location),
                ),
                items: [
                  for (final c in _cities)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name.of(context)),
                    ),
                ],
                onChanged: (v) => setState(() => _cityId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Gender>(
                initialValue: _gender,
                decoration: InputDecoration(
                  labelText: l.profileGender,
                  prefixIcon: const Icon(AppIcons.gender),
                ),
                items: [
                  DropdownMenuItem(
                    value: Gender.male,
                    child: Text(l.genderMale),
                  ),
                  DropdownMenuItem(
                    value: Gender.female,
                    child: Text(l.genderFemale),
                  ),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _missionTypeId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l.profileMissionType,
                  prefixIcon: const Icon(AppIcons.mission),
                ),
                items: [
                  for (final m in _missions)
                    DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name.of(context)),
                    ),
                ],
                onChanged: (v) => setState(() => _missionTypeId = v),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l.profileDateOfBirth,
                    prefixIcon: const Icon(AppIcons.dateOfBirth),
                  ),
                  child: Text(formatDate(_dob)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneSy,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l.profilePhoneSy,
                  prefixIcon: const Icon(AppIcons.phoneSy),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneSa,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l.profilePhoneSa,
                  prefixIcon: const Icon(AppIcons.phoneSa),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: _save, child: Text(l.commonSave)),
            ],
          ),
        ),
      ),
    );
  }
}
