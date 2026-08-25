import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // <-- Добавлен обязательный импорт

import '../../data/models/batch_model.dart';
import '../../data/models/label_template_model.dart';

class PdfGenerator {
  /// Генерация этикетки с точными габаритами в мм
  static Future<Uint8List> generateLabelPdf({
    required Batch batch,
    required LabelTemplate template,
  }) async {
    final pdf = pw.Document();

    // Конвертация мм в точки PDF (1 мм = 2.83465 pt)
    final widthPt = template.widthMm * PdfPageFormat.mm;
    final heightPt = template.heightMm * PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(
      widthPt,
      heightPt,
      marginAll: 2 * PdfPageFormat.mm,
    );

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final dateFormat = DateFormat('dd.MM.yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          final sugarVal = batch.finalSugar ?? batch.initialSugar;
          final alcoholVal = batch.finalAlcohol ?? 0;
          final notesText = batch.notes;

          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1, color: PdfColors.black),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Название партии
                pw.Center(
                  child: pw.Text(
                    batch.name.toUpperCase(),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                ),
                pw.Divider(thickness: 0.5),

                // Основные параметры
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Сорт:', style: const pw.TextStyle(fontSize: 7)),
                    pw.Text(
                      batch.appleVariety,
                      style: const pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Сахар:', style: const pw.TextStyle(fontSize: 7)),
                    pw.Text('$sugarVal г/100мл', style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Алкоголь:', style: const pw.TextStyle(fontSize: 7)),
                    pw.Text(
                      '$alcoholVal% об.',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Дата розлива:', style: const pw.TextStyle(fontSize: 7)),
                    pw.Text(
                      dateFormat.format(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ],
                ),

                // Проверка на null для заметки
                if (notesText.isNotEmpty) ...[
                  pw.Divider(thickness: 0.5),
                  pw.Text(
                    'Заметка: $notesText',
                    style: const pw.TextStyle(fontSize: 6),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}