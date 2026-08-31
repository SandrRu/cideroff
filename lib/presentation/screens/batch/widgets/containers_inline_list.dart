import 'package:flutter/material.dart';
import '../../../../core/utils/batch_volume_calculator.dart';
import '../../../../data/models/batch_container_model.dart';
import 'container_form_dialog.dart';

class ContainersInlineList extends StatelessWidget {
  final String batchId;
  final double totalJuiceVolume;
  final List<BatchContainer> containers;
  final ValueChanged<List<BatchContainer>> onChanged;

  const ContainersInlineList({
    super.key,
    required this.batchId,
    required this.totalJuiceVolume,
    required this.containers,
    required this.onChanged,
  });

  void _addContainer(BuildContext context) async {
    final newContainer = await showDialog<BatchContainer>(
      context: context,
      builder: (_) => ContainerFormDialog(batchId: batchId),
    );

    if (newContainer != null) {
      final updatedList = List<BatchContainer>.from(containers)..add(newContainer);
      onChanged(updatedList);
    }
  }

  void _editContainer(BuildContext context, int index) async {
    final updatedContainer = await showDialog<BatchContainer>(
      context: context,
      builder: (_) => ContainerFormDialog(
        batchId: batchId,
        container: containers[index],
      ),
    );

    if (updatedContainer != null) {
      final updatedList = List<BatchContainer>.from(containers);
      updatedList[index] = updatedContainer;
      onChanged(updatedList);
    }
  }

  void _removeContainer(int index) {
    final updatedList = List<BatchContainer>.from(containers)..removeAt(index);
    onChanged(updatedList);
  }

  @override
  Widget build(BuildContext context) {
    final totalBottled = BatchVolumeCalculator.calculateTotalBottledVolume(containers);
    final lossVolume = BatchVolumeCalculator.calculateLossVolume(
      totalJuiceVolume: totalJuiceVolume,
      containers: containers,
    );
    final isExceeded = BatchVolumeCalculator.isVolumeExceeded(
      totalJuiceVolume: totalJuiceVolume,
      containers: containers,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Распределение по таре (подпартии)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton.icon(
              onPressed: () => _addContainer(context),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('+ Тара'),
            ),
          ],
        ),
        const SizedBox(height: 4),

        if (containers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: const Text(
              'Нажмите "+ Тара", чтобы добавить варианты фасовки (например: 0.75л бугель, кеги или сладкие подпартии).',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: containers.length,
            itemBuilder: (context, index) {
              final c = containers[index];
              final hasSweetener = c.sweetenerType != null && c.sweetenerAmountGramsPerLiter > 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.white,
                elevation: 1,
                child: ListTile(
                  dense: true,
                  title: Text(
                    c.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${c.containerType} ${c.containerVolumeLiters}л × ${c.count} шт = ${c.totalVolumeLiters.toStringAsFixed(1)}л'
                    '${hasSweetener ? '\nПодсластитель: ${c.sweetenerType} (${c.sweetenerAmountGramsPerLiter} г/л)' : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                        onPressed: () => _editContainer(context, index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        onPressed: () => _removeContainer(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 8),

        // Сводка по объемам
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isExceeded ? Colors.red.shade50 : Colors.amber.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isExceeded ? Colors.red : Colors.amber.shade300),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Исходный объем сусла:', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                  Text('${totalJuiceVolume.toStringAsFixed(1)} л', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Разлито по подпартиям:', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                  Text('${totalBottled.toStringAsFixed(1)} л', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isExceeded ? 'ПРЕВЫШЕНИЕ ОБЪЕМА:' : 'Осадок / Потери:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isExceeded ? Colors.red : Colors.brown,
                    ),
                  ),
                  Text(
                    isExceeded
                        ? '+${(totalBottled - totalJuiceVolume).toStringAsFixed(1)} л'
                        : '${lossVolume.toStringAsFixed(1)} л',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isExceeded ? Colors.red : Colors.brown,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}