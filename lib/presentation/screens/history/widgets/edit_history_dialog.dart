import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/batch_history_model.dart';
import '../../../../data/models/batch_model.dart';
import '../../../../data/models/recipe_model.dart'; // <-- Не забудьте импортировать модель рецепта

class EditHistoryDialog extends StatefulWidget {
  final BatchHistory history;
  final Batch? batch;
  final RecipeStep? recipeStep; // <-- Принимаем шаг рецепта

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
  late TextEditingController _nonFermentableSugarController;
  late TextEditingController _noteController;
  
  late DateTime _selectedTimestamp;

  @override
  void initState() {
    super.initState();
    _sugarController = TextEditingController(
      text: widget.history.sugarMeasured?.toString() ?? '',
    );
    _alcoholController = TextEditingController(
      text: widget.history.alcoholMeasured?.toString() ?? '',
    );

    double? initialNonFermentable = widget.history.nonFermentableSugarGrams;
    
    if ((initialNonFermentable == null || initialNonFermentable == 0) && widget.batch != null) {
      initialNonFermentable = widget.batch?.nonFermentableSugarGrams;
    }

    _nonFermentableSugarController = TextEditingController(
      text: initialNonFermentable != null && initialNonFermentable > 0 
          ? initialNonFermentable.toString() 
          : '',
    );

    _noteController = TextEditingController(text: widget.history.note ?? '');
    _selectedTimestamp = widget.history.timestamp;
  }

  @override
  void dispose() {
    _sugarController.dispose();
    _alcoholController.dispose();
    _nonFermentableSugarController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    // Определяем видимость полей на основе флагов RecipeStep
    // Если recipeStep не передан, фоллбэк проверяет наличие сохраненных данных в истории
    final bool showSugar = widget.recipeStep?.requiresSugarMeasurement ?? (widget.history.sugarMeasured != null);
    final bool showAlcohol = widget.recipeStep?.requiresAlcoholMeasurement ?? (widget.history.alcoholMeasured != null);
    final bool showNonFermentable = widget.recipeStep?.isBottlingStep ?? (widget.history.nonFermentableSugarGrams != null && widget.history.nonFermentableSugarGrams! > 0);

    return AlertDialog(
      title: const Text('Редактирование шага'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Нередактируемое поле: Название шага
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

              // Нередактируемое поле: Статус / Действие
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

              // Выбор даты и времени выполнения шага
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

              // Поле замера сахара (если разрешено рецептом)
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

              // Поле крепости/алкоголя (если разрешено рецептом)
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

              // Несбраживаемые сахара (только для этапа розлива/финала)
              if (showNonFermentable) ...[
                TextFormField(
                  controller: _nonFermentableSugarController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Несбраживаемые сахара (г/л)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Заметка доступна всегда
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
                // Сохраняем введенное значение, либо оставляем старое, если поле было скрыто
                sugarMeasured: showSugar ? double.tryParse(_sugarController.text.replaceAll(',', '.')) : widget.history.sugarMeasured,
                alcoholMeasured: showAlcohol ? double.tryParse(_alcoholController.text.replaceAll(',', '.')) : widget.history.alcoholMeasured,
                nonFermentableSugarGrams: showNonFermentable ? double.tryParse(_nonFermentableSugarController.text.replaceAll(',', '.')) : widget.history.nonFermentableSugarGrams,
                note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
              );
              Navigator.pop(context, updatedHistory);
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}