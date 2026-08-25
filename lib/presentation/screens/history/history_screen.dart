import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/datasources/database_service.dart';
import '../../../data/models/batch_history_model.dart';
import '../../../data/models/batch_model.dart';
import '../../../data/models/recipe_model.dart'; // <-- Импортируем модель рецепта
import '../../providers/batch_provider.dart';
import '../../providers/recipe_provider.dart'; // <-- Импортируем провайдер рецептов
import 'widgets/edit_history_dialog.dart';
import 'widgets/fermentation_chart.dart';

class HistoryScreen extends StatefulWidget {
  final String batchId;

  const HistoryScreen({super.key, required this.batchId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('История партии'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: Future.wait([
          DatabaseService.instance.getHistoryForBatch(widget.batchId),
          DatabaseService.instance.getBatchById(widget.batchId),
        ]).then((results) => {
              'history': results[0] as List<BatchHistory>,
              'batch': results[1] as Batch?,
            }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final historyList = (snapshot.data?['history'] as List<BatchHistory>?) ?? [];
          final batch = snapshot.data?['batch'] as Batch?;

          if (historyList.isEmpty) {
            return const Center(
              child: Text(
                'История пока пуста',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FermentationChart(
                historyList: historyList,
                batch: batch,
              ),
              const SizedBox(height: 8),
              ...List.generate(historyList.length, (index) {
                final item = historyList[index];
                final isFirst = index == 0;
                final isLast = index == historyList.length - 1;

                final isBottlingOrLater = item.actionName.contains('Завершение') ||
                    item.actionName.contains('розлив') ||
                    item.stepTitle.toLowerCase().contains('розлив');

                double? calculatedSweetness = batch?.finalSugarWithPriming;
                if (calculatedSweetness == null &&
                    item.sugarMeasured != null &&
                    item.nonFermentableSugarGrams != null &&
                    item.nonFermentableSugarGrams! > 0) {
                  calculatedSweetness = item.sugarMeasured! + (item.nonFermentableSugarGrams! / 10.0);
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 2,
                          height: 16,
                          color: isFirst ? Colors.transparent : Colors.amber.shade300,
                        ),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 60,
                          color: isLast ? Colors.transparent : Colors.amber.shade300,
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.stepTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        dateFormat.format(item.timestamp),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: 'Редактировать',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        onPressed: () async {
                                          // Ищем соответствующий RecipeStep в рецепте партии по названию шага
                                          RecipeStep? matchedStep;
                                          if (batch?.currentRecipeId != null) {
                                            try {
                                              final recipeProvider = context.read<RecipeProvider>();
                                              final recipe = recipeProvider.recipes.firstWhere(
                                                (r) => r.id == batch?.currentRecipeId,
                                              );
                                              matchedStep = recipe.steps.firstWhere(
                                                (s) => s.getTitle('ru') == item.stepTitle,
                                              );
                                            } catch (_) {
                                              // Если рецепт не найден или название не совпало, оставляем null
                                            }
                                          }

                                          final updatedHistory = await showDialog<BatchHistory>(
                                            context: context,
                                            builder: (_) => EditHistoryDialog(
                                              history: item,
                                              batch: batch,
                                              recipeStep: matchedStep, // Передаем найденный шаг рецепта
                                            ),
                                          );
                                          if (updatedHistory != null && context.mounted) {
                                            await context
                                                .read<BatchProvider>()
                                                .updateBatchHistory(updatedHistory);
                                            _refresh();
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                        tooltip: 'Удалить шаг',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Удалить шаг?'),
                                              content: Text('Удалить запись "${item.stepTitle}" из истории?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text('Отмена'),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Удалить'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true && context.mounted) {
                                            await context.read<BatchProvider>().deleteBatchHistory(item.id);
                                            _refresh();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.actionName,
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontSize: 13,
                                ),
                              ),
                              if (item.sugarMeasured != null ||
                                  item.alcoholMeasured != null ||
                                  (isBottlingOrLater && calculatedSweetness != null)) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    if (item.sugarMeasured != null)
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text('Замер сахара: ${item.sugarMeasured} г/100мл'),
                                      ),
                                    if (item.alcoholMeasured != null)
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text('Спирт: ${item.alcoholMeasured}% об.'),
                                      ),
                                    if (isBottlingOrLater && calculatedSweetness != null)
                                      Chip(
                                        backgroundColor: Colors.amber.shade100,
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          'Сладость: ${calculatedSweetness.toStringAsFixed(1)} г/100мл',
                                          style: TextStyle(
                                            color: Colors.amber.shade900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              if (item.note != null && item.note!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Заметка: ${item.note}',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }
}