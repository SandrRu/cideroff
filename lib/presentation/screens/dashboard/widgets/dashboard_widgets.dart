import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/batch_model.dart';
import '../../../providers/yeast_provider.dart';
import '../../calculator/calculator_screen.dart';

/// 1. Карточка общего объема готового напитка
class TotalCompletedVolumeCard extends StatelessWidget {
  final double volumeLiters;
  const TotalCompletedVolumeCard({super.key, required this.volumeLiters});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            const SizedBox(height: 4),
            Text(
              '${volumeLiters.toStringAsFixed(1)} л',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const Text('Готовый напиток', style: TextStyle(fontSize: 11, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

/// 2. Карточка объема в процессе
class TotalInProgressVolumeCard extends StatelessWidget {
  final double volumeLiters;
  const TotalInProgressVolumeCard({super.key, required this.volumeLiters});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.science_outlined, color: Colors.amber, size: 28),
            const SizedBox(height: 4),
            Text(
              '${volumeLiters.toStringAsFixed(1)} л',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
            ),
            const Text('Объем в процессе', style: TextStyle(fontSize: 11, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

/// 3. Карточка ближайшего шага
class NearestStepCard extends StatelessWidget {
  final Batch? nearestBatch;
  const NearestStepCard({super.key, this.nearestBatch});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Card(
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Icon(Icons.alarm, color: Colors.orange, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Ближайший шаг',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (nearestBatch != null) ...[
              Text(
                nearestBatch!.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                nearestBatch!.nextStepDate != null
                    ? dateFormat.format(nearestBatch!.nextStepDate!)
                    : 'Без даты',
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ] else
              const Text('Нет запланированных шагов', style: TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

/// 4. Распределение по типам (Сидр vs Кальвадос)
class TypeDistributionCard extends StatelessWidget {
  final int ciderCount;
  final int calvadosCount;

  const TypeDistributionCard({super.key, required this.ciderCount, required this.calvadosCount});

  @override
  Widget build(BuildContext context) {
    final total = ciderCount + calvadosCount;
    final ciderPercent = total > 0 ? (ciderCount / total) : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Типы напитков', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ciderPercent,
                minHeight: 8,
                backgroundColor: Colors.deepOrange.shade300,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🍏 Сидр: $ciderCount', style: const TextStyle(fontSize: 10)),
                Text('🥃 Кальвадос: $calvadosCount', style: const TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 5. Количество активных брожений
class ActiveFermentationsCard extends StatelessWidget {
  final int count;

  const ActiveFermentationsCard({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.purple.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bubble_chart_outlined, color: Colors.purple, size: 28),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
            ),
            const Text('Активные брожения', style: TextStyle(fontSize: 11, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

/// 6. Используемые дрожжи в ходу
/// Отображает детальный список активных штаммов с их названиями и количеством партий.
class ActiveYeastsCard extends StatelessWidget {
  final List<Batch> batches;

  const ActiveYeastsCard({super.key, required this.batches});

  @override
  Widget build(BuildContext context) {
    final activeBatches = batches.where((b) => b.status != BatchStatus.archived).toList();
    final yeastProvider = context.watch<YeastProvider>();

    final Map<String, int> yeastUsageMap = {};
    for (final batch in activeBatches) {
      if (batch.yeastId != null && batch.yeastId!.trim().isNotEmpty) {
        final yeastId = batch.yeastId!.trim();
        final matches = yeastProvider.yeasts.where((y) => y.id == yeastId);
        final name = matches.isNotEmpty ? matches.first.name : 'Неизвестный штамм';

        yeastUsageMap[name] = (yeastUsageMap[name] ?? 0) + 1;
      }
    }

    final sortedYeasts = yeastUsageMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      color: Colors.teal.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.biotech_outlined, color: Colors.teal, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'Дрожжи в работе',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                    ),
                  ],
                ),
                Text(
                  '${sortedYeasts.length} шт.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (sortedYeasts.isEmpty)
              const Text('Нет указанных дрожжей в активных партиях', style: TextStyle(fontSize: 11, color: Colors.black54))
            else
              Column(
                children: sortedYeasts.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${entry.value} партий',
                          style: TextStyle(fontSize: 10, color: Colors.teal.shade800),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

/// 7. Готовность по видам тары
/// Отображает сгруппированный остаток готовой продукции по типам емкостей.
class FinishedPackagingCard extends StatelessWidget {
  final List<Batch> batches;

  const FinishedPackagingCard({super.key, required this.batches});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> packagingCounts = {};
    final Map<String, double> packagingVolumes = {};

    for (final batch in batches) {
      for (final container in batch.containers) {
        final label = container.containerType.trim().isEmpty
            ? 'Прочая тара'
            : container.containerType;

        packagingCounts[label] = (packagingCounts[label] ?? 0) + container.count;
        packagingVolumes[label] = (packagingVolumes[label] ?? 0) + container.totalVolumeLiters;
      }
    }

    return Card(
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Colors.blueGrey.shade700, size: 20),
                const SizedBox(width: 6),
                Text(
                  'Готовность по видам тары',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (packagingCounts.isEmpty)
              const Text('Готовая продукция еще не расфасована', style: TextStyle(fontSize: 11, color: Colors.black54))
            else
              Column(
                children: packagingCounts.keys.map((key) {
                  final count = packagingCounts[key]!;
                  final volume = packagingVolumes[key]!;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(_getIconForPackaging(key), size: 14, color: Colors.blueGrey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              key,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                            ),
                          ],
                        ),
                        Text(
                          '$count шт. (~${volume.toStringAsFixed(1)} л)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForPackaging(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('кег')) return Icons.sports_bar;
    if (lower.contains('бутылк')) return Icons.wine_bar;
    if (lower.contains('банка')) return Icons.view_headline;
    return Icons.takeout_dining;
  }
}

/// 8. Быстрый калькулятор
class QuickCalculatorCard extends StatelessWidget {
  const QuickCalculatorCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CalculatorScreen()),
          );
        },
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calculate_outlined, color: Colors.blue, size: 28),
              SizedBox(height: 4),
              Text(
                'Калькулятор',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              Text('Быстрые расчеты', style: TextStyle(fontSize: 10, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }
}