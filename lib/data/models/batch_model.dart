import 'package:uuid/uuid.dart';

enum BatchStatus {
  inProgress,
  completed,
  archived;

  String toJson() => name;
  static BatchStatus fromJson(String json) =>
      BatchStatus.values.firstWhere((e) => e.name == json, orElse: () => BatchStatus.inProgress);
}

enum BatchType {
  cider,
  calvados;

  String toJson() => name;
  static BatchType fromJson(String json) =>
      BatchType.values.firstWhere((e) => e.name == json, orElse: () => BatchType.cider);
}

class Batch {
  final String id;
  final String name;
  final String appleVariety;
  final double initialSugar; // г/100мл
  final double juiceVolume;   // литры
  final DateTime pressDate;
  final BatchStatus status;
  final BatchType type;      // Тип партии: Сидр или Кальвадос
  
  final String? currentRecipeId;
  final int? currentStepIndex;
  final DateTime? nextStepDate;
  
  // Данные розлива
  final String? containerType;
  final int? containerCount;
  final double? finalSugar;
  final double? finalAlcohol;
  final double? primingSugarGrams;        // Катализатор / Декстроза (г/л)
  final double? nonFermentableSugarGrams; // Несбраживаемые сахара (ксилит, эритрит и т.д.), г/л
  final double? finalSugarWithPriming;    // Расчётная сладость / Итоговый сахар (г/100мл)
  final String notes;

  // --- Поля Кальвадоса (Дистилляция и Выдержка) ---
  final double? rawSpiritVolume;  // Объем спирта-сырца (л)
  final double? rawSpiritABV;     // Крепость спирта-сырца (% об.)
  final double? distillateVolume; // Объем "сердца" / дистиллята (л)
  final double? distillateABV;    // Крепость дистиллята (% об.)
  final double? barrelDilutedABV; // Крепость при заливке в бочку (% об.)
  final DateTime? agingStartDate; // Дата начала выдержки
  final String? barrelNotes;      // Объем бочки, обжиг или парам. щепы

  Batch({
    String? id,
    required this.name,
    required this.appleVariety,
    required this.initialSugar,
    required this.juiceVolume,
    required this.pressDate,
    this.status = BatchStatus.inProgress,
    this.type = BatchType.cider,
    this.currentRecipeId,
    this.currentStepIndex,
    this.nextStepDate,
    this.containerType,
    this.containerCount,
    this.finalSugar,
    this.finalAlcohol,
    this.primingSugarGrams,
    this.nonFermentableSugarGrams,
    this.finalSugarWithPriming,
    this.notes = '',
    this.rawSpiritVolume,
    this.rawSpiritABV,
    this.distillateVolume,
    this.distillateABV,
    this.barrelDilutedABV,
    this.agingStartDate,
    this.barrelNotes,
  }) : id = id ?? const Uuid().v4();

  /// Сколько дней осталось до следующего шага
  int? get daysUntilNextStep {
    if (nextStepDate == null) return null;
    final diff = nextStepDate!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Дней в бочке / на выдержке (для Кальвадоса)
  int? get daysInAging {
    if (agingStartDate == null) return null;
    return DateTime.now().difference(agingStartDate!).inDays;
  }

  /// Название текущего/следующего шага
  String? get currentStepTitle => notes.isNotEmpty ? notes : null;

  Batch copyWith({
    String? id,
    String? name,
    String? appleVariety,
    double? initialSugar,
    double? juiceVolume,
    DateTime? pressDate,
    BatchStatus? status,
    BatchType? type,
    String? currentRecipeId,
    int? currentStepIndex,
    DateTime? nextStepDate,
    String? containerType,
    int? containerCount,
    double? finalSugar,
    double? finalAlcohol,
    double? primingSugarGrams,
    double? nonFermentableSugarGrams,
    double? finalSugarWithPriming,
    String? notes,
    double? rawSpiritVolume,
    double? rawSpiritABV,
    double? distillateVolume,
    double? distillateABV,
    double? barrelDilutedABV,
    DateTime? agingStartDate,
    String? barrelNotes,
  }) {
    return Batch(
      id: id ?? this.id,
      name: name ?? this.name,
      appleVariety: appleVariety ?? this.appleVariety,
      initialSugar: initialSugar ?? this.initialSugar,
      juiceVolume: juiceVolume ?? this.juiceVolume,
      pressDate: pressDate ?? this.pressDate,
      status: status ?? this.status,
      type: type ?? this.type,
      currentRecipeId: currentRecipeId ?? this.currentRecipeId,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      nextStepDate: nextStepDate ?? this.nextStepDate,
      containerType: containerType ?? this.containerType,
      containerCount: containerCount ?? this.containerCount,
      finalSugar: finalSugar ?? this.finalSugar,
      finalAlcohol: finalAlcohol ?? this.finalAlcohol,
      primingSugarGrams: primingSugarGrams ?? this.primingSugarGrams,
      nonFermentableSugarGrams: nonFermentableSugarGrams ?? this.nonFermentableSugarGrams,
      finalSugarWithPriming: finalSugarWithPriming ?? this.finalSugarWithPriming,
      notes: notes ?? this.notes,
      rawSpiritVolume: rawSpiritVolume ?? this.rawSpiritVolume,
      rawSpiritABV: rawSpiritABV ?? this.rawSpiritABV,
      distillateVolume: distillateVolume ?? this.distillateVolume,
      distillateABV: distillateABV ?? this.distillateABV,
      barrelDilutedABV: barrelDilutedABV ?? this.barrelDilutedABV,
      agingStartDate: agingStartDate ?? this.agingStartDate,
      barrelNotes: barrelNotes ?? this.barrelNotes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'appleVariety': appleVariety,
        'initialSugar': initialSugar,
        'juiceVolume': juiceVolume,
        'pressDate': pressDate.toIso8601String(),
        'status': status.toJson(),
        'type': type.toJson(),
        'currentRecipeId': currentRecipeId,
        'currentStepIndex': currentStepIndex,
        'nextStepDate': nextStepDate?.toIso8601String(),
        'containerType': containerType,
        'containerCount': containerCount,
        'finalSugar': finalSugar,
        'finalAlcohol': finalAlcohol,
        'primingSugarGrams': primingSugarGrams,
        'nonFermentableSugarGrams': nonFermentableSugarGrams,
        'finalSugarWithPriming': finalSugarWithPriming,
        'notes': notes,
        'rawSpiritVolume': rawSpiritVolume,
        'rawSpiritABV': rawSpiritABV,
        'distillateVolume': distillateVolume,
        'distillateABV': distillateABV,
        'barrelDilutedABV': barrelDilutedABV,
        'agingStartDate': agingStartDate?.toIso8601String(),
        'barrelNotes': barrelNotes,
      };

  factory Batch.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    return Batch(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Партия',
      appleVariety: json['appleVariety'] as String? ?? 'Смешанные',
      initialSugar: (json['initialSugar'] as num?)?.toDouble() ?? 0.0,
      juiceVolume: (json['juiceVolume'] as num?)?.toDouble() ?? 0.0,
      pressDate: parseDate(json['pressDate']),
      status: BatchStatus.fromJson(json['status'] as String? ?? 'inProgress'),
      type: BatchType.fromJson(json['type'] as String? ?? 'cider'),
      currentRecipeId: json['currentRecipeId'] as String?,
      currentStepIndex: json['currentStepIndex'] as int?,
      nextStepDate: parseNullableDate(json['nextStepDate']),
      containerType: json['containerType'] as String?,
      containerCount: json['containerCount'] as int?,
      finalSugar: (json['finalSugar'] as num?)?.toDouble(),
      finalAlcohol: (json['finalAlcohol'] as num?)?.toDouble(),
      primingSugarGrams: (json['primingSugarGrams'] as num?)?.toDouble(),
      nonFermentableSugarGrams: (json['nonFermentableSugarGrams'] as num?)?.toDouble(),
      finalSugarWithPriming: (json['finalSugarWithPriming'] as num?)?.toDouble(),
      notes: json['notes'] as String? ?? '',
      rawSpiritVolume: (json['rawSpiritVolume'] as num?)?.toDouble(),
      rawSpiritABV: (json['rawSpiritABV'] as num?)?.toDouble(),
      distillateVolume: (json['distillateVolume'] as num?)?.toDouble(),
      distillateABV: (json['distillateABV'] as num?)?.toDouble(),
      barrelDilutedABV: (json['barrelDilutedABV'] as num?)?.toDouble(),
      agingStartDate: parseNullableDate(json['agingStartDate']),
      barrelNotes: json['barrelNotes'] as String?,
    );
  }

  /// Расчётная итоговая сладость с учётом остаточного сахара и несбраживаемых сахаров
  double? get calculatedFinalSweetness {
    if (finalSugarWithPriming != null) return finalSugarWithPriming;
    if (finalSugar != null) {
      final nonFerm = nonFermentableSugarGrams ?? 0.0;
      return finalSugar! + (nonFerm / 10.0);
    }
    return null;
  }
}