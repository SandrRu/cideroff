import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/models/batch_model.dart';
import '../data/models/label_template_model.dart';

class LabelPdfService {
  /// Генерация PDF документа заданной партии по размерам шаблона
  static Future<Uint8List> generateLabelPdf({
    required Batch batch,
    required LabelTemplate template,
  }) async {
    final pdf = pw.Document();

    // Загрузка кириллических шрифтов из Google Fonts
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // Перевод миллиметров в поинты PDF (1 мм = 2.83465 pt)
    final widthPt = template.widthMm * PdfPageFormat.mm;
    final heightPt = template.heightMm * PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(
      widthPt,
      heightPt,
      marginAll: 2 * PdfPageFormat.mm,
    );

    // Форматирование даты DD.MM.YYYY
    final day = batch.pressDate.day.toString().padLeft(2, '0');
    final month = batch.pressDate.month.toString().padLeft(2, '0');
    final year = batch.pressDate.year;
    final formattedDate = '$day.$month.$year';

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        // Устанавливаем базовую тему со шрифтом Roboto для всей страницы
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1),
            ),
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Название партии
                pw.Text(
                  batch.name,
                  style: pw.TextStyle(font: fontBold, fontSize: 10),
                  maxLines: 1,
                ),
                pw.Divider(thickness: 0.5),

                // Характеристики
                pw.Text(
                  'Сорт: ${batch.appleVariety}',
                  style: pw.TextStyle(font: fontRegular, fontSize: 7),
                ),
                pw.Text(
                  'Дата: $formattedDate',
                  style: pw.TextStyle(font: fontRegular, fontSize: 7),
                ),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Крепость: ${batch.finalAlcohol ?? 0}% об.',
                      style: pw.TextStyle(font: fontBold, fontSize: 7),
                    ),
                    pw.Text(
                      'Сахар: ${batch.finalSugar ?? 0} г/100мл',
                      style: pw.TextStyle(font: fontRegular, fontSize: 6),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Открыть системное окно печати / сохранения в PDF
  static Future<void> printOrSaveLabel({
    required Batch batch,
    required LabelTemplate template,
  }) async {
    final pdfData = await generateLabelPdf(batch: batch, template: template);
    final sanitizeName = batch.name.replaceAll(RegExp(r'[^\w\s\-]'), '_');

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: 'Этикетка_$sanitizeName.pdf',
    );
  }
}