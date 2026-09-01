import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/datasources/database_service.dart';
import '../../../data/models/batch_container_model.dart';
import '../../../data/models/batch_history_model.dart';
import '../../../data/models/batch_model.dart';
import '../../../data/models/recipe_model.dart';
import '../../providers/batch_provider.dart';
import '../../providers/recipe_provider.dart';
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
    if (!mounted) return;
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

                final isBottlingStep = item.actionName.contains('Завершение') ||
                    item.actionName.contains('розлив') ||
                    item.stepTitle.toLowerCase().contains('розлив') ||
                    item.containers.isNotEmpty;

                final effectiveContainers = item.containers.isNotEmpty
                    ? item.containers
                    : (isBottlingStep && batch != null ? batch.containers : <BatchContainer>[]);

                double? calculatedSweetness = batch?.finalSugarWithPriming;
                if (calculatedSweetness == null &&
                    item.sugarMeasured != null &&
                    item.nonFermentableSugarGrams != null &&
                    item.nonFermentableSugarGrams! > 0) {
                  calculatedSweetness = item.sugarMeasured! + (item.nonFermentableSugarGrams! / 10.0);
                }
                calculatedSweetness ??= item.sugarMeasured;

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
                          height: effectiveContainers.isNotEmpty ? 120 : 60,
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
                                            } catch (_) {}
                                          }

                                          final editResult = await showDialog<EditHistoryDialogResult>(
                                            context: context,
                                            builder: (_) => EditHistoryDialog(
                                              history: item,
                                              batch: batch,
                                              recipeStep: matchedStep,
                                            ),
                                          );

                                          if (!mounted) return;

                                          if (editResult != null) {
                                            final batchProvider = context.read<BatchProvider>();
                                            await batchProvider.updateBatchHistory(editResult.history);

                                            if (batch != null) {
                                              Batch updatedBatch = batch;
                                              bool needsBatchUpdate = false;

                                              if (isBottlingStep) {
                                                updatedBatch = updatedBatch.copyWith(
                                                  containers: editResult.history.containers,
                                                );
                                                needsBatchUpdate = true;
                                              }

                                              if (editResult.yeastId != batch.yeastId) {
                                                updatedBatch = updatedBatch.copyWith(
                                                  yeastId: editResult.yeastId,
                                                );
                                                needsBatchUpdate = true;
                                              }

                                              if (needsBatchUpdate) {
                                                await batchProvider.updateBatch(updatedBatch);
                                              }
                                            }
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

                                          if (!mounted) return;

                                          if (confirm == true) {
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
                                  (isBottlingStep && calculatedSweetness != null && effectiveContainers.isEmpty)) ...[
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
                                    if (isBottlingStep && calculatedSweetness != null && effectiveContainers.isEmpty)
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

                              if (effectiveContainers.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Разлитые подпартии:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Column(
                                  children: effectiveContainers.map((container) {
                                    final baseSugar = item.sugarMeasured ?? batch?.finalSugar ?? 0.0;
                                    final sweetenerGramsPer100ml = container.sweetenerAmountGramsPerLiter / 10.0;
                                    final totalSweetness = baseSugar + sweetenerGramsPer100ml;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber.shade200),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${container.title} (${container.containerType})',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${container.count} шт × ${container.containerVolumeLiters}л (${container.totalVolumeLiters.toStringAsFixed(1)}л)'
                                                  '${container.sweetenerType != null && container.sweetenerAmountGramsPerLiter > 0 ? ' • ${container.sweetenerType}: ${container.sweetenerAmountGramsPerLiter} г/л' : ''}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade200,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Сладость: ${totalSweetness.toStringAsFixed(1)} г/100мл',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.amber.shade900,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
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