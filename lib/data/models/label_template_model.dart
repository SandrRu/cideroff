// lib/data/models/label_template_model.dart
import 'package:uuid/uuid.dart';

class LabelTemplate {
  final String id;
  final String name;
  final double widthMm;
  final double heightMm;
  final String schemaJson; // Оставляем для обратной совместимости со старыми координатами
  final String? svgContent; // Хранение исходного SVG кода
  final bool isCustomSvg;   // Флаг: кастомный SVG или стандартный макет

  LabelTemplate({
    String? id,
    required this.name,
    this.widthMm = 58.0,
    this.heightMm = 40.0,
    this.schemaJson = '{}',
    this.svgContent,
    this.isCustomSvg = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'schemaJson': schemaJson,
        'svgContent': svgContent,
        'isCustomSvg': isCustomSvg ? 1 : 0,
      };

  factory LabelTemplate.fromJson(Map<String, dynamic> json) => LabelTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        widthMm: (json['widthMm'] as num).toDouble(),
        heightMm: (json['heightMm'] as num).toDouble(),
        schemaJson: json['schemaJson'] as String? ?? '{}',
        svgContent: json['svgContent'] as String?,
        isCustomSvg: (json['isCustomSvg'] as int? ?? 0) == 1,
      );
}