import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import 'grid_layout.dart';
import 'scoring.dart';

const _mm = PdfPageFormat.mm;

class PdfService {
  /// Sujet d'une version : titre, code de version, questions et propositions dans l'ordre figé.
  static Future<Uint8List> examPdf(ExamVersion v) async {
    final doc = pw.Document();
    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(v.examTitle, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Version ${v.code}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
      build: (_) => [
        for (var i = 0; i < v.questions.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('${i + 1}. ${v.questions[i].text}', style: bold),
              for (var j = 0; j < v.questions[i].options.length; j++)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 14, top: 2),
                  child: pw.Text('${letter(j)}) ${v.questions[i].options[j].text}'),
                ),
            ]),
          ),
      ],
    ));
    return doc.save();
  }

  /// Une grille de réponses (une carte). Repères noirs aux 4 coins, cadres Nom / Prénom, cases rondes.
  static pw.Widget _card(ExamVersion v) {
    final lay = GridLayout(v.questions.length);
    final nOpts = v.maxOptions;

    pw.Widget at(double x, double y, pw.Widget w) =>
        pw.Positioned(left: (GridLayout.ox + x) * _mm, top: (GridLayout.oy + y) * _mm, child: w);
    pw.Widget box(double w, double h, {PdfColor? fill, double border = 0, bool circle = false}) => pw.Container(
          width: w * _mm,
          height: h * _mm,
          decoration: pw.BoxDecoration(
            color: fill,
            shape: circle ? pw.BoxShape.circle : pw.BoxShape.rectangle,
            border: border > 0 ? pw.Border.all(width: border) : null,
          ),
        );
    pw.Widget txt(String s, double size, {bool bold = false}) => pw.Text(s,
        style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal));

    final kids = <pw.Widget>[
      pw.Positioned(left: 0, top: 0, child: box(GridLayout.cardW, GridLayout.cardH, border: 0.4)),
      // repères
      for (final cx in [0.0, GridLayout.fw])
        for (final cy in [0.0, GridLayout.fh]) at(cx - 2.5, cy - 2.5, box(5, 5, fill: PdfColors.black)),
      // en-tête
      at(5, -1.8, txt('Version ${v.code}', 11, bold: true)),
      at(32, -0.9, pw.SizedBox(width: 44 * _mm, child: pw.Text(v.examTitle, maxLines: 1, style: const pw.TextStyle(fontSize: 6.5)))),
      at(1, GridLayout.nomY + 1.3, txt('Nom', 6.5)),
      at(GridLayout.nameX, GridLayout.nomY, box(GridLayout.nameW, GridLayout.nameH, border: 0.5)),
      at(1, GridLayout.prenomY + 1.3, txt('Prénom', 6.5)),
      at(GridLayout.nameX, GridLayout.prenomY, box(GridLayout.nameW, GridLayout.nameH, border: 0.5)),
      // lettres A B C...
      for (var col = 0; col < 2; col++)
        if (col == 0 || lay.n > lay.rows)
          for (var o = 0; o < nOpts; o++)
            at(lay.xOf(col, o) - 2, 22.6, pw.SizedBox(width: 4 * _mm, child: pw.Center(child: txt(letter(o), 6.5, bold: true)))),
      // questions
      for (var q = 0; q < v.questions.length; q++) ...[
        at(lay.numX(q), lay.by(q) - 1.4, pw.SizedBox(width: 7 * _mm, child: txt('${q + 1}', 6.5))),
        for (var o = 0; o < v.questions[q].options.length; o++)
          at(lay.bx(q, o) - lay.radius, lay.by(q) - lay.radius,
              box(lay.radius * 2, lay.radius * 2, border: 0.6, circle: true)),
      ],
    ];
    return pw.SizedBox(width: GridLayout.cardW * _mm, height: GridLayout.cardH * _mm, child: pw.Stack(children: kids));
  }

  /// Planche A4 : 6 grilles identiques (2 x 3) pour une version.
  static Future<Uint8List> gridSheetPdf(ExamVersion v) async {
    final doc = pw.Document();
    pw.Widget row() => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [_card(v), _card(v)]);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Center(child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [row(), row(), row()])),
    ));
    return doc.save();
  }

  /// Grille de correction (réponses justes) pour l'enseignant.
  static Future<Uint8List> keyPdf(ExamVersion v) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => [
        pw.Text('Grille de correction - ${v.examTitle} - Version ${v.code}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 14),
        pw.Wrap(spacing: 16, runSpacing: 8, children: [
          for (var q = 0; q < v.questions.length; q++)
            pw.SizedBox(
                width: 90, child: pw.Text('${q + 1} : ${(v.correctOf(q).toList()..sort()).map(letter).join(', ')}')),
        ]),
        pw.SizedBox(height: 14),
        pw.Text('Bareme : ${scoringLabels[v.scoring]}'),
      ],
    ));
    return doc.save();
  }
}
