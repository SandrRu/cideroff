import 'dart:math';

class HydrometryCalculator {
  /// Перевод Brix в SG (Specific Gravity)
  static double brixToSg(double brix) {
    if (brix <= 0) return 1.000;
    return 1.0 + (brix / (258.6 - ((brix / 258.2) * 227.1)));
  }

  /// Перевод SG в Brix
  static double sgToBrix(double sg) {
    if (sg <= 1.000) return 0.0;
    return (((182.4601 * sg - 775.6821) * sg + 1262.7794) * sg - 669.5622);
  }

  /// Конвертация Brix в Граммы сахара на 100 мл
  static double brixToSugarGramsPer100ml(double brix) {
    final sg = brixToSg(brix);
    return brix * sg;
  }

  /// Расчет крепости ABV (%) по начальному и конечному SG
  static double calculateAbvFromSg(double ogSg, double fgSg) {
    if (ogSg <= fgSg) return 0.0;
    final abv = (ogSg - fgSg) * 131.25;
    return double.parse(abv.toStringAsFixed(2));
  }

  /// Расчет массы сахара (в граммах) для шаптализации
  static double calculateSugarAddition({
    required double currentSugarGrams100ml,
    required double targetSugarGrams100ml,
    required double volumeLiters,
  }) {
    if (targetSugarGrams100ml <= currentSugarGrams100ml) return 0.0;
    final delta = targetSugarGrams100ml - currentSugarGrams100ml;
    return delta * 10 * volumeLiters;
  }

  /// Расчет декстрозы/сахара для карбонизации при розливе (в граммах на 1 литр)
  static double calculatePrimingSugarPerLiter({
    double targetCo2Volumes = 2.4,
    double ciderTempC = 18.0,
  }) {
    final residualCo2 = 1.7037 - (0.0461 * ciderTempC) + (0.0005 * pow(ciderTempC, 2));
    final neededCo2 = targetCo2Volumes - residualCo2;
    if (neededCo2 <= 0) return 0.0;
    
    final sugarGram = neededCo2 * 4.0;
    return double.parse(sugarGram.toStringAsFixed(2));
  }

  /// Точный расчет крепости ABV (%) по значениям начального и конечного сахара/Brix
  static double calculateAbvFromHydrometer(double initialSugar, double finalSugar, {double factor = 0.47}) {
    if (initialSugar <= finalSugar) return 0.0;
    final ogSg = brixToSg(initialSugar);
    final fgSg = brixToSg(finalSugar);
    final abv = calculateAbvFromSg(ogSg, fgSg);
    return double.parse(abv.toStringAsFixed(1));
  }

  // --- КАЛЬКУЛЯТОРЫ ДИСТИЛЛЯЦИИ И КАЛЬВАДОСА ---

  /// Расчет Абсолютного Спирта (АС) в литрах
  static double calculateAbsoluteAlcohol(double volumeLiters, double abvPercent) {
    if (volumeLiters <= 0 || abvPercent <= 0) return 0.0;
    final absoluteAlcohol = volumeLiters * (abvPercent / 100.0);
    return double.parse(absoluteAlcohol.toStringAsFixed(2));
  }

  /// Расчет объема воды (в литрах) для разбавления дистиллята до нужной крепости
  static double calculateWaterToDilute({
    required double currentVolume,
    required double currentAbv,
    required double targetAbv,
  }) {
    if (targetAbv >= currentAbv || targetAbv <= 0 || currentVolume <= 0) return 0.0;
    final waterVolume = currentVolume * ((currentAbv - targetAbv) / targetAbv);
    return double.parse(waterVolume.toStringAsFixed(2));
  }

  /// Расчет ориентировочного объема «голов» (в мл) при 2-м дробном перегоне
  static double calculateHeadsVolumeMl({
    required double volumeLiters,
    required double abvPercent,
    double headsPercentage = 5.0,
  }) {
    final absoluteAlcoholLiters = calculateAbsoluteAlcohol(volumeLiters, abvPercent);
    final headsLiters = absoluteAlcoholLiters * (headsPercentage / 100.0);
    final headsMl = headsLiters * 1000;
    return double.parse(headsMl.toStringAsFixed(0));
  }
}