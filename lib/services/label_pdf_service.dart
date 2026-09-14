import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/models/batch_model.dart';
import '../data/models/label_template_model.dart';
import '../data/models/batch_container_model.dart';
import 'svg_label_processor.dart';

class LabelPdfService {
  /// Генерация PDF документа заданной партии по размерам шаблона
  static Future<Uint8List> generateLabelPdf({
    required Batch batch,
    BatchContainer? container,
    required LabelTemplate template,
    String? yeastName,
  }) async {
    // Если шаблон является кастомным SVG, вызываем генератор для SVG
    if (template.isCustomSvg && template.svgContent != null && template.svgContent!.isNotEmpty) {
      return generateSvgLabelPdf(
        batch: batch,
        container: container,
        template: template,
        yeastName: yeastName,
      );
    }

    // Иначе рендерим стандартную верстку
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

    // Формирование заглавия
    final displayTitle = container != null
        ? '${batch.name} • ${container.title}'
        : batch.name;

    // Расчётная сладость (с учетом подпартии, декстрозы и несбраживаемых сахаров)
    final baseSugar = batch.finalSugarWithPriming ?? batch.finalSugar ?? 0.0;
    final calculatedSugar = container != null
        ? container.getCalculatedFinalSugar(baseSugar)
        : baseSugar;
    final sugarText = '${calculatedSugar.toStringAsFixed(1)} г/100мл';

    // Инфо по таре
    final containerInfo = container != null
        ? '${container.containerType} ${container.containerVolumeLiters}л'
        : null;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
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
                // Название партии / подпартии
                pw.Text(
                  displayTitle,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                ),
                pw.Divider(thickness: 0.5),

                // Характеристики
                pw.Text(
                  'Сорт: ${batch.appleVariety}',
                  style: const pw.TextStyle(fontSize: 7),
                ),
                if (containerInfo != null)
                  pw.Text(
                    'Тара: $containerInfo',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                pw.Text(
                  'Дата: $formattedDate',
                  style: const pw.TextStyle(fontSize: 7),
                ),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Крепость: ${batch.finalAlcohol ?? 0}% об.',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 7,
                      ),
                    ),
                    pw.Text(
                      'Сладость: $sugarText',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 7,
                      ),
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

/// Генерация PDF из SVG с масштабированием на весь размер этикетки
  static Future<Uint8List> generateSvgLabelPdf({
    required Batch batch,
    BatchContainer? container,
    required LabelTemplate template,
    String? yeastName,
  }) async {
    final pdf = pw.Document();

    final selectedContainer = container ??
        BatchContainer(
          id: '',
          batchId: batch.id,
          title: 'Основная партия',
          containerType: 'Бутылка',
          containerVolumeLiters: 0.5,
          count: 1,
        );

    // 1. Подстановка данных
    final processedSvg = SvgLabelProcessor.injectData(
      rawSvg: template.svgContent ?? '',
      batch: batch,
      container: selectedContainer,
      yeastName: yeastName,
    );

    // 2. Размеры в поинтах PDF
    final widthPt = template.widthMm * PdfPageFormat.mm;
    final heightPt = template.heightMm * PdfPageFormat.mm;

    // 3. Загрузка SVG структуры
    final PictureInfo pictureInfo = await vg.loadPicture(
      SvgStringLoader(processedSvg),
      null,
    );

    // 4. Расчет масштабного коэффициента (scale) под целевое разрешение (300 DPI)
    const double targetDpi = 300.0;
    final double pixelWidth = widthPt * (targetDpi / 72.0);
    final double pixelHeight = heightPt * (targetDpi / 72.0);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    final double rawWidth = pictureInfo.size.width > 0 ? pictureInfo.size.width : widthPt;
    final double rawHeight = pictureInfo.size.height > 0 ? pictureInfo.size.height : heightPt;

    final double scaleX = pixelWidth / rawWidth;
    final double scaleY = pixelHeight / rawHeight;

    canvas.scale(scaleX, scaleY);
    canvas.drawPicture(pictureInfo.picture);

    final ui.Picture scaledPicture = recorder.endRecording();
    final ui.Image image = await scaledPicture.toImage(
      pixelWidth.round(),
      pixelHeight.round(),
    );

    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw Exception('Ошибка при сжатии и конвертации SVG этикетки');
    }

    final pdfImage = pw.MemoryImage(bytes.buffer.asUint8List());

    // 5. Создание страницы точно по размеру этикетки
    final pageFormat = PdfPageFormat(
      widthPt,
      heightPt,
      marginAll: 0,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(pdfImage, fit: pw.BoxFit.fill),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Открыть системное окно печати / сохранения с правильным форматом страницы
  static Future<void> printOrSaveLabel({
    required Batch batch,
    BatchContainer? container,
    required LabelTemplate template,
    String? yeastName,
  }) async {
    final pdfData = await generateLabelPdf(
      batch: batch,
      container: container,
      template: template,
      yeastName: yeastName,
    );

    final widthPt = template.widthMm * PdfPageFormat.mm;
    final heightPt = template.heightMm * PdfPageFormat.mm;
    final labelFormat = PdfPageFormat(widthPt, heightPt, marginAll: 0);

    final sanitizeName = batch.name.replaceAll(RegExp(r'[^\w\s\-]'), '_');

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: 'Этикетка_$sanitizeName.pdf',
      format: labelFormat, // Фиксирует размер печати по размеру этикетки, а не A4
    );
  }
}