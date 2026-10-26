import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../data/models/batch_model.dart';
import '../../../data/models/recipe_model.dart';
import '../../providers/batch_provider.dart';
import '../../providers/recipe_provider.dart';

class CreateBatchScreen extends StatefulWidget {
  const CreateBatchScreen({super.key});

  @override
  State<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends State<CreateBatchScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _appleVarietyController = TextEditingController();
  final _volumeController = TextEditingController(text: '10.0');
  final _initialSugarController = TextEditingController(text: '12.0');
  final _notesController = TextEditingController();

  // Контроллеры для Кальвадоса
  final _rawSpiritVolumeController = TextEditingController();
  final _rawSpiritAbvController = TextEditingController();
  final _barrelNotesController = TextEditingController();

  BatchType _selectedType = BatchType.cider;
  DateTime _pressDate = DateTime.now();

  // Список выбранных рецептов/этапов
  final List<Recipe> _selectedRecipes = [];

  @override
  void dispose() {
    _nameController.dispose();
    _appleVarietyController.dispose();
    _volumeController.dispose();
    _initialSugarController.dispose();
    _notesController.dispose();
    _rawSpiritVolumeController.dispose();
    _rawSpiritAbvController.dispose();
    _barrelNotesController.dispose();
    super.dispose();
  }

  double? _parseDouble(String? text) {
    if (text == null) return null;
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  void _showAddRecipeBottomSheet(List<Recipe> allRecipes, String langCode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Выберите рецепт или этап',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: allRecipes.length,
                    itemBuilder: (context, index) {
                      final recipe = allRecipes[index];
                      final isSelected = _selectedRecipes.contains(recipe);

                      return ListTile(
                        leading: Icon(
                          recipe.isCustom ? Icons.extension : Icons.menu_book,
                          color: Colors.amber.shade800,
                        ),
                        title: Text(recipe.getTitle(langCode)),
                        subtitle: Text('${recipe.steps.length} шагов'),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : const Icon(Icons.add_circle_outline),
                        onTap: () {
                          setState(() {
                            if (!isSelected) {
                              _selectedRecipes.add(recipe);
                            }
                          });
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
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
    final recipeProvider = context.watch<RecipeProvider>();
    final allRecipes = recipeProvider.recipes;
    final langCode = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat('dd.MM.yyyy');

    // Автоматический первичный выбор стартового рецепта по умолчанию, если список еще пуст
    if (_selectedRecipes.isEmpty && allRecipes.isNotEmpty) {
      final defaultRecipe = allRecipes.firstWhere(
        (r) => _selectedType == BatchType.calvados
            ? (r.id.contains('calvados') ||
                r.getTitle('ru').toLowerCase().contains('кальвадос'))
            : (!r.id.contains('calvados') &&
                !r.getTitle('ru').toLowerCase().contains('кальвадос')),
        orElse: () => allRecipes.first,
      );
      _selectedRecipes.add(defaultRecipe);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая партия'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Переключатель типа партии
            Center(
              child: SegmentedButton<BatchType>(
                segments: const [
                  ButtonSegment(
                    value: BatchType.cider,
                    label: Text('🍏 Сидр'),
                  ),
                  ButtonSegment(
                    value: BatchType.calvados,
                    label: Text('🥃 Кальвадос'),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),

            // Название партии
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Название партии',
                hintText: _selectedType == BatchType.cider
                    ? 'Например: Антоновка 2026'
                    : 'Например: Кальвадос Бочка №1',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Введите название партии'
                  : null,
            ),
            const SizedBox(height: 16),

            // Сорт яблок
            TextFormField(
              controller: _appleVarietyController,
              decoration: const InputDecoration(
                labelText: 'Сорт яблок',
                hintText: 'Например: Антоновка, Грушовка',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Укажите сорт яблок' : null,
            ),
            const SizedBox(height: 16),

            // Блок гибкого выбора рецептов / технологических карт
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Рецепты и технологические этапы',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _showAddRecipeBottomSheet(allRecipes, langCode),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Добавить'),
                        ),
                      ],
                    ),
                    if (_selectedRecipes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Выберите хотя бы один рецепт для партии',
                          style: TextStyle(color: Colors.red),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _selectedRecipes.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _selectedRecipes.removeAt(oldIndex);
                            _selectedRecipes.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final recipe = _selectedRecipes[index];
                          return ListTile(
                            key: ValueKey('${recipe.id}_$index'),
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.amber,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black),
                              ),
                            ),
                            title: Text(recipe.getTitle(langCode)),
                            subtitle: Text('${recipe.steps.length} шагов'),
                            trailing: _selectedRecipes.length > 1
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _selectedRecipes.removeAt(index);
                                      });
                                    },
                                  )
                                : const Icon(Icons.drag_handle),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Объем сока и начальный сахар
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _volumeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Объём сока (л)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Укажите объём';
                      if (_parseDouble(v) == null) return 'Не число';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _initialSugarController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Нач. сахар (г/100мл)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Укажите сахар';
                      if (_parseDouble(v) == null) return 'Не число';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Поля перегона для Кальвадоса
            if (_selectedType == BatchType.calvados) ...[
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Параметры Спирта-Сырца (Необязательно)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rawSpiritVolumeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Объём СС (л)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _rawSpiritAbvController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Крепость СС (% об.)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _barrelNotesController,
                        decoration: const InputDecoration(
                          labelText: 'Параметры бочки / щепы',
                          hintText: 'Дуб Майкоп, 10 литров, средний обжиг',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Дата отжима сока
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _pressDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() {
                    _pressDate = picked;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата отжима / Запуска',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(dateFormat.format(_pressDate)),
              ),
            ),
            const SizedBox(height: 16),

            // Поле для произвольных заметок
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Заметка к партии',
                hintText: 'Особенности отжима, температура, заметки и т.д.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Кнопка сохранения
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text(
                  'Создать партию',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedRecipes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите хотя бы один рецепт')),
        );
        return;
      }

      final batchProvider = context.read<BatchProvider>();
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      final primaryRecipe = _selectedRecipes.first;

      await batchProvider.createBatch(
        name: _nameController.text.trim(),
        appleVariety: _appleVarietyController.text.trim(),
        initialSugar: _parseDouble(_initialSugarController.text) ?? 0.0,
        juiceVolume: _parseDouble(_volumeController.text)!,
        pressDate: _pressDate,
        recipe: primaryRecipe,
        notes: _notesController.text.trim(),
        type: _selectedType,
        yeastId: null,
        rawSpiritVolume: _parseDouble(_rawSpiritVolumeController.text),
        rawSpiritAbv: _parseDouble(_rawSpiritAbvController.text),
        barrelNotes: _barrelNotesController.text.trim(),
      );

      // Если было выбрано несколько рецептов/этапов, привязываем остальные по порядку
      if (_selectedRecipes.length > 1) {
        final currentBatches = batchProvider.batches;
        if (currentBatches.isNotEmpty) {
          final createdBatch = currentBatches.first;
          for (int i = 1; i < _selectedRecipes.length; i++) {
            await batchProvider.attachRecipeToBatch(
              batchId: createdBatch.id,
              recipe: _selectedRecipes[i],
              sequenceOrder: i + 1,
            );
          }
        }
      }

      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Партия успешно создана')),
        );
      }
    }
  }
}
