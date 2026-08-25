import 'package:uuid/uuid.dart';

class BatchHistory {
  final String id;
  final String batchId;
  final DateTime timestamp;
  final String stepTitle;
  final String actionName;
  final double? sugarMeasured;
  final double? alcoholMeasured;
  final double? nonFermentableSugarGrams; // <-- Добавлено поле
  final String? note;

  BatchHistory({
    String? id,
    required this.batchId,
    required this.timestamp,
    required this.stepTitle,
    required this.actionName,
    this.sugarMeasured,
    this.alcoholMeasured,
    this.nonFermentableSugarGrams,
    this.note,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'batchId': batchId,
        'timestamp': timestamp.toIso8601String(),
        'stepTitle': stepTitle,
        'actionName': actionName,
        'sugarMeasured': sugarMeasured,
        'alcoholMeasured': alcoholMeasured,
        'nonFermentableSugarGrams': nonFermentableSugarGrams,
        'note': note,
      };

  factory BatchHistory.fromJson(Map<String, dynamic> json) => BatchHistory(
        id: json['id'] as String,
        batchId: json['batchId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        stepTitle: json['stepTitle'] as String,
        actionName: json['actionName'] as String,
        sugarMeasured: (json['sugarMeasured'] as num?)?.toDouble(),
        alcoholMeasured: (json['alcoholMeasured'] as num?)?.toDouble(),
        nonFermentableSugarGrams: (json['nonFermentableSugarGrams'] as num?)?.toDouble(),
        note: json['note'] as String?,
      );
}