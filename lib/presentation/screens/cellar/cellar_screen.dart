import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/batch_model.dart';
import '../../../data/models/batch_container_model.dart';
import '../../../data/models/drink_type_model.dart';
import '../../../data/datasources/database_service.dart';
import '../../providers/batch_provider.dart';
import '../batch/batch_detail_screen.dart';

class CellarScreen extends StatefulWidget {
  const CellarScreen({super.key});

  @override
  State<CellarScreen> createState() => _CellarScreenState();
}

class _CellarScreenState extends State<CellarScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DrinkType> _drinkTypes = [];
  bool _isLoadingDrinkTypes = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDrinkTypes();
  }

  Future<void> _loadDrinkTypes() async {
    final types = await DatabaseService.instance.getAllDrinkTypes();
    if (mounted) {
      setState(() {
        _drinkTypes = types;
        _isLoadingDrinkTypes = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Определение названия категории сладости по г/л сахара
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
    final batchProvider = context.watch<BatchProvider>();

    final cellarBatches = batchProvider.batches.where((b) {
      return b.status == BatchStatus.inProgress || b.status == BatchStatus.completed;
    }).toList();

    final ciderBatches = cellarBatches.where((b) => b.type == BatchType.cider).toList();
    final calvadosBatches = cellarBatches.where((b) => b.type == BatchType.calvados).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Погребок', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '🍏 Сидр'),
            Tab(text: '🥃 Кальвадос'),
          ],
        ),
      ),
      body: _isLoadingDrinkTypes || batchProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCiderTab(ciderBatches),
                _buildCalvadosTab(calvadosBatches),
              ],
            ),
    );
  }

  /// Вкладка "Сидр" с контрастным баннером статистики
  Widget _buildCiderTab(List<Batch> batches) {
    final List<_CellarItem> items = [];

    for (final b in batches) {
      final baseSugarGramsPer100ml = b.finalSugarWithPriming ?? b.finalSugar ?? b.initialSugar;
      final baseSugarGramsPerLiter = baseSugarGramsPer100ml * 10.0;

      if (b.containers.isNotEmpty) {
        for (final c in b.containers) {
          final totalSugarGramsPerLiter = baseSugarGramsPerLiter + c.sweetenerAmountGramsPerLiter;
          final sweetnessCategory = _getSweetnessCategoryName(totalSugarGramsPerLiter);

          items.add(_CellarItem(
            batch: b,
            container: c,
            sweetnessCategory: sweetnessCategory,
            calculatedSugarGramsPerLiter: totalSugarGramsPerLiter,
          ));
        }
      } else if (b.containerCount != null && b.containerCount! > 0) {
        final sweetnessCategory = _getSweetnessCategoryName(baseSugarGramsPerLiter);
        items.add(_CellarItem(
          batch: b,
          sweetnessCategory: sweetnessCategory,
          calculatedSugarGramsPerLiter: baseSugarGramsPerLiter,
        ));
      }
    }

    if (items.isEmpty) {
      return const Center(
        child: Text('В погребке пока нет разлитого сидра', style: TextStyle(color: Colors.grey)),
      );
    }

    final Map<String, List<_CellarItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.sweetnessCategory, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildCellarHeader(items),
        ...grouped.entries.map((entry) {
          final categoryName = entry.key;
          final categoryItems = entry.value;

          final categoryVolume = categoryItems.fold<double>(
            0.0,
            (sum, i) => sum + (i.container?.totalVolumeLiters ?? i.batch.juiceVolume),
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.wine_bar, color: Colors.amber),
              title: Text(
                categoryName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text('Позиций: ${categoryItems.length} | Всего: ${categoryVolume.toStringAsFixed(1)} л'),
              children: categoryItems.map((item) {
                final c = item.container;
                return ListTile(
                  dense: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BatchDetailScreen(batchId: item.batch.id),
                      ),
                    );
                  },
                  title: Text(
                    c != null ? '${item.batch.name} — ${c.title}' : item.batch.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    c != null
                        ? '${c.containerType} (${c.containerVolumeLiters}л × ${c.count} шт.)'
                            '${c.sweetenerType != null ? " • ${c.sweetenerType}" : ""}'
                        : 'Тара: ${item.batch.containerType ?? "—"}',
                  ),
                  trailing: Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: item.batch.status == BatchStatus.completed
                        ? Colors.green.shade100
                        : Colors.amber.shade100,
                    label: Text(
                      item.batch.status == BatchStatus.completed ? 'Готов' : 'Созревание',
                      style: TextStyle(
                        fontSize: 11,
                        color: item.batch.status == BatchStatus.completed
                            ? Colors.green.shade900
                            : Colors.amber.shade900,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  /// Баннер статистики погреба с фиксированной контрастностью
  Widget _buildCellarHeader(List<_CellarItem> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalBottles = items.fold<int>(
      0,
      (sum, i) => sum + (i.container?.count ?? i.batch.containerCount ?? 0),
    );
    final totalLiters = items.fold<double>(
      0.0,
      (sum, i) => sum + (i.container?.totalVolumeLiters ?? i.batch.juiceVolume),
    );

    // Подбор контрастных цветов под тему
    final backgroundColor = isDark ? const Color(0xFF332A15) : Colors.amber.shade100;
    final borderColor = isDark ? Colors.amber.shade700 : Colors.amber.shade300;
    final labelColor = isDark ? Colors.amber.shade200 : Colors.black54;
    final valueColor = isDark ? Colors.amber.shade50 : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text('Всего бутылок', style: TextStyle(fontSize: 12, color: labelColor)),
              const SizedBox(height: 4),
              Text(
                '$totalBottles шт.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor),
              ),
            ],
          ),
          Container(height: 32, width: 1, color: borderColor),
          Column(
            children: [
              Text('Общий объем', style: TextStyle(fontSize: 12, color: labelColor)),
              const SizedBox(height: 4),
              Text(
                '${totalLiters.toStringAsFixed(1)} л',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Вкладка "Кальвадос"
  Widget _buildCalvadosTab(List<Batch> batches) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (batches.isEmpty) {
      return const Center(
        child: Text('В погребке пока нет Кальвадоса', style: TextStyle(color: Colors.grey)),
      );
    }

    final totalVolume = batches.fold<double>(
      0.0,
      (sum, b) => sum + (b.distillateVolume ?? b.juiceVolume),
    );

    final backgroundColor = isDark ? const Color(0xFF3D2512) : Colors.orange.shade100;
    final borderColor = isDark ? Colors.orange.shade700 : Colors.orange.shade300;
    final labelColor = isDark ? Colors.orange.shade200 : Colors.black54;
    final valueColor = isDark ? Colors.orange.shade50 : Colors.black87;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('Партий', style: TextStyle(fontSize: 12, color: labelColor)),
                  const SizedBox(height: 4),
                  Text(
                    '${batches.length}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor),
                  ),
                ],
              ),
              Container(height: 32, width: 1, color: borderColor),
              Column(
                children: [
                  Text('Общий объем', style: TextStyle(fontSize: 12, color: labelColor)),
                  const SizedBox(height: 4),
                  Text(
                    '${totalVolume.toStringAsFixed(1)} л',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor),
                  ),
                ],
              ),
            ],
          ),
        ),
        ...batches.map((b) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BatchDetailScreen(batchId: b.id),
                    ),
                  );
                },
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFD48115),
                  child: Text('🥃', style: TextStyle(fontSize: 14)),
                ),
                title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (b.barrelNotes != null && b.barrelNotes!.isNotEmpty)
                      Text('Бочка/Щепа: ${b.barrelNotes}'),
                    if (b.daysInAging != null)
                      Text('Выдержка: ${b.daysInAging} дн.'),
                    Text(
                        'Объем: ${b.distillateVolume ?? b.juiceVolume} л (${b.distillateABV ?? b.finalAlcohol ?? 0}% об.)'),
                  ],
                ),
                trailing: Icon(
                  b.status == BatchStatus.completed ? Icons.check_circle : Icons.hourglass_bottom,
                  color: b.status == BatchStatus.completed ? Colors.green : Colors.orange,
                ),
              ),
            )),
      ],
    );
  }
}

class _CellarItem {
  final Batch batch;
  final BatchContainer? container;
  final String sweetnessCategory;
  final double calculatedSugarGramsPerLiter;

  _CellarItem({
    required this.batch,
    this.container,
    required this.sweetnessCategory,
    required this.calculatedSugarGramsPerLiter,
  });
}