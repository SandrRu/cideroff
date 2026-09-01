import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'batch_container_model.dart';

class BatchHistory {
  final String id;
  final String batchId;
  final DateTime timestamp;
  final String stepTitle;
  final String actionName;
  final double? sugarMeasured;
  final double? alcoholMeasured;
  final double? nonFermentableSugarGrams;
  final List<BatchContainer> containers;
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
    this.containers = const [],
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
        'containers': jsonEncode(containers.map((c) => c.toJson()).toList()),
        'note': note,
      };

  factory BatchHistory.fromJson(Map<String, dynamic> json) {
    List<BatchContainer> parsedContainers = const [];

    if (json['containers'] != null) {
      if (json['containers'] is String && (json['containers'] as String).isNotEmpty) {
        try {
          final List dynamicList = jsonDecode(json['containers'] as String);
          parsedContainers = dynamicList
              .map((c) => BatchContainer.fromJson(c as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      } else if (json['containers'] is List) {
        parsedContainers = (json['containers'] as List)
            .map((c) => BatchContainer.fromJson(c as Map<String, dynamic>))
            .toList();
      }
    }

    return BatchHistory(
      id: json['id'] as String,
      batchId: json['batchId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      stepTitle: json['stepTitle'] as String,
      actionName: json['actionName'] as String,
      sugarMeasured: (json['sugarMeasured'] as num?)?.toDouble(),
      alcoholMeasured: (json['alcoholMeasured'] as num?)?.toDouble(),
      nonFermentableSugarGrams: (json['nonFermentableSugarGrams'] as num?)?.toDouble(),
      containers: parsedContainers,
      note: json['note'] as String?,
    );
  }
}