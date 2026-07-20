import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfSection {
  final String title;
  final String? meta;
  final List<String>? tags;
  final String? personalNote;
  final String bodyText;

  PdfSection({
    required this.title,
    this.meta,
    this.tags,
    this.personalNote,
    required this.bodyText,
  });
}

/// Renders sections into a watermarked PDF and opens the platform's print/save
/// dialog. Unlike the web app's rasterized-image export (built for anti-copy-paste
/// in a browser), this produces a standard text PDF - the norm for native apps -
/// with a visible ownership watermark on every page.
Future<void> exportNotesPdf(
  List<PdfSection> sections,
  String documentName, {
  String watermarkText = 'Personal copy - do not redistribute',
}) async {
  final doc = pw.Document();

  final pageTheme = pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
    buildBackground: (context) => pw.FullPage(
      ignoreMargins: true,
      child: pw.Watermark.text(
        watermarkText,
        angle: math.pi / 6,
        style: pw.TextStyle(color: PdfColors.grey300, fontSize: 22, fontWeight: pw.FontWeight.bold),
      ),
    ),
  );

  final content = <pw.Widget>[];
  for (int i = 0; i < sections.length; i++) {
    final section = sections[i];
    if (i > 0) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 18),
        child: pw.Divider(thickness: 1, color: PdfColors.grey300),
      ));
    }
    content.add(pw.Text(section.title, style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)));
    if (section.meta != null && section.meta!.isNotEmpty) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 3),
        child: pw.Text(section.meta!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ));
    }
    if (section.tags != null && section.tags!.isNotEmpty) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Wrap(
          spacing: 6,
          runSpacing: 6,
          children: section.tags!
              .map((tag) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: pw.BoxDecoration(color: PdfColors.indigo50, borderRadius: pw.BorderRadius.circular(999)),
                    child: pw.Text(tag, style: pw.TextStyle(fontSize: 8, color: PdfColors.indigo700, fontWeight: pw.FontWeight.bold)),
                  ))
              .toList(),
        ),
      ));
    }
    if (section.personalNote != null && section.personalNote!.isNotEmpty) {
      content.add(pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.amber50,
          border: pw.Border.all(color: PdfColors.amber200),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(text: 'Personal note: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(text: section.personalNote, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ));
    }
    content.add(pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12),
      child: pw.Text(section.bodyText, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 3)),
    ));
  }

  doc.addPage(
    pw.MultiPage(
      pageTheme: pageTheme,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ),
      build: (context) => content,
    ),
  );

  await Printing.layoutPdf(
    onLayout: (_) => doc.save(),
    name: documentName.endsWith('.pdf') ? documentName : '$documentName.pdf',
  );
}
