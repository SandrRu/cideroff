import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/recipe_model.dart';
import '../../providers/recipe_provider.dart';

class RecipeEditorScreen extends StatefulWidget {
  final Recipe? recipe;

  const RecipeEditorScreen({super.key, this.recipe});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleRuController;
  late TextEditingController _descRuController;
  List<RecipeStep> _steps = [];

  @override
  void initState() {
    super.initState();
    _titleRuController = TextEditingController(
      text: widget.recipe?.title['ru'] ?? '',
    );
    _descRuController = TextEditingController(
      text: widget.recipe?.description['ru'] ?? '',
    );
    _steps = widget.recipe?.steps != null
        ? List.from(widget.recipe!.steps)
        : [
            RecipeStep(
              stepIndex: 0,
              title: {'ru': 'Первичное брожение'},
              instruction: {'ru': 'Установите гидрозатвор и поставьте в темное место.'},
              durationDays: 14,
              requiresSugarMeasurement: true,
            ),
          ];
  }

  void _addStep() {
    final newStep = RecipeStep(
      stepIndex: _steps.length,
      title: {'ru': 'Новый шаг'},
      instruction: {'ru': ''},
      durationDays: 7,
    );
    setState(() {
      _steps.add(newStep);
    });
    _editStep(newStep, _steps.length - 1);
  }

  void _editStep(RecipeStep step, int index) {
    final titleController = TextEditingController(text: step.getTitle('ru'));
    final instructionController = TextEditingController(text: step.getInstruction('ru'));
    final durationController = TextEditingController(text: step.durationDays.toString());

    bool requiresSugar = step.requiresSugarMeasurement;
    bool requiresAlcohol = step.requiresAlcoholMeasurement;
    bool isBottling = step.isBottlingStep;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Шаг ${index + 1}: Настройка'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Название шага',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Длительность (дней)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: instructionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Инструкция',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Замер сахара'),
                      value: requiresSugar,
                      activeColor: Colors.amber,
                      onChanged: (v) => setDialogState(() => requiresSugar = v ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Замер спирта'),
                      value: requiresAlcohol,
                      activeColor: Colors.amber,
                      onChanged: (v) => setDialogState(() => requiresAlcohol = v ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Этап розлива (финал)'),
                      value: isBottling,
                      activeColor: Colors.green,
                      onChanged: (v) => setDialogState(() => isBottling = v ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final updatedStep = RecipeStep(
                      stepIndex: index,
                      title: {'ru': titleController.text.trim()},
                      instruction: {'ru': instructionController.text.trim()},
                      durationDays: int.tryParse(durationController.text) ?? 1,
                      requiresSugarMeasurement: requiresSugar,
                      requiresAlcoholMeasurement: requiresAlcohol,
                      isBottlingStep: isBottling,
                    );

                    setState(() {
                      _steps[index] = updatedStep;
                    });

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Новый рецепт' : 'Редактирование рецепта'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveRecipe,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleRuController,
              decoration: const InputDecoration(
                labelText: 'Название рецепта',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Введите название' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descRuController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Описание рецепта',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Шаги рецепта (${_steps.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить шаг'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _steps.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _steps.removeAt(oldIndex);
                  _steps.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final step = _steps[index];
                return Card(
                  key: ValueKey(step.hashCode),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _editStep(step, index),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.amber,
                                child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.black)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  step.getTitle('ru'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                tooltip: 'Редактировать',
                                onPressed: () => _editStep(step, index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Удалить',
                                onPressed: () {
                                  setState(() {
                                    _steps.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                          Text('Интервал: ${step.durationDays} дн.'),
                          if (step.getInstruction('ru').isNotEmpty)
                            Text(
                              step.getInstruction('ru'),
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (step.requiresSugarMeasurement) const Text('• Требуется замер сахара'),
                          if (step.requiresAlcoholMeasurement) const Text('• Требуется замер спирта'),
                          if (step.isBottlingStep) const Text('• Этап розлива (финал)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveRecipe() {
    if (_formKey.currentState!.validate()) {
      final newRecipe = Recipe(
        id: widget.recipe?.id, // Передаем прежний ID при обновлении рецепта
        title: {'ru': _titleRuController.text},
        description: {'ru': _descRuController.text},
        isCustom: true,
        isFavorite: widget.recipe?.isFavorite ?? false,
        steps: _steps,
      );

      context.read<RecipeProvider>().saveRecipe(newRecipe);
      Navigator.pop(context);
    }
  }
}