import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../export/data/pdf_writer.dart';
import '../domain/check_in.dart';

/// One place's code on paper.
///
/// Top-level rather than a method, because three callers need the same page and
/// a poster that differed between "print" and "share" would be two codes
/// claiming to be one.
///
/// One code per A4 sheet, deliberately not four: these go up one per gate, in
/// different places, often by different people, and a page holding four is a
/// page somebody cuts up wrongly at two in the morning.
///
/// The place's NAME is printed above the code and large. Whoever is putting
/// forty of these up is holding a stack of near-identical black squares, and a
/// code on the wrong gate is the one mistake that makes the whole register lie
/// — it would record people as present somewhere they have never been.
Future<Uint8List> placeCodeSheet({
  required PdfPageFormat format,
  required String payload,
  required String placeName,
  String? subtitle,
}) async {
  // The app's own Arabic font, converted to TrueType for exactly this — see
  // PdfWriter. Without it these names print as empty boxes.
  final theme = await PdfWriter.arabicTheme();
  final document = pw.Document(theme: theme);

  document.addPage(
    pw.Page(
      pageFormat: format,
      theme: theme,
      textDirection: pw.TextDirection.rtl,
      build: (context) => _page(payload, placeName, subtitle),
    ),
  );
  return document.save();
}

/// Every place of one list, one to a page.
///
/// The workflow this exists for is a person sitting down once with a printer
/// and coming away with the season's whole stock of stickers. Doing it one
/// place at a time is an afternoon's work, and an afternoon's work is the kind
/// that gets half-finished — which leaves gates with no code, and a register
/// with holes in exactly the places nobody got round to.
Future<Uint8List> placeCodeBook({
  required PdfPageFormat format,
  required List<({String payload, String placeName, String? subtitle})> places,
}) async {
  final theme = await PdfWriter.arabicTheme();
  final document = pw.Document(theme: theme);

  for (final place in places) {
    document.addPage(
      pw.Page(
        pageFormat: format,
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        build: (context) =>
            _page(place.payload, place.placeName, place.subtitle),
      ),
    );
  }
  return document.save();
}

pw.Widget _page(String payload, String placeName, String? subtitle) =>
    pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          placeName,
          style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
        ],
        pw.SizedBox(height: 28),
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: payload,
          width: 320,
          height: 320,
          drawText: false,
        ),
        pw.SizedBox(height: 20),
        // The payload in small print underneath. If a code is ever damaged or
        // unreadable in the sun, this is what lets somebody work out which gate
        // the sheet belonged to.
        pw.Text(
          payload,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          textDirection: pw.TextDirection.ltr,
        ),
      ],
    );

/// The code for one place, on screen and on paper.
///
/// On paper is the point. This is a sticker for a hotel entrance or a camp
/// gate, and the whole feature is worth nothing until somebody has printed it
/// and walked out to fix it there — so the screen exists mainly to reach the
/// print sheet.
class PlaceCodeScreen extends StatelessWidget {
  const PlaceCodeScreen({
    super.key,
    required this.code,
    required this.placeName,
    this.subtitle,
  });

  final PlaceCode code;
  final String placeName;

  /// Which list it came from, and its city or مشعر — what tells two "المخيم
  /// رقم ١٦" apart in a stack of paper.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final payload = code.encode();

    return Scaffold(
      appBar: GlassAppBar(title: Text(l.checkInQrTitle)),
      // Capped narrow: the code is a fixed 220 square, and a card stretched
      // across a monitor around it would put the print button a long way from
      // the thing it prints.
      body: ResponsivePage(
        width: PageWidth.form,
        builder: (context, size) => SinglePaneLayout(
          gutter: size.gutter,
          children: [
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Text(
                      placeName,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    // White behind the code always, in both themes. A QR is
                    // read by contrast, and a dark-mode card would hand the
                    // printer a negative that no phone can scan.
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: QrImageView(
                        data: payload,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l.checkInQrHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => Printing.layoutPdf(
                onLayout: (format) => placeCodeSheet(
                  format: format,
                  payload: payload,
                  placeName: placeName,
                  subtitle: subtitle,
                ),
                name: 'place-code',
              ),
              icon: const Icon(AppIcons.qrCode),
              label: Text(l.checkInQrPrint),
            ),
          ],
        ),
      ),
    );
  }
}
