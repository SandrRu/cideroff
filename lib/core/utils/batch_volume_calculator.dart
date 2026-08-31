import '../../data/models/batch_container_model.dart';

class BatchVolumeCalculator {
  /// Расчет суммарного объема розлива по всем подпартиям (л)
  static double calculateTotalBottledVolume(List<BatchContainer> containers) {
    return containers.fold(0.0, (sum, c) => sum + c.totalVolumeLiters);
  }

  /// Расчет осадка / потерь (Общий объем сусла - Общий объем розлива)
  static double calculateLossVolume({
    required double totalJuiceVolume,
    required List<BatchContainer> containers,
  }) {
    final bottled = calculateTotalBottledVolume(containers);
    final loss = totalJuiceVolume - bottled;
    return loss < 0 ? 0.0 : double.parse(loss.toStringAsFixed(2));
  }

  /// Проверка превышения объема сусла
  static bool isVolumeExceeded({
    required double totalJuiceVolume,
    required List<BatchContainer> containers,
  }) {
    final bottled = calculateTotalBottledVolume(containers);
    return bottled > totalJuiceVolume;
  }
}