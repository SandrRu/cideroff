import 'package:flutter/material.dart';
import '../../data/datasources/database_service.dart';
import '../../data/models/batch_model.dart';
import '../../data/models/batch_history_model.dart';
import '../../data/models/recipe_model.dart';
import '../../services/notification_service.dart';
import '../../services/calendar_service.dart';

class BatchProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final NotificationService _notifications = NotificationService.instance;
  final CalendarService _calendar = CalendarService();

  List<Batch> _batches = [];
  bool _isLoading = false;

  List<Batch> get batches => _batches;
  List<Batch> get inProgressBatches =>
      _batches.where((b) => b.status == BatchStatus.inProgress).toList();
  List<Batch> get completedBatches =>
      _batches.where((b) => b.status == BatchStatus.completed).toList();
  bool get isLoading => _isLoading;

  Future<void> loadBatches() async {
    _isLoading = true;
    notifyListeners();
    _batches = await _db.getAllBatches();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createBatch({
    required String name,
    required String appleVariety,
    required double initialSugar,
    required double juiceVolume,
    required DateTime pressDate,
    required Recipe recipe,
    String notes = '',
    BatchType type = BatchType.cider,
    double? rawSpiritVolume,
    double? rawSpiritAbv,
    String? barrelNotes,
  }) async {
    final firstStep = recipe.steps.isNotEmpty ? recipe.steps.first : null;
    final nextDate = firstStep != null
        ? pressDate.add(Duration(days: firstStep.durationDays))
        : null;

    final batch = Batch(
      name: name,
      appleVariety: appleVariety,
      initialSugar: initialSugar,
      juiceVolume: juiceVolume,
      pressDate: pressDate,
      currentRecipeId: recipe.id,
      currentStepIndex: 0,
      nextStepDate: nextDate,
      notes: notes,
      type: type,
      rawSpiritVolume: rawSpiritVolume,
      rawSpiritABV: rawSpiritAbv,
      barrelNotes: barrelNotes,
      agingStartDate: type == BatchType.calvados ? pressDate : null,
    );

    await _db.insertBatch(batch);

    final history = BatchHistory(
      batchId: batch.id,
      timestamp: pressDate,
      stepTitle: firstStep?.getTitle('ru') ?? 'Запуск партии',
      actionName: 'Партия создана по рецепту "${recipe.getTitle('ru')}" (${type == BatchType.calvados ? 'Кальвадос' : 'Сидр'})',
      sugarMeasured: initialSugar,
      note: notes,
    );
    await _db.insertHistory(history);

    if (nextDate != null && firstStep != null) {
      await _scheduleReminders(batch, firstStep, nextDate);
    }

    await loadBatches();
  }

  Future<void> completeCurrentStep({
    required Batch batch,
    required Recipe recipe,
    double? sugarMeasured,
    double? alcoholMeasured,
    String? note,
    String? containerType,
    int? containerCount,
    DateTime? stepDate,
    double? primingSugarGrams,
    double? nonFermentableSugarGrams,
    double? finalSugarWithPriming,
  }) async {
    final currentIndex = batch.currentStepIndex ?? 0;
    if (currentIndex >= recipe.steps.length) return;

    final currentStep = recipe.steps[currentIndex];
    final executionDate = stepDate ?? DateTime.now();

    final history = BatchHistory(
      batchId: batch.id,
      timestamp: executionDate,
      stepTitle: currentStep.getTitle('ru'),
      actionName: 'Шаг выполнен',
      sugarMeasured: sugarMeasured,
      alcoholMeasured: alcoholMeasured,
      nonFermentableSugarGrams: nonFermentableSugarGrams, // <-- Передаем несбраживаемые сахара
      note: note,
    );
    await _db.insertHistory(history);

    final isLastStep = currentIndex >= recipe.steps.length - 1;
    final hasNextStep = !isLastStep;
    final nextStep = hasNextStep ? recipe.steps[currentIndex + 1] : null;
    final nextDate = (nextStep != null)
        ? executionDate.add(Duration(days: nextStep.durationDays))
        : null;

    if (isLastStep || currentStep.isBottlingStep) {
      final updatedBatch = batch.copyWith(
        status: isLastStep ? BatchStatus.completed : BatchStatus.inProgress,
        currentStepIndex: isLastStep ? null : currentIndex + 1,
        nextStepDate: isLastStep ? null : nextDate,
        containerType: containerType,
        containerCount: containerCount,
        finalSugar: sugarMeasured ?? batch.initialSugar,
        finalAlcohol: alcoholMeasured ?? 0.0,
        primingSugarGrams: primingSugarGrams,
        nonFermentableSugarGrams: nonFermentableSugarGrams,
        finalSugarWithPriming: finalSugarWithPriming,
      );
      await _db.updateBatch(updatedBatch);

      if (!isLastStep && nextStep != null && nextDate != null) {
        await _scheduleReminders(updatedBatch, nextStep, nextDate);
      }
    } else {
      final nextStepIndex = currentIndex + 1;

      final updatedBatch = batch.copyWith(
        currentStepIndex: nextStepIndex,
        nextStepDate: nextDate,
      );
      await _db.updateBatch(updatedBatch);

      if (nextStep != null && nextDate != null) {
        await _scheduleReminders(updatedBatch, nextStep, nextDate);
      }
    }

    await loadBatches();
  }

  Future<void> _scheduleReminders(Batch batch, RecipeStep nextStep, DateTime nextDate) async {
    final notificationId = batch.id.hashCode & 0x7FFFFFFF;

    await _notifications.scheduleStepNotification(
      id: notificationId,
      title: 'CiderOff: ${batch.name}',
      body: 'Пора выполнять шаг: ${nextStep.getTitle('ru')}',
      scheduledDate: nextDate,
    );

    await _calendar.addStepToCalendar(
      batchName: batch.name,
      stepTitle: nextStep.getTitle('ru'),
      instruction: nextStep.getInstruction('ru'),
      targetDate: nextDate,
    );
  }

  Future<void> updateBatch(Batch updatedBatch) async {
    await _db.updateBatch(updatedBatch);
    await loadBatches();
  }

  Future<void> deleteBatch(String batchId) async {
    try {
      final notificationId = batchId.hashCode & 0x7FFFFFFF;
      await _notifications.cancelNotification(notificationId);
    } catch (e) {
      debugPrint('Ошибка при отмене уведомления: $e');
    }

    try {
      await _db.deleteBatch(batchId);
    } catch (e) {
      debugPrint('Ошибка при удалении из БД: $e');
      rethrow;
    }

    await loadBatches();
  }

  Future<void> updateBatchHistory(BatchHistory updatedHistory) async {
    await _db.updateHistory(updatedHistory);
    await loadBatches();
  }

  Future<void> deleteBatchHistory(String historyId) async {
    await _db.deleteHistory(historyId);
    await loadBatches();
  }
}