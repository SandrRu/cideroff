import 'package:cider_off/core/utils/hydrometry_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brix <-> SG', () {
    test('нулевой Brix соответствует SG 1.000', () {
      expect(HydrometryCalculator.brixToSg(0), 1.0);
      expect(HydrometryCalculator.brixToSg(-3), 1.0);
    });

    test('SG 1.000 даёт 0 Brix', () {
      expect(HydrometryCalculator.sgToBrix(1.0), 0.0);
    });

    test('перевод Brix в SG', () {
      expect(HydrometryCalculator.brixToSg(12), closeTo(1.0484, 0.0005));
    });

    test('обратный перевод SG в Brix', () {
      expect(HydrometryCalculator.sgToBrix(1.0484), closeTo(12.0, 0.1));
    });

    test('круговое преобразование сохраняет значение', () {
      for (final brix in [5.0, 10.0, 15.0, 20.0, 25.0]) {
        final sg = HydrometryCalculator.brixToSg(brix);
        expect(HydrometryCalculator.sgToBrix(sg), closeTo(brix, 0.1),
            reason: 'Brix $brix');
      }
    });

    test('сахар в г/100мл растёт вместе с Brix', () {
      final low = HydrometryCalculator.brixToSugarGramsPer100ml(8);
      final high = HydrometryCalculator.brixToSugarGramsPer100ml(16);

      expect(low, greaterThan(0));
      expect(high, greaterThan(low));
    });
  });

  group('Крепость', () {
    test('ABV по SG', () {
      expect(
        HydrometryCalculator.calculateAbvFromSg(1.060, 1.010),
        closeTo(6.56, 0.01),
      );
    });

    test('ABV равен нулю, если брожения не было', () {
      expect(HydrometryCalculator.calculateAbvFromSg(1.010, 1.060), 0.0);
      expect(HydrometryCalculator.calculateAbvFromSg(1.020, 1.020), 0.0);
    });

    test('ABV по гидрометру', () {
      final abv = HydrometryCalculator.calculateAbvFromHydrometer(20, 5);
      expect(abv, greaterThan(8.0));
      expect(abv, lessThan(12.0));
    });
  });

  group('Шаптализация', () {
    test('масса сахара для повышения плотности', () {
      final grams = HydrometryCalculator.calculateSugarAddition(
        currentSugarGrams100ml: 10,
        targetSugarGrams100ml: 15,
        volumeLiters: 20,
      );

      expect(grams, closeTo(1000.0, 0.0001));
    });

    test('ничего не добавляем, если цель ниже текущего сахара', () {
      expect(
        HydrometryCalculator.calculateSugarAddition(
          currentSugarGrams100ml: 15,
          targetSugarGrams100ml: 10,
          volumeLiters: 20,
        ),
        0.0,
      );
    });
  });

  group('Карбонизация', () {
    test('декстроза при 18 °C и 2.4 объёмах CO2', () {
      expect(
        HydrometryCalculator.calculatePrimingSugarPerLiter(
          targetCo2Volumes: 2.4,
          ciderTempC: 18,
        ),
        closeTo(5.46, 0.01),
      );
    });

    test(
        'чем теплее сидр, тем меньше в нём остаточного CO2 — сахара нужно больше',
        () {
      final cold =
          HydrometryCalculator.calculatePrimingSugarPerLiter(ciderTempC: 5);
      final warm =
          HydrometryCalculator.calculatePrimingSugarPerLiter(ciderTempC: 25);

      expect(warm, greaterThan(cold));
    });

    test('при достаточном остаточном CO2 добавка не нужна', () {
      expect(
        HydrometryCalculator.calculatePrimingSugarPerLiter(
          targetCo2Volumes: 0.5,
          ciderTempC: 18,
        ),
        0.0,
      );
    });
  });

  group('Дистилляция', () {
    test('абсолютный спирт', () {
      expect(HydrometryCalculator.calculateAbsoluteAlcohol(10, 40),
          closeTo(4.0, 0.0001));
    });

    test('объём воды для разбавления', () {
      expect(
        HydrometryCalculator.calculateWaterToDilute(
          currentVolume: 10,
          currentAbv: 60,
          targetAbv: 40,
        ),
        closeTo(5.0, 0.0001),
      );
    });

    test('не разбавляем, если крепость уже ниже цели', () {
      expect(
        HydrometryCalculator.calculateWaterToDilute(
          currentVolume: 10,
          currentAbv: 30,
          targetAbv: 40,
        ),
        0.0,
      );
    });

    test('объём голов', () {
      expect(
        HydrometryCalculator.calculateHeadsVolumeMl(
          volumeLiters: 20,
          abvPercent: 50,
        ),
        500,
      );
    });
  });
}
