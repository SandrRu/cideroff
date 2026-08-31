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

  bool get _isReadOnly => widget.recipe != null && !widget.recipe!.isCustom;

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

  @override
  void dispose() {
    _titleRuController.dispose();
    _descRuController.dispose();
    super.dispose();
  }

  void _addStep() {
    if (_isReadOnly) return;
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
    if (_isReadOnly) return;

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
              title: Text('Настройка шага ${index + 1}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Название шага',
                        hintText: 'Например: Снятие с осадка',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Длительность (дней)',
                        hintText: '14',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: instructionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Инструкция к шагу',
                        hintText: 'Подробное описание действий на этом этапе',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Требуемые замеры и параметры',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            dense: true,
                            title: const Text('Замер сахара'),
                            subtitle: const Text('Включить ввод граммов сахара на 100 мл'),
                            value: requiresSugar,
                            activeColor: Colors.amber,
                            onChanged: (v) => setDialogState(() => requiresSugar = v),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            dense: true,
                            title: const Text('Замер крепости'),
                            subtitle: const Text('Включить ввод спирта (% об.)'),
                            value: requiresAlcohol,
                            activeColor: Colors.amber,
                            onChanged: (v) => setDialogState(() => requiresAlcohol = v),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            dense: true,
                            title: const Text('Этап розлива (Финал)'),
                            subtitle: const Text('Активирует форму фасовки по подпартиям'),
                            value: isBottling,
                            activeColor: Colors.green,
                            onChanged: (v) => setDialogState(() => isBottling = v),
                          ),
                        ],
                      ),
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
        title: Text(
          widget.recipe == null
              ? 'Новый рецепт'
              : (_isReadOnly
                  ? 'Просмотр системного рецепта'
                  : 'Редактирование рецепта'),
        ),
        actions: [
          if (!_isReadOnly)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Сохранить',
              onPressed: _saveRecipe,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isReadOnly)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: Colors.amber),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Это системный рецепт, его нельзя редактировать. Вы можете продублировать его и изменить копию.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        await context
                            .read<RecipeProvider>()
                            .duplicateAsCustom(widget.recipe!);
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Создана пользовательская копия рецепта',
                            ),
                          ),
                        );
                      },
                      child: const Text('Дублировать'),
                    ),
                  ],
                ),
              ),

            TextFormField(
              controller: _titleRuController,
              enabled: !_isReadOnly,
              decoration: const InputDecoration(
                labelText: 'Название рецепта',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Введите название' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descRuController,
              enabled: !_isReadOnly,
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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (!_isReadOnly)
                  TextButton.icon(
                    onPressed: _addStep,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить шаг'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isReadOnly)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
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
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  step.getTitle('ru'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Интервал: ${step.durationDays} дн.'),
                          if (step.getInstruction('ru').isNotEmpty)
                            Text(
                              step.getInstruction('ru'),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          if (step.requiresSugarMeasurement)
                            const Text('• Требуется замер сахара'),
                          if (step.requiresAlcoholMeasurement)
                            const Text('• Требуется замер спирта'),
                          if (step.isBottlingStep)
                            const Text(
                              '• Этап розлива (финал)',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              )
            else
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
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    step.getTitle('ru'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'Редактировать',
                                  onPressed: () => _editStep(step, index),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
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
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (step.requiresSugarMeasurement)
                              const Text('• Требуется замер сахара'),
                            if (step.requiresAlcoholMeasurement)
                              const Text('• Требуется замер спирта'),
                            if (step.isBottlingStep)
                              const Text(
                                '• Этап розлива (финал)',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
    if (_isReadOnly) return;

    if (_formKey.currentState!.validate()) {
      final newRecipe = Recipe(
        id: widget.recipe?.id,
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