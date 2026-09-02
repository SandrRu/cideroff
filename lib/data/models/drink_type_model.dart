import 'package:uuid/uuid.dart';

class DrinkType {
  final String id;
  final String name;
  final double minSugarGramsPerLiter;
  final double maxSugarGramsPerLiter;
  final bool isCustom;

  DrinkType({
    String? id,
    required this.name,
    required this.minSugarGramsPerLiter,
    required this.maxSugarGramsPerLiter,
    this.isCustom = false,
  }) : id = id ?? const Uuid().v4();

  DrinkType copyWith({
    String? id,
    String? name,
    double? minSugarGramsPerLiter,
    double? maxSugarGramsPerLiter,
    bool? isCustom,
  }) {
    return DrinkType(
      id: id ?? this.id,
      name: name ?? this.name,
      minSugarGramsPerLiter: minSugarGramsPerLiter ?? this.minSugarGramsPerLiter,
      maxSugarGramsPerLiter: maxSugarGramsPerLiter ?? this.maxSugarGramsPerLiter,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'minSugarGramsPerLiter': minSugarGramsPerLiter,
        'maxSugarGramsPerLiter': maxSugarGramsPerLiter,
        'isCustom': isCustom ? 1 : 0,
      };

  factory DrinkType.fromJson(Map<String, dynamic> json) => DrinkType(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        minSugarGramsPerLiter: (json['minSugarGramsPerLiter'] as num?)?.toDouble() ?? 0.0,
        maxSugarGramsPerLiter: (json['maxSugarGramsPerLiter'] as num?)?.toDouble() ?? 0.0,
        isCustom: (json['isCustom'] as int? ?? 0) == 1,
      );
}