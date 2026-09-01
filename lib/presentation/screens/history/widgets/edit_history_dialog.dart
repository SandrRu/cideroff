import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/batch_container_model.dart';
import '../../../../data/models/batch_history_model.dart';
import '../../../../data/models/batch_model.dart';
import '../../../../data/models/recipe_model.dart';
import '../../../providers/yeast_provider.dart';
import '../../batch/widgets/containers_inline_list.dart';

class EditHistoryDialogResult {
  final BatchHistory history;
  final String? yeastId;

  EditHistoryDialogResult({
    required this.history,
    this.yeastId,
  });
}

class EditHistoryDialog extends StatefulWidget {
  final BatchHistory history;
  final Batch? batch;
  final RecipeStep? recipeStep;

  const EditHistoryDialog({
    super.key,
    required this.history,
    this.batch,
    this.recipeStep,
  });

  @override
  State<EditHistoryDialog> createState() => _EditHistoryDialogState();
}

class _EditHistoryDialogState extends State<EditHistoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _sugarController;
  late TextEditingController _alcoholController;
  late TextEditingController _noteController;

  late DateTime _selectedTimestamp;
  late List<BatchContainer> _draftContainers;
  String? _selectedYeastId;

  @override
  void initState() {
    super.initState();
    _sugarController = TextEditingController(
      text: widget.history.sugarMeasured?.toString() ?? '',
    );
    _alcoholController = TextEditingController(
      text: widget.history.alcoholMeasured?.toString() ?? '',
    );
    _noteController = TextEditingController(text: widget.history.note ?? '');
    _selectedTimestamp = widget.history.timestamp;
    _selectedYeastId = widget.batch?.yeastId;

    if (widget.history.containers.isNotEmpty) {
      _draftContainers = List.from(widget.history.containers);
    } else if (widget.batch != null && widget.batch!.containers.isNotEmpty) {
      _draftContainers = List.from(widget.batch!.containers);
    } else {
      _draftContainers = [];
    }
  }

  @override
  void dispose() {
    _sugarController.dispose();
    _alcoholController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedTimestamp,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedTimestamp),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedTimestamp = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  double? _parseDouble(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final yeastProvider = context.watch<YeastProvider>();

    final bool isFirstStep = (widget.recipeStep?.stepIndex == 0) ||
        widget.history.stepTitle.toLowerCase().contains('первичное') ||
        widget.history.stepTitle.toLowerCase().contains('постановка') ||
        widget.history.actionName.toLowerCase().contains('создана');

    final bool isBottling = (widget.recipeStep?.isBottlingStep ?? false) ||
        widget.history.actionName.contains('Завершение') ||
        widget.history.actionName.contains('розлив') ||
        widget.history.stepTitle.toLowerCase().contains('розлив') ||
        widget.history.containers.isNotEmpty;

    final bool showSugar = widget.recipeStep?.requiresSugarMeasurement ??
        (widget.history.sugarMeasured != null);
    final bool showAlcohol = widget.recipeStep?.requiresAlcoholMeasurement ??
        (widget.history.alcoholMeasured != null);

    final double juiceVolume = widget.batch?.juiceVolume ?? 0.0;

    return AlertDialog(
      title: const Text('Редактирование шага'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade600),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Название шага',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.history.stepTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade600),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Действие / Статус',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.history.actionName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _pickDateTime(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade600),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: Colors.amber),
                            const SizedBox(width: 10),
                            Text(
                              'Дата: ${dateFormat.format(_selectedTimestamp)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                        const Icon(Icons.edit_calendar, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (isFirstStep) ...[
                  DropdownButtonFormField<String?>(
                    value: yeastProvider.yeasts.any((y) => y.id == _selectedYeastId)
                        ? _selectedYeastId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Штамм дрожжей',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.grain, color: Colors.amber),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Не выбрано / Дикие дрожжи'),
                      ),
                      ...yeastProvider.yeasts.map((y) {
                        return DropdownMenuItem<String?>(
                          value: y.id,
                          child: Text(y.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedYeastId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                if (showSugar) ...[
                  TextFormField(
                    controller: _sugarController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Замер сахара (г/100мл)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (showAlcohol) ...[
                  TextFormField(
                    controller: _alcoholController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Крепость (% об.)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (isBottling) ...[
                  ContainersInlineList(
                    batchId: widget.history.batchId,
                    totalJuiceVolume: juiceVolume,
                    containers: _draftContainers,
                    onChanged: (newList) {
                      setState(() {
                        _draftContainers = newList;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Заметка',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final updatedHistory = BatchHistory(
                id: widget.history.id,
                batchId: widget.history.batchId,
                timestamp: _selectedTimestamp,
                stepTitle: widget.history.stepTitle,
                actionName: widget.history.actionName,
                sugarMeasured: showSugar ? _parseDouble(_sugarController.text) : widget.history.sugarMeasured,
                alcoholMeasured: showAlcohol ? _parseDouble(_alcoholController.text) : widget.history.alcoholMeasured,
                nonFermentableSugarGrams: widget.history.nonFermentableSugarGrams,
                containers: isBottling ? _draftContainers : widget.history.containers,
                note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
              );

              Navigator.pop(
                context,
                EditHistoryDialogResult(
                  history: updatedHistory,
                  yeastId: _selectedYeastId,
                ),
              );
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}