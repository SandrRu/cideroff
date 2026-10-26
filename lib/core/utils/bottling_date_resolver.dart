// lib/core/utils/bottling_date_resolver.dart
import '../../data/datasources/database_service.dart';
import '../../data/models/batch_history_model.dart';
import '../../data/models/batch_model.dart';

/// Определяет фактическую дату розлива партии.
///
/// Отдельного поля "дата розлива" в модели нет, поэтому дата берётся из
/// истории партии по приоритету:
///  1. последнее событие розлива (в нём есть тара либо в названии шага/действия
///     встречается "розлив") — это и есть настоящая дата розлива;
///  2. последнее событие завершённой партии (финальный шаг = розлив);
///  3. плановая дата следующего шага — для партий в процессе;
///  4. дата отжима — крайний случай, когда истории вообще нет.
class BottlingDateResolver {
  const BottlingDateResolver._();

  static Future<DateTime> resolve(Batch batch) async {
    return fromHistory(batch, await _loadHistory(batch.id));
  }

  /// Синхронный расчёт по уже загруженной истории.
  /// [history] ожидается в порядке убывания [BatchHistory.timestamp],
  /// как его отдаёт DatabaseService.getHistoryForBatch.
  static DateTime fromHistory(Batch batch, List<BatchHistory> history) {
    for (final entry in history) {
      if (isBottlingEvent(entry)) return entry.timestamp;
    }

    if (history.isNotEmpty && batch.status != BatchStatus.inProgress) {
      return history.first.timestamp;
    }

    return batch.nextStepDate ?? batch.pressDate;
  }

  /// Событие истории относится к розливу?
  static bool isBottlingEvent(BatchHistory entry) {
    if (entry.containers.isNotEmpty) return true;
    final action = entry.actionName.toLowerCase();
    final step = entry.stepTitle.toLowerCase();
    return action.contains('розлив') ||
        action.contains('завершение') ||
        step.contains('розлив');
  }

  static Future<List<BatchHistory>> _loadHistory(String batchId) async {
    try {
      return await DatabaseService.instance.getHistoryForBatch(batchId);
    } catch (_) {
      // Без истории этикетка всё равно должна печататься.
      return const <BatchHistory>[];
    }
  }
}
