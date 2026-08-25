import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/datasources/database_service.dart';
import '../../../data/models/batch_history_model.dart';
import 'widgets/fermentation_chart.dart';

class HistoryScreen extends StatelessWidget {
  final String batchId;

  const HistoryScreen({super.key, required this.batchId});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('История партии'),
      ),
      body: FutureBuilder<List<BatchHistory>>(
        future: DatabaseService.instance.getHistoryForBatch(batchId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final historyList = snapshot.data ?? [];

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
              // График динамики сахара и алкоголя
              FermentationChart(historyList: historyList),

              const SizedBox(height: 8),

              // Список событий Timeline
              ...List.generate(historyList.length, (index) {
                final item = historyList[index];
                final isFirst = index == 0;
                final isLast = index == historyList.length - 1;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Временная шкала
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

                    // Карточка записи истории
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
                                  Text(
                                    dateFormat.format(item.timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
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
                              if (item.sugarMeasured != null || item.alcoholMeasured != null) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    if (item.sugarMeasured != null)
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text('Сахар: ${item.sugarMeasured} г/100мл'),
                                      ),
                                    if (item.alcoholMeasured != null)
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text('Спирт: ${item.alcoholMeasured}% об.'),
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