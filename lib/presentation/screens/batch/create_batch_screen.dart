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
  Recipe? _selectedRecipe;

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

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final allRecipes = recipeProvider.recipes;
    final langCode = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat('dd.MM.yyyy');

    // Фильтрация рецептов по выбранному типу напитка
    final filteredRecipes = allRecipes.where((recipe) {
      final isCalvadosRecipe = recipe.id.contains('calvados') ||
          (recipe.title['ru'] ?? '').toLowerCase().contains('кальвадос');
      return _selectedType == BatchType.calvados ? isCalvadosRecipe : !isCalvadosRecipe;
    }).toList();

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

                    // Получаем обновленный список под новый тип и сбрасываем рецепт
                    final newFiltered = allRecipes.where((recipe) {
                      final isCalvadosRecipe = recipe.id.contains('calvados') ||
                          (recipe.title['ru'] ?? '').toLowerCase().contains('кальвадос');
                      return _selectedType == BatchType.calvados ? isCalvadosRecipe : !isCalvadosRecipe;
                    }).toList();

                    _selectedRecipe = newFiltered.isNotEmpty ? newFiltered.first : null;
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
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Введите название партии' : null,
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

            // Выбор рецепта (только отфильтрованные)
            DropdownButtonFormField<Recipe>(
              value: filteredRecipes.contains(_selectedRecipe) ? _selectedRecipe : null,
              decoration: const InputDecoration(
                labelText: 'Рецепт приготовления',
                border: OutlineInputBorder(),
              ),
              items: filteredRecipes.map((recipe) {
                return DropdownMenuItem<Recipe>(
                  value: recipe,
                  child: Text(recipe.getTitle(langCode)),
                );
              }).toList(),
              onChanged: (recipe) {
                setState(() {
                  _selectedRecipe = recipe;
                });
              },
              validator: (v) => v == null ? 'Выберите рецепт' : null,
            ),
            const SizedBox(height: 16),

            // Объем сока и начальный сахар
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _volumeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      final batchProvider = context.read<BatchProvider>();
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      await batchProvider.createBatch(
        name: _nameController.text.trim(),
        appleVariety: _appleVarietyController.text.trim(),
        initialSugar: _parseDouble(_initialSugarController.text) ?? 0.0,
        juiceVolume: _parseDouble(_volumeController.text)!,
        pressDate: _pressDate,
        recipe: _selectedRecipe!,
        notes: _notesController.text.trim(),
        type: _selectedType,
        yeastId: null,
        rawSpiritVolume: _parseDouble(_rawSpiritVolumeController.text),
        rawSpiritAbv: _parseDouble(_rawSpiritAbvController.text),
        barrelNotes: _barrelNotesController.text.trim(),
      );

      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Партия успешно создана')),
        );
      }
    }
  }
}