import 'package:intl/intl.dart';
import '../data/models/batch_model.dart';

class LabelSvgProcessor {
  /// Заменяет плейсхолдеры и подменяет font-family на стандартный векторный шрифт
  static String processSvgTemplate(String svgRaw, Batch batch) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    final calculatedSugar = batch.finalSugarWithPriming ?? batch.finalSugar ?? 0.0;
    final abvValue = batch.finalAlcohol ?? 0.0;
    final primingGrams = batch.primingSugarGrams ?? 0.0;

    final map = <String, String>{
      'BATCH_NAME': batch.name,
      'APPLE_VARIETY': batch.appleVariety,
      'PRESS_DATE': dateFormat.format(batch.pressDate),
      'BOTTLING_DATE': dateFormat.format(DateTime.now()),
      'INITIAL_SUGAR': '${batch.initialSugar.toStringAsFixed(1)} г/100мл',
      'FINAL_SUGAR': '${calculatedSugar.toStringAsFixed(1)} г/100мл',
      'ABV': '${abvValue.toStringAsFixed(1)}%',
      'PRIMING_SUGAR': '${primingGrams.toStringAsFixed(1)} г/л',
      'CONTAINER_TYPE': batch.containerType ?? 'Бутылка',
      'NOTES': batch.notes,
    };

    String result = svgRaw;

    // 1. Замена плейсхолдеров
    map.forEach((key, value) {
      final pattern = RegExp(r'\{\{\s*' + key + r'\s*\}\}', caseSensitive: false);
      result = result.replaceAll(pattern, value);
    });

    return result;
  }
}