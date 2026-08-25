import 'package:uuid/uuid.dart';

class RecipeStep {
  final int stepIndex;
  final Map<String, String> title;
  final Map<String, String> instruction;
  final int durationDays;
  final bool requiresSugarMeasurement;
  final bool requiresAlcoholMeasurement;
  final bool isBottlingStep;

  RecipeStep({
    required this.stepIndex,
    required this.title,
    required this.instruction,
    required this.durationDays,
    this.requiresSugarMeasurement = false,
    this.requiresAlcoholMeasurement = false,
    this.isBottlingStep = false,
  });

  /// Получение заголовка на указанном языке (с фолбэком на 'ru' или 'en')
  String getTitle(String langCode) {
    return title[langCode] ?? title['ru'] ?? title['en'] ?? '';
  }

  /// Получение инструкции на указанном языке
  String getInstruction(String langCode) {
    return instruction[langCode] ?? instruction['ru'] ?? instruction['en'] ?? '';
  }

  Map<String, dynamic> toJson() => {
        'stepIndex': stepIndex,
        'title': title,
        'instruction': instruction,
        'durationDays': durationDays,
        'requiresSugarMeasurement': requiresSugarMeasurement,
        'requiresAlcoholMeasurement': requiresAlcoholMeasurement,
        'isBottlingStep': isBottlingStep,
      };

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
        stepIndex: json['stepIndex'] as int,
        title: Map<String, String>.from(json['title'] as Map),
        instruction: Map<String, String>.from(json['instruction'] as Map),
        durationDays: json['durationDays'] as int,
        requiresSugarMeasurement: json['requiresSugarMeasurement'] as bool? ?? false,
        requiresAlcoholMeasurement: json['requiresAlcoholMeasurement'] as bool? ?? false,
        isBottlingStep: json['isBottlingStep'] as bool? ?? false,
      );
}

class Recipe {
  final String id;
  final Map<String, String> title;
  final Map<String, String> description;
  final bool isCustom;
  final bool isFavorite;
  final List<RecipeStep> steps;

  Recipe({
    String? id,
    required this.title,
    required this.description,
    this.isCustom = true,
    this.isFavorite = false,
    required this.steps,
  }) : id = id ?? const Uuid().v4();

  String getTitle(String langCode) {
    return title[langCode] ?? title['ru'] ?? title['en'] ?? '';
  }

  String getDescription(String langCode) {
    return description[langCode] ?? description['ru'] ?? description['en'] ?? '';
  }

  Recipe copyWith({
    String? id,
    Map<String, String>? title,
    Map<String, String>? description,
    bool? isCustom,
    bool? isFavorite,
    List<RecipeStep>? steps,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCustom: isCustom ?? this.isCustom,
      isFavorite: isFavorite ?? this.isFavorite,
      steps: steps ?? this.steps,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'isCustom': isCustom,
        'isFavorite': isFavorite,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        title: Map<String, String>.from(json['title'] ?? {}),
        description: Map<String, String>.from(json['description'] ?? {}),
        isCustom: json['isCustom'] as bool? ?? true,
        isFavorite: json['isFavorite'] as bool? ?? false,
        steps: (json['steps'] as List)
            .map((s) => RecipeStep.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}