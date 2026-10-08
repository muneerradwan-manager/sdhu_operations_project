import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_icons.dart';
import '../theme/glass_tokens.dart';
import 'glass.dart';
import 'responsive.dart';

/// A titled glass pane grouping a set of [InfoRow]s, with hairline separators
/// between rows so long detail screens stay scannable — or without them, for a
/// pane holding a form rather than a list of fields. See [separated].
///
/// The fields fill the pane's width in as many columns as fit. A value here is
/// a name, a city or a date — a dozen characters, most of them — so one field
/// per line spends a monitor's width on the space *after* the value: seven
/// fields become seven near-empty lines and a page that has to be scrolled to
/// be read. Wide enough, and the same seven fit in three lines you can take in
/// at once.
///
/// The separators stay horizontal, between rows of fields rather than between
/// fields. That is what says which things are on the same line — a grid ruled
/// in both directions reads as a spreadsheet, and none of this is tabular.
class InfoSection extends StatelessWidget {
  const InfoSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.minFieldWidth = 280,
    this.maxColumns = 3,
    this.separated = true,
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;

  /// Whether to rule a hairline between the rows.
  ///
  /// True is right for what this widget was built for: a list of [InfoRow]s,
  /// where every child is one labelled value and the rules are what keep a long
  /// column of them scannable.
  ///
  /// It is wrong for a pane holding a FORM. The separator is placed between
  /// children, and a form's children are not peers — a label belongs to the
  /// control under it, a master switch governs everything below it, and a
  /// [SizedBox] used as a spacer is not a row at all but still gets ruled off
  /// on both sides, which draws two lines around eight pixels of nothing. The
  /// settings page's own panes had seven of these and the accounts pane two;
  /// see `PrayerAlertsSection` and `_AccountsSection`, which is where this flag
  /// came from.
  ///
  /// Only turn it off. A caller wanting SOME of the rules wants a second pane.
  final bool separated;

  /// The narrowest a field may get before the pane drops a column. Its default
  /// is set so that a pane inside the old 600-wide cap stays in one column —
  /// this widget is shared, and no page changes shape until it is given the
  /// room to.
  final double minFieldWidth;

  /// Past three across, the eye stops reading a row of fields and starts
  /// searching one.
  final int maxColumns;

  static const _gap = AppSpacing.lg;

  /// The pane's own left and right padding, which the rows sit inside.
  static const _inset = AppSpacing.lg * 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Inside a grid cell the width is already known, and must NOT be measured
    // again: a [LayoutBuilder] cannot report intrinsic dimensions, and an
    // equal-height row of panes is built by asking each pane for exactly that.
    // Three of these side by side on the settings page brought it down until
    // the grid started handing the number over instead. See [GridCellWidth].
    final cell = GridCellWidth.maybeOf(context);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (cell != null)
            _rows(scheme, cell - _inset)
          else
            LayoutBuilder(
              builder: (context, constraints) =>
                  _rows(scheme, constraints.maxWidth),
            ),
        ],
      ),
    );
  }

  Widget _rows(ColorScheme scheme, double width) {
    final columns = width.isFinite && width > 0
        ? ((width + _gap) ~/ (minFieldWidth + _gap)).clamp(1, maxColumns)
        : 1;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(columns == 1 ? children[i] : _row(i, columns));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0 && separated)
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          rows[i],
        ],
      ],
    );
  }

  Widget _row(int start, int columns) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < columns; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            // A short final row keeps its fields in their columns rather than
            // letting them spread out and break the alignment down the pane.
            Expanded(
              child: start + i < children.length
                  ? children[start + i]
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

/// What a row's value can be acted on with. A phone number is there to be
/// called and an address to be written to — reading either off the screen and
/// retyping it is the failure this avoids.
enum InfoAction {
  call('tel', AppIcons.phoneSy),
  email('mailto', AppIcons.email);

  const InfoAction(this.scheme, this.icon);

  final String scheme;
  final IconData icon;

  Uri uriFor(String value) => Uri(
    scheme: scheme,
    // A number written "+963 11 222" dials only once the spacing is gone.
    path: this == InfoAction.call ? digitsOf(value) : value.trim(),
  );

  /// A telephone number reduced to what a dialler will accept.
  ///
  /// Lifted out of [uriFor] because [whatsAppUri] needs the same reduction and
  /// must not grow its own copy: the two would drift the first time somebody
  /// stored a number with a dash in it.
  static String digitsOf(String value) =>
      value.replaceAll(RegExp(r'[^0-9+]'), '');

  /// The same number, opened in WhatsApp instead of the dialler.
  ///
  /// Worth a second button rather than a replacement, because the two are not
  /// interchangeable for this mission. Its staff carry Syrian numbers and stand
  /// in Saudi Arabia, so a call is an international one on a foreign network and
  /// WhatsApp is what most of these conversations actually happen on. And when
  /// the network in Mina is too thin to hold a call, a message still goes.
  ///
  /// Null when there is nothing dialable in [value], so the button can simply
  /// not be drawn.
  ///
  /// `wa.me` rather than the `whatsapp:` scheme: it opens the app when it is
  /// installed and the web client when it is not, instead of failing at a
  /// scheme nothing on the device claims. It also insists on a full
  /// international number with no `+` and no zeros in front — a local "0999…"
  /// reaches nobody — so a number that is not in that shape is refused here
  /// rather than opened onto an error.
  static Uri? whatsAppUri(String value) {
    final digits = digitsOf(value);
    final international = digits.startsWith('+')
        ? digits.substring(1)
        : digits.startsWith('00')
        ? digits.substring(2)
        : null;
    if (international == null || international.length < 8) return null;
    return Uri.parse('https://wa.me/$international');
  }
}

/// A labelled value row with a leading icon; shows "not provided" when empty.
///
/// Give it an [action] and the value becomes a link: tap to dial or to open a
/// mail composer, long-press to copy.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.action,
  });

  final IconData icon;
  final String label;
  final String? value;
  final InfoAction? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isEmpty = value == null || value!.isEmpty;
    final shown = isEmpty ? context.l10n.profileFieldNotProvided : value!;
    final live = action != null && !isEmpty;
    final whatsApp = action == InfoAction.call && !isEmpty
        ? InfoAction.whatsAppUri(value!)
        : null;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  shown,
                  style: text.bodyLarge?.copyWith(
                    // Placeholder text recedes so real values read first; a
                    // live value is coloured the way a link is expected to be.
                    color: isEmpty
                        ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
                        : (live ? scheme.primary : scheme.onSurface),
                    fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  // An address is longer than the row and must not be clipped
                  // to something that reads like a different address.
                  softWrap: true,
                ),
              ],
            ),
          ),
          // WhatsApp before the dialler, and that order is the claim.
          //
          // This mission's staff carry Syrian numbers and stand in Saudi
          // Arabia: a call is an international one on a foreign network, and
          // WhatsApp is where most of these conversations already happen. It is
          // also the one that still works when the network in Mina is too thin
          // to hold a call — a message waits and goes; a call just fails.
          //
          // Drawn only when the stored number is in full international form,
          // because `wa.me` accepts nothing else. A local "0999…" would open
          // onto an error page, which is worse than an absent button.
          if (whatsApp case final uri?) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: context.l10n.contactWhatsApp,
              onPressed: () =>
                  launchUrl(uri, mode: LaunchMode.externalApplication),
              icon: const Icon(AppIcons.whatsApp, size: 18),
              color: scheme.primary,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
          if (live) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(action!.icon, size: 18, color: scheme.primary),
          ],
        ],
      ),
    );

    if (!live) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => launchUrl(action!.uriFor(value!)),
      onLongPress: () => copyToClipboard(context, value!),
      child: row,
    );
  }
}

/// Copies [value] and says so. Used where a value is worth having in another
/// app but the link may not resolve — a device with no mail client set up.
Future<void> copyToClipboard(BuildContext context, String value) async {
  final message = context.l10n.commonCopied;
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: value));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String formatDate(DateTime? d) => d == null
    ? ''
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The date AND the hour, for a list where several things happen in one day.
///
/// [formatDate] is right almost everywhere in this app — a task is due on a
/// day, a season runs between two of them — and wrong in exactly one place: a
/// record of what went on. A task picked up at dawn, stuck by noon and sent for
/// acceptance in the evening has three lines that all read «١٤٤٧-٠٦-٠٩», which
/// is a timeline with the time taken out of it.
///
/// Twenty-four hour, because the whole mission runs on it and «٦:٤٠» with no
/// م/ص is the one ambiguity a schedule cannot afford.
String formatDateTime(DateTime? d) => d == null
    ? ''
    : '${formatDate(d)} · ${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
