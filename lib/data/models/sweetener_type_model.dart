import 'package:uuid/uuid.dart';

class SweetenerType {
  final String id;
  final String name;
  final double sweetnessFactor; // Коэффициент относительно сахара (например, ксилит ~1.0, эритрит ~0.7)
  final bool isCustom;

  SweetenerType({
    String? id,
    required this.name,
    this.sweetnessFactor = 1.0,
    this.isCustom = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sweetnessFactor': sweetnessFactor,
        'isCustom': isCustom ? 1 : 0,
      };

  factory SweetenerType.fromJson(Map<String, dynamic> json) => SweetenerType(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        sweetnessFactor: (json['sweetnessFactor'] as num?)?.toDouble() ?? 1.0,
        isCustom: (json['isCustom'] as int? ?? 0) == 1,
      );
}