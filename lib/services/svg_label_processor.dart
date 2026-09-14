// lib/services/svg_label_processor.dart
import 'package:intl/intl.dart';
import '../data/models/batch_model.dart';
import '../data/models/batch_container_model.dart';

class SvgLabelProcessor {
  static String injectData({
    required String rawSvg,
    required Batch batch,
    required BatchContainer container,
    String? yeastName,
  }) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    
    // Расчет параметров подпартии
    final finalSugar = container.getCalculatedFinalSugar(batch.finalSugar ?? 0.0);
    final abvText = batch.finalAlcohol != null ? '${batch.finalAlcohol!.toStringAsFixed(1)}%' : '0.0%';
    
    String sweetenerInfo = 'Без подсластителя';
    if (container.sweetenerType != null && container.sweetenerAmountGramsPerLiter > 0) {
      sweetenerInfo = '${container.sweetenerType}: ${container.sweetenerAmountGramsPerLiter} г/л';
    }

    final formattedPressDate = dateFormat.format(batch.pressDate);
    final formattedBottlingDate = dateFormat.format(DateTime.now());
    final sugarText = '${finalSugar.toStringAsFixed(1)} г/100мл';
    final notesText = batch.notes ?? '';
    final yeast = yeastName ?? '—';

    // Расширенная карта замен (поддерживает ВСЕ вариации регистра и названий)
    final Map<String, String> replacements = {
      // Имя партии
      '{{batch_name}}': batch.name,
      '{{BATCH_NAME}}': batch.name,
      '{{BATCH NAME}}': batch.name,
      '{batch_name}': batch.name,

      // Сорт яблок
      '{{apple_variety}}': batch.appleVariety,
      '{{APPLE_VARIETY}}': batch.appleVariety,
      '{{APPLE VARIETY}}': batch.appleVariety,
      '{apple_variety}': batch.appleVariety,

      // Даты
      '{{press_date}}': formattedPressDate,
      '{{PRESS_DATE}}': formattedPressDate,
      '{{bottling_date}}': formattedBottlingDate,
      '{{BOTTLING_DATE}}': formattedBottlingDate,
      '{{BOTTLING DATE}}': formattedBottlingDate,

      // Крепость и Сахар
      '{{abv}}': abvText,
      '{{ABV}}': abvText,
      '{{sugar}}': sugarText,
      '{{SUGAR}}': sugarText,
      '{{final_sugar}}': sugarText,
      '{{FINAL_SUGAR}}': sugarText,
      '{{FINAL SUGAR}}': sugarText,

      // Заметки / Описание
      '{{notes}}': notesText,
      '{{NOTES}}': notesText,
      '{{description}}': notesText,

      // Дрожжи
      '{{yeast_name}}': yeast,
      '{{YEAST_NAME}}': yeast,
      '{{YEAST NAME}}': yeast,
      '{yeast_name}': yeast,

      // Тара и Подсластитель
      '{{container_title}}': container.title,
      '{{CONTAINER_TITLE}}': container.title,
      '{{container_type}}': container.containerType,
      '{{CONTAINER_TYPE}}': container.containerType,
      '{{sweetener}}': sweetenerInfo,
      '{{SWEETENER}}': sweetenerInfo,
      '{{batch_id}}': batch.id,
      '{{BATCH_ID}}': batch.id,
    };

    // 1. Предварительная нормализация: вычищаем разрывающие XML-теги и лишние пробелы из плейсхолдеров
    String processedSvg = _normalizePlaceholdersInSvg(rawSvg);

    // 2. Безопасная замена плейсхолдеров с экранированием XML
    replacements.forEach((key, value) {
      processedSvg = processedSvg.replaceAll(key, _escapeXml(value));
    });

    return processedSvg;
  }

  /// Находит плейсхолдеры {{...}}, которые разбиты <tspan> или содержат лишние пробелы/переносы
  static String _normalizePlaceholdersInSvg(String svgContent) {
    // Регулярное выражение для поиска всех фигурных скобок {{ ... }}
    final brokenPlaceholderRegex = RegExp(
      r'\{\{[\s\S]*?\}\}',
      multiLine: true,
    );

    return svgContent.replaceAllMapped(brokenPlaceholderRegex, (match) {
      String matchedText = match.group(0)!;

      // Удаляем теги tspan/xml внутри фигурных скобок
      matchedText = matchedText.replaceAll(RegExp(r'</?[^>]+>', caseSensitive: false), '');
      
      // Нормализуем пробельные символы внутри {{ ... }} до одного пробела
      matchedText = matchedText.replaceAll(RegExp(r'\s+'), ' ');

      return matchedText;
    });
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}