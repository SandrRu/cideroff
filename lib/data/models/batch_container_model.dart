import 'package:uuid/uuid.dart';

class BatchContainer {
  final String id;
  final String batchId;
  final String title;                    // Название подпартии / тары (напр. "Сухой бугель", "Сладкий кег")
  final String? sweetenerType;            // Тип подсластителя (Ксилит, Эритрит, Сорбитол, Сок и т.д.)
  final double sweetenerAmountGramsPerLiter; // Количество подсластителя (г/л)
  final String containerType;            // Тип тары (Бугель, Кронен, ПЭТ, Кег)
  final double containerVolumeLiters;    // Объем одной емкости (л)
  final int count;                       // Количество емкостей (шт)

  BatchContainer({
    String? id,
    required this.batchId,
    required this.title,
    this.sweetenerType,
    this.sweetenerAmountGramsPerLiter = 0.0,
    required this.containerType,
    required this.containerVolumeLiters,
    required this.count,
  }) : id = id ?? const Uuid().v4();

  /// Общий объем всей подпартии в литрах
  double get totalVolumeLiters => containerVolumeLiters * count;

  /// Добавленная сладость от подсластителя в г/100мл
  double get addedSweetnessGrams100ml => sweetenerAmountGramsPerLiter / 10.0;

  /// Итоговый расчетный сахар подпартии (Базовый сахар партии + Добавленная сладость)
  double getCalculatedFinalSugar(double baseFinalSugar) {
    return baseFinalSugar + addedSweetnessGrams100ml;
  }

  BatchContainer copyWith({
    String? id,
    String? batchId,
    String? title,
    String? sweetenerType,
    double? sweetenerAmountGramsPerLiter,
    String? containerType,
    double? containerVolumeLiters,
    int? count,
  }) {
    return BatchContainer(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      title: title ?? this.title,
      sweetenerType: sweetenerType ?? this.sweetenerType,
      sweetenerAmountGramsPerLiter:
          sweetenerAmountGramsPerLiter ?? this.sweetenerAmountGramsPerLiter,
      containerType: containerType ?? this.containerType,
      containerVolumeLiters:
          containerVolumeLiters ?? this.containerVolumeLiters,
      count: count ?? this.count,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'batchId': batchId,
        'title': title,
        'sweetenerType': sweetenerType,
        'sweetenerAmountGramsPerLiter': sweetenerAmountGramsPerLiter,
        'containerType': containerType,
        'containerVolumeLiters': containerVolumeLiters,
        'count': count,
      };

  factory BatchContainer.fromJson(Map<String, dynamic> json) => BatchContainer(
        id: json['id'] as String? ?? const Uuid().v4(),
        batchId: json['batchId'] as String? ?? '',
        title: json['title'] as String? ?? 'Тара',
        sweetenerType: json['sweetenerType'] as String?,
        sweetenerAmountGramsPerLiter:
            (json['sweetenerAmountGramsPerLiter'] as num?)?.toDouble() ?? 0.0,
        containerType: json['containerType'] as String? ?? 'Бутылка',
        containerVolumeLiters:
            (json['containerVolumeLiters'] as num?)?.toDouble() ?? 0.75,
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}