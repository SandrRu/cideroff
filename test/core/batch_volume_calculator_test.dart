import 'package:cider_off/core/utils/batch_volume_calculator.dart';
import 'package:cider_off/data/models/batch_container_model.dart';
import 'package:flutter_test/flutter_test.dart';

BatchContainer _container({
  required double volumeLiters,
  required int count,
  String id = 'c1',
}) {
  return BatchContainer(
    id: id,
    batchId: 'b1',
    title: 'Тара',
    containerType: 'Бутылка (бугель)',
    containerVolumeLiters: volumeLiters,
    count: count,
  );
}

void main() {
  group('BatchVolumeCalculator.calculateTotalBottledVolume', () {
    test('суммирует объём всех подпартий', () {
      final containers = [
        _container(id: 'c1', volumeLiters: 0.75, count: 20),
        _container(id: 'c2', volumeLiters: 5, count: 2),
      ];

      expect(BatchVolumeCalculator.calculateTotalBottledVolume(containers),
          closeTo(25.0, 0.0001));
    });

    test('пустой список даёт 0', () {
      expect(BatchVolumeCalculator.calculateTotalBottledVolume(const []), 0.0);
    });
  });

  group('BatchVolumeCalculator.calculateLossVolume', () {
    test('считает потери как разницу сусла и розлива', () {
      final loss = BatchVolumeCalculator.calculateLossVolume(
        totalJuiceVolume: 30,
        containers: [_container(volumeLiters: 0.75, count: 20)],
      );

      expect(loss, closeTo(15.0, 0.0001));
    });

    test('не уходит в минус при переполнении', () {
      final loss = BatchVolumeCalculator.calculateLossVolume(
        totalJuiceVolume: 10,
        containers: [_container(volumeLiters: 5, count: 4)],
      );

      expect(loss, 0.0);
    });

    test('округляет до двух знаков', () {
      final loss = BatchVolumeCalculator.calculateLossVolume(
        totalJuiceVolume: 10,
        containers: [_container(volumeLiters: 0.33, count: 3)],
      );

      expect(loss, closeTo(9.01, 0.0001));
    });
  });

  group('BatchVolumeCalculator.isVolumeExceeded', () {
    test('истина, когда розлив больше сусла', () {
      expect(
        BatchVolumeCalculator.isVolumeExceeded(
          totalJuiceVolume: 10,
          containers: [_container(volumeLiters: 6, count: 2)],
        ),
        isTrue,
      );
    });

    test('ложь при равенстве объёмов', () {
      expect(
        BatchVolumeCalculator.isVolumeExceeded(
          totalJuiceVolume: 10,
          containers: [_container(volumeLiters: 5, count: 2)],
        ),
        isFalse,
      );
    });
  });
}
