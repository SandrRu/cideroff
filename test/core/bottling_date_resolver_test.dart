import 'package:cider_off/core/utils/bottling_date_resolver.dart';
import 'package:cider_off/data/models/batch_container_model.dart';
import 'package:cider_off/data/models/batch_history_model.dart';
import 'package:cider_off/data/models/batch_model.dart';
import 'package:flutter_test/flutter_test.dart';

Batch _batch({
  DateTime? pressDate,
  DateTime? nextStepDate,
  BatchStatus status = BatchStatus.inProgress,
}) {
  return Batch(
    name: 'Антоновка',
    appleVariety: 'Антоновка десертная',
    initialSugar: 12,
    juiceVolume: 20,
    pressDate: pressDate ?? DateTime(2023, 5, 1),
    nextStepDate: nextStepDate,
    status: status,
  );
}

BatchHistory _history({
  required DateTime timestamp,
  String stepTitle = 'Шаг',
  String actionName = 'Шаг выполнен',
  List<BatchContainer> containers = const [],
}) {
  return BatchHistory(
    batchId: 'b1',
    timestamp: timestamp,
    stepTitle: stepTitle,
    actionName: actionName,
    containers: containers,
  );
}

void main() {
  group('BottlingDateResolver.isBottlingEvent', () {
    test('событие с тарой считается розливом', () {
      final event = _history(
        timestamp: DateTime(2023, 6, 1),
        containers: [
          BatchContainer(
            batchId: 'b1',
            title: 'Подпартия',
            containerType: 'Бутылка',
            containerVolumeLiters: 0.5,
            count: 10,
          ),
        ],
      );

      expect(BottlingDateResolver.isBottlingEvent(event), isTrue);
    });

    test('розлив определяется по названию шага', () {
      final event = _history(
        timestamp: DateTime(2023, 6, 1),
        stepTitle: 'Розлив и внесение декстрозы',
      );

      expect(BottlingDateResolver.isBottlingEvent(event), isTrue);
    });

    test('обычный шаг розливом не считается', () {
      final event = _history(
        timestamp: DateTime(2023, 6, 1),
        stepTitle: 'Снятие с осадка',
      );

      expect(BottlingDateResolver.isBottlingEvent(event), isFalse);
    });
  });

  group('BottlingDateResolver.fromHistory', () {
    test('берёт дату события розлива, даже если позже были другие записи', () {
      final bottlingDate = DateTime(2023, 6, 5);
      // История приходит в порядке убывания даты, как её отдаёт БД.
      final history = [
        _history(timestamp: DateTime(2023, 6, 20), stepTitle: 'Дегустация'),
        _history(
          timestamp: bottlingDate,
          stepTitle: 'Розлив и внесение декстрозы',
        ),
        _history(timestamp: DateTime(2023, 5, 1), stepTitle: 'Постановка'),
      ];

      expect(
        BottlingDateResolver.fromHistory(_batch(), history),
        bottlingDate,
      );
    });

    test('для завершённой партии без явного розлива — последнее событие', () {
      final lastStepDate = DateTime(2023, 6, 12);
      final history = [
        _history(timestamp: lastStepDate, stepTitle: 'Финишное разбавление'),
        _history(timestamp: DateTime(2023, 5, 1), stepTitle: 'Постановка'),
      ];

      expect(
        BottlingDateResolver.fromHistory(
          _batch(status: BatchStatus.completed),
          history,
        ),
        lastStepDate,
      );
    });

    test('для партии в процессе — плановая дата розлива', () {
      final planned = DateTime(2023, 7, 1);
      final history = [
        _history(timestamp: DateTime(2023, 5, 1), stepTitle: 'Постановка'),
      ];

      expect(
        BottlingDateResolver.fromHistory(
          _batch(nextStepDate: planned),
          history,
        ),
        planned,
      );
    });

    test('без истории и плановой даты — дата отжима', () {
      final pressDate = DateTime(2023, 5, 3);

      expect(
        BottlingDateResolver.fromHistory(
            _batch(pressDate: pressDate), const []),
        pressDate,
      );
    });
  });
}
