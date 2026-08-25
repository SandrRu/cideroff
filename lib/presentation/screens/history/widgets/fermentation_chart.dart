import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/batch_history_model.dart';

class FermentationChart extends StatelessWidget {
  final List<BatchHistory> historyList;

  const FermentationChart({super.key, required this.historyList});

  @override
  Widget build(BuildContext context) {
    // Фильтруем историю, оставляя только записи с зафиксированными замерами
    final filteredHistory = historyList
        .where((h) => h.sugarMeasured != null || h.alcoholMeasured != null)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (filteredHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    // Формируем точки для сахара и алкоголя
    final sugarSpots = <FlSpot>[];
    final alcoholSpots = <FlSpot>[];

    final minTimestamp = filteredHistory.first.timestamp.millisecondsSinceEpoch.toDouble();

    for (var i = 0; i < filteredHistory.length; i++) {
      final item = filteredHistory[i];
      // Обись X: дни с момента первой записи
      final daysFromStart = (item.timestamp.millisecondsSinceEpoch - minTimestamp) / (1000 * 60 * 60 * 24);

      if (item.sugarMeasured != null) {
        sugarSpots.add(FlSpot(daysFromStart, item.sugarMeasured!));
      }
      if (item.alcoholMeasured != null) {
        alcoholSpots.add(FlSpot(daysFromStart, item.alcoholMeasured!));
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Динамика брожения',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Row(
                  children: [
                    _buildLegendItem('Сахар', Colors.amber),
                    const SizedBox(width: 12),
                    _buildLegendItem('Алкоголь', Colors.green),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${value.toInt()}дн',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Линия Сахара
                    if (sugarSpots.isNotEmpty)
                      LineChartBarData(
                        spots: sugarSpots,
                        isCurved: true,
                        color: Colors.amber,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.amber.withValues(alpha: 0.15),
                        ),
                      ),
                    // Линия Алкоголя
                    if (alcoholSpots.isNotEmpty)
                      LineChartBarData(
                        spots: alcoholSpots,
                        isCurved: true,
                        color: Colors.green,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.green.withValues(alpha: 0.15),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}