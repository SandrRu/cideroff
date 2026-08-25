import 'package:uuid/uuid.dart';

class LabelTemplate {
  final String id;
  final String name;
  final double widthMm;
  final double heightMm;
  final String schemaJson; // Конфигурация размещения блоков на этикетке

  LabelTemplate({
    String? id,
    required this.name,
    this.widthMm = 58.0,
    this.heightMm = 40.0,
    required this.schemaJson,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'schemaJson': schemaJson,
      };

  factory LabelTemplate.fromJson(Map<String, dynamic> json) => LabelTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        widthMm: (json['widthMm'] as num).toDouble(),
        heightMm: (json['heightMm'] as num).toDouble(),
        schemaJson: json['schemaJson'] as String,
      );
}