import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/animations/animations.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/info_section.dart';
import '../../data/map_link_resolver.dart';
import '../../domain/map_location.dart';
import '../../domain/module_type.dart';
import '../../domain/operational_module.dart';
import '../../domain/reference_item.dart';
import '../map_picker_screen.dart';
import 'picker_sheet.dart';

/// Renders one field of a module type. The module type — not this widget —
/// decides what the field is, which is what lets a new type ship without a
/// code change: every kind in [ModuleFieldKind] has a branch here.
class ModuleFieldInput extends StatelessWidget {
  const ModuleFieldInput({
    super.key,
    required this.field,
    required this.value,
    required this.referenceSet,
    required this.onChanged,
    this.onFilePicked,
  });

  final ModuleField field;
  final Object? value;

  /// The master-data list backing a [ModuleFieldKind.reference] field.
  final ReferenceSet? referenceSet;

  final void Function(Object? value) onChanged;

  /// Only module forms attach files; master-data forms leave this null and
  /// simply never define a pdf field.
  final void Function(File file, String fileName)? onFilePicked;

  String _label(BuildContext context) {
    final label = field.label.of(context);
    return field.isRequired ? '$label *' : label;
  }

  @override
  Widget build(BuildContext context) {
    return switch (field.kind) {
      ModuleFieldKind.reference => _ReferenceField(
        label: _label(context),
        set: referenceSet,
        value: value is String ? value as String : null,
        onChanged: onChanged,
      ),
      ModuleFieldKind.pdf => _PdfField(
        label: _label(context),
        file: ModuleFile.fromJson(value),
        onPicked: onFilePicked ?? (_, _) {},
      ),
      ModuleFieldKind.url => _TextField(
        label: _label(context),
        initial: value?.toString() ?? '',
        keyboardType: TextInputType.url,
        onChanged: onChanged,
      ),
      ModuleFieldKind.location => _LocationField(
        label: _label(context),
        url: value?.toString() ?? '',
        onChanged: onChanged,
      ),
      // Typed as text — what is stored is the string the code will carry, and
      // it is usually a link. Drawing it as a code is the READER's side of it,
      // which is why nothing here shows one.
      ModuleFieldKind.qr => _TextField(
        label: _label(context),
        initial: value?.toString() ?? '',
        keyboardType: TextInputType.url,
        onChanged: onChanged,
      ),
      // Text, not number: a phone number keeps its leading zero and may carry
      // a country prefix.
      ModuleFieldKind.phone => _TextField(
        label: _label(context),
        initial: value?.toString() ?? '',
        keyboardType: TextInputType.phone,
        formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
        icon: AppIcons.phoneSy,
        onChanged: onChanged,
      ),
      ModuleFieldKind.date => _DateField(
        label: _label(context),
        value: value is String ? DateTime.tryParse(value as String) : null,
        onChanged: (d) => onChanged(d?.toIso8601String().split('T').first),
      ),
      ModuleFieldKind.number => _TextField(
        label: _label(context),
        initial: value?.toString() ?? '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        onChanged: (v) => onChanged(v.isEmpty ? null : num.tryParse(v) ?? v),
      ),
      ModuleFieldKind.textarea => _TextField(
        label: _label(context),
        initial: value?.toString() ?? '',
        maxLines: 4,
        onChanged: onChanged,
      ),
      ModuleFieldKind.text => _TextField(
        label: _label(context),
        initial: value?.toString() ?? '',
        onChanged: onChanged,
      ),
    };
  }
}

class _TextField extends StatefulWidget {
  const _TextField({
    required this.label,
    required this.initial,
    required this.onChanged,
    this.maxLines = 1,
    this.keyboardType,
    this.formatters,
    this.icon,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final IconData? icon;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.formatters,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon),
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// A dropdown fed by admin-managed master data. Free text is deliberately not
/// offered — the same hotel typed three ways would become three hotels.
class _ReferenceField extends StatelessWidget {
  const _ReferenceField({
    required this.label,
    required this.set,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final ReferenceSet? set;
  final String? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = set?.items ?? const <ReferenceItem>[];
    final selected = items.where((i) => i.id == value).firstOrNull;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () async {
        final result = await showPickerSheet(
          context,
          title: label,
          options: [
            for (final i in items)
              PickerOption(id: i.id, label: i.name.of(context)),
          ],
          selected: {?value},
          emptyMessage: l.referenceEmpty,
        );
        if (result != null) onChanged(result.firstOrNull);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selected?.name.of(context) ?? l.moduleRoleUnassigned,
          style: selected == null
              ? TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                )
              : null,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(AppIcons.seasons),
        ),
        child: Text(
          value == null ? context.l10n.profileSelectDate : formatDate(value),
        ),
      ),
    );
  }
}

/// A place on the ground. Three ways in, in the order they get used: drop a pin
/// on a map, take the position you are standing at, or paste a link you already
/// have. All three end as the same stored URL.
class _LocationField extends StatefulWidget {
  const _LocationField({
    required this.label,
    required this.url,
    required this.onChanged,
  });

  final String label;
  final String url;
  final ValueChanged<Object?> onChanged;

  @override
  State<_LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<_LocationField> {
  late final _controller = TextEditingController(text: widget.url);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply(MapLocation location) {
    _controller.text = location.url;
    widget.onChanged(location.url);
  }

  /// The link currently being resolved, so that a person still typing does not
  /// start a request per keystroke and so that a slow answer for an old paste
  /// cannot overwrite a newer one.
  String? _resolving;

  Future<void> _resolveIfShort(String value) async {
    final link = value.trim();
    if (!MapLocation.isShortLink(link) || link == _resolving) return;
    _resolving = link;

    final found = await const MapLinkResolver().resolve(link);
    if (!mounted || _resolving != link) return;
    _resolving = null;
    if (found == null) return;

    // Replaced rather than annotated: what is stored becomes the canonical
    // `?q=lat,lng`, which the database can read without following anything.
    // A stored short link is a place the season map cannot draw.
    _apply(found);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.locationResolved)));
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<MapLocation>(
      fadeThroughRoute(
        (_) => MapPickerScreen(initial: MapLocation.parse(_controller.text)),
      ),
    );
    if (picked != null) _apply(picked);
  }

  Future<void> _useCurrentLocation() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    void say(String message) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        say(l.locationServiceDisabled);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        say(l.locationPermissionDenied);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      _apply(
        MapLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
      say(l.locationCaptured);
    } catch (_) {
      say(l.locationFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final coordinates = MapLocation.parse(_controller.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickOnMap,
                icon: const Icon(AppIcons.map, size: 18),
                label: Text(
                  l.locationPickOnMap,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(AppIcons.myLocation, size: 18),
                label: Text(
                  l.locationUseCurrent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: coordinates == null
                ? l.locationOrPasteLink
                : '${coordinates.latitude.toStringAsFixed(5)}, '
                      '${coordinates.longitude.toStringAsFixed(5)}',
            prefixIcon: const Icon(AppIcons.location),
          ),
          // Re-read so a pasted link that carries coordinates starts showing
          // them under the field.
          onChanged: (v) {
            widget.onChanged(v);
            setState(() {});
            // And if it carries none because it is a share link, go and get
            // them. Pressing Share in Google Maps is the most natural way to
            // produce one of these, and until now it read as an empty field.
            _resolveIfShort(v);
          },
        ),
      ],
    );
  }
}

/// The module's official attachment. Picked here, uploaded on save — the file
/// is stored under the module's id, which does not exist until then.
class _PdfField extends StatelessWidget {
  const _PdfField({
    required this.label,
    required this.file,
    required this.onPicked,
  });

  final String label;
  final ModuleFile? file;
  final void Function(File file, String fileName) onPicked;

  Future<void> _pick(BuildContext context) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = picked?.path;
    if (picked == null || path == null) return;
    onPicked(File(path), picked.name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: [
          Icon(
            file == null ? AppIcons.documentEmpty : AppIcons.pdf,
            size: 18,
            color: file == null ? scheme.onSurfaceVariant : scheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              file?.name ?? l.moduleNoPdf,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: file == null
                  ? TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    )
                  : null,
            ),
          ),
          TextButton(
            onPressed: () => _pick(context),
            child: Text(file == null ? l.moduleAttachPdf : l.moduleReplacePdf),
          ),
        ],
      ),
    );
  }
}
