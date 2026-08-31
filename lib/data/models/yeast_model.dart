import 'package:uuid/uuid.dart';

class Yeast {
  final String id;
  final String name;
  final String category; // 'Cider', 'Calvados', 'Universal', etc.
  final String description;
  final bool isCustom;

  Yeast({
    String? id,
    required this.name,
    required this.category,
    this.description = '',
    this.isCustom = true,
  }) : id = id ?? const Uuid().v4();

  Yeast copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    bool? isCustom,
  }) {
    return Yeast(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'isCustom': isCustom ? 1 : 0,
      };

  factory Yeast.fromJson(Map<String, dynamic> json) => Yeast(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'Cider',
        description: json['description'] as String? ?? '',
        isCustom: (json['isCustom'] as int? ?? 1) == 1,
      );
}