import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../data/datasources/database_service.dart';
import '../../../../data/models/batch_model.dart';
import '../../../../data/models/drink_type_model.dart';
import '../../../providers/yeast_provider.dart';
import '../../calculator/calculator_screen.dart';

/// 1. Карточка объема готового напитка по категориям DrinkType
class TotalCompletedVolumeCard extends StatefulWidget {
  final List<Batch> completedBatches;
  final VoidCallback? onTap;

  const TotalCompletedVolumeCard({
    super.key,
    required this.completedBatches,
    this.onTap,
  });

  @override
  State<TotalCompletedVolumeCard> createState() => _TotalCompletedVolumeCardState();
}

class _TotalCompletedVolumeCardState extends State<TotalCompletedVolumeCard> {
  List<DrinkType> _drinkTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrinkTypes();
  }

  Future<void> _loadDrinkTypes() async {
    final types = await DatabaseService.instance.getAllDrinkTypes();
    if (mounted) {
      setState(() {
        _drinkTypes = types;
        _isLoading = false;
      });
    }
  }

  String _getSweetnessCategoryName(double sugarGramsPerLiter) {
    if (_drinkTypes.isEmpty) return 'Прочее';
    for (final dt in _drinkTypes) {
      if (sugarGramsPerLiter >= dt.minSugarGramsPerLiter &&
          sugarGramsPerLiter <= dt.maxSugarGramsPerLiter) {
        return dt.name;
      }
    }
    return 'Прочее';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        color: Colors.green.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
          ),
        ),
      );
    }

    // Подсчет объема по категориям сладости
    final Map<String, double> categoryVolumes = {};
    double totalLiters = 0.0;

    for (final b in widget.completedBatches) {
      final baseSugarGramsPer100ml = b.finalSugarWithPriming ?? b.finalSugar ?? b.initialSugar;
      final baseSugarGramsPerLiter = baseSugarGramsPer100ml * 10.0;

      if (b.containers.isNotEmpty) {
        for (final c in b.containers) {
          final totalSugarGramsPerLiter = baseSugarGramsPerLiter + c.sweetenerAmountGramsPerLiter;
          final categoryName = _getSweetnessCategoryName(totalSugarGramsPerLiter);
          
          categoryVolumes[categoryName] = (categoryVolumes[categoryName] ?? 0.0) + c.totalVolumeLiters;
          totalLiters += c.totalVolumeLiters;
        }
      } else {
        final categoryName = _getSweetnessCategoryName(baseSugarGramsPerLiter);
        final vol = b.totalBottledVolume > 0 ? b.totalBottledVolume : b.juiceVolume;
        categoryVolumes[categoryName] = (categoryVolumes[categoryName] ?? 0.0) + vol;
        totalLiters += vol;
      }
    }

    final sortedEntries = categoryVolumes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
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
                    children: const [
                      Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Готовый напиток',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${totalLiters.toStringAsFixed(1)} л',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (sortedEntries.isEmpty)
                const Text(
                  'Нет готовых партий',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                )
              else
                Column(
                  children: sortedEntries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${entry.value.toStringAsFixed(1)} л',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
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
            const Text('Объём в процессе', style: TextStyle(fontSize: 11, color: Colors.black87)),
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

/// 6. Используемые дрожжи в ходу (Оптимизирован для малых экранов)
class ActiveYeastsCard extends StatelessWidget {
  final List<Batch> batches;

  const ActiveYeastsCard({super.key, required this.batches});

  String _formatYeastName(String rawName) {
    return rawName
        .replaceAll("Mangrove Jack's", '')
        .replaceAll('Fermentis', '')
        .replaceAll('Lallemand', '')
        .trim();
  }

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
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactWidth = constraints.maxWidth < 170;
            final isCompactHeight = constraints.maxHeight < 120;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.biotech_outlined, color: Colors.teal, size: 18),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Дрожжи в работе',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (!isCompactWidth) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${sortedYeasts.length} шт.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (sortedYeasts.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Нет дрожжей в работающих партиях',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedYeasts.length,
                      itemBuilder: (context, index) {
                        final entry = sortedYeasts[index];
                        final displayName = isCompactWidth
                            ? _formatYeastName(entry.key)
                            : entry.key;

                        final batchSuffix = isCompactWidth
                            ? 'п.'
                            : (entry.value == 1 ? 'парт.' : 'партии');

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${entry.value} $batchSuffix',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 7. Объем и структура расфасованной продукции (Замена FinishedPackagingCard)
class PackagingVolumeDistributionCard extends StatelessWidget {
  final List<Batch> batches;

  const PackagingVolumeDistributionCard({super.key, required this.batches});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> packagingCounts = {};
    final Map<String, double> packagingVolumes = {};
    double totalVolume = 0.0;

    for (final batch in batches) {
      for (final container in batch.containers) {
        final label = container.containerType.trim().isEmpty
            ? 'Прочая тара'
            : container.containerType;

        packagingCounts[label] = (packagingCounts[label] ?? 0) + container.count;
        packagingVolumes[label] = (packagingVolumes[label] ?? 0) + container.totalVolumeLiters;
        totalVolume += container.totalVolumeLiters;
      }
    }

    final sortedKeys = packagingVolumes.keys.toList()
      ..sort((a, b) => packagingVolumes[b]!.compareTo(packagingVolumes[a]!));

    return Card(
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactWidth = constraints.maxWidth < 170;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.blueGrey.shade800,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Разлито по таре',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    Text(
                      '${totalVolume.toStringAsFixed(1)} л',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (sortedKeys.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Продукция еще не расфасована',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedKeys.length,
                      itemBuilder: (context, index) {
                        final key = sortedKeys[index];
                        final count = packagingCounts[key]!;
                        final volume = packagingVolumes[key]!;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Row(
                            children: [
                              Icon(
                                _getIconForPackaging(key),
                                size: 12,
                                color: Colors.blueGrey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  key,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCompactWidth
                                    ? '$count шт'
                                    : '$count шт (${volume.toStringAsFixed(1)}л)',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade900,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _getIconForPackaging(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('кег')) return Icons.sports_bar;
    if (lower.contains('бутылк')) return Icons.wine_bar;
    if (lower.contains('банка') || lower.contains('пэт')) return Icons.local_drink;
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