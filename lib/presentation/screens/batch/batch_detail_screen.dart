import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/hydrometry_calculator.dart';
import '../../../data/models/batch_model.dart';
import '../../../data/models/recipe_model.dart';
import '../../providers/batch_provider.dart';
import '../../providers/recipe_provider.dart';
import '../history/history_screen.dart';
import '../label/label_template_list_screen.dart';

class BatchDetailScreen extends StatefulWidget {
  final String batchId;

  const BatchDetailScreen({super.key, required this.batchId});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  final _sugarController = TextEditingController();
  final _alcoholController = TextEditingController();
  final _noteController = TextEditingController();
  final _containerTypeController = TextEditingController();
  final _containerCountController = TextEditingController();
  final _primingSugarController = TextEditingController(text: '7.0');
  final _nonFermentableSugarController = TextEditingController(text: '0.0');

  final _distillateVolumeController = TextEditingController();
  final _distillateAbvController = TextEditingController();

  double? _calculatedAbv;
  DateTime _selectedStepDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _sugarController.dispose();
    _alcoholController.dispose();
    _noteController.dispose();
    _containerTypeController.dispose();
    _containerCountController.dispose();
    _primingSugarController.dispose();
    _nonFermentableSugarController.dispose();
    _distillateVolumeController.dispose();
    _distillateAbvController.dispose();
    super.dispose();
  }

  void _recalculateAbv(Batch batch) {
    final currentSugarGrams = double.tryParse(_sugarController.text);
    if (currentSugarGrams != null) {
      final abv = HydrometryCalculator.calculateAbvFromHydrometer(
        batch.initialSugar,
        currentSugarGrams,
        factor: 0.47,
      );

      setState(() {
        _calculatedAbv = abv;
        _alcoholController.text = abv.toStringAsFixed(1);
      });
    }
  }

  Future<void> _selectStepDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedStepDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null && pickedDate != _selectedStepDate) {
      setState(() {
        _selectedStepDate = pickedDate;
      });
    }
  }

  void _showEditBatchDialog(BuildContext context, Batch batch) {
    final nameEditController = TextEditingController(text: batch.name);
    final notesEditController = TextEditingController(text: batch.notes);
    final containerTypeEditController = TextEditingController(text: batch.containerType ?? '');
    final containerCountEditController = TextEditingController(
      text: batch.containerCount != null ? batch.containerCount.toString() : '',
    );
    final rawSpiritVolumeEdit = TextEditingController(
        text: batch.rawSpiritVolume != null ? batch.rawSpiritVolume.toString() : '');
    final rawSpiritAbvEdit = TextEditingController(
        text: batch.rawSpiritABV != null ? batch.rawSpiritABV.toString() : '');
    final barrelNotesEdit = TextEditingController(text: batch.barrelNotes ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Редактировать партию'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameEditController,
                  decoration: const InputDecoration(
                    labelText: 'Название партии',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesEditController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Заметка / Примечания',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (batch.type == BatchType.calvados) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rawSpiritVolumeEdit,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Спирт-сырец (л)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: rawSpiritAbvEdit,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Крепость СС (%)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: barrelNotesEdit,
                    decoration: const InputDecoration(
                      labelText: 'Параметры бочки / щепы',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: containerTypeEditController,
                  decoration: const InputDecoration(
                    labelText: 'Тип тары (Бугель, Стекло, ПЭТ)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: containerCountEditController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Количество емкостей (шт.)',
                    border: OutlineInputBorder(),
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
              onPressed: () async {
                final batchProvider = context.read<BatchProvider>();
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);

                final updatedBatch = batch.copyWith(
                  name: nameEditController.text.trim(),
                  notes: notesEditController.text.trim(),
                  containerType: containerTypeEditController.text.trim(),
                  containerCount: int.tryParse(containerCountEditController.text.trim()),
                  rawSpiritVolume: double.tryParse(rawSpiritVolumeEdit.text.trim()),
                  rawSpiritABV: double.tryParse(rawSpiritAbvEdit.text.trim()),
                  barrelNotes: barrelNotesEdit.text.trim(),
                );

                await batchProvider.updateBatch(updatedBatch);

                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Партия обновлена')),
                  );
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteBatchDialog(BuildContext context, Batch batch) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить партию?'),
          content: Text(
            'Вы уверены, что хотите удалить партию "${batch.name}"? Это действие нельзя будет отменить.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final batchProvider = context.read<BatchProvider>();
                final dialogNav = Navigator.of(dialogContext);
                final screenNav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                dialogNav.pop();
                await batchProvider.deleteBatch(batch.id);

                if (mounted) {
                  screenNav.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Партия "${batch.name}" удалена')),
                  );
                }
              },
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final batchProvider = context.watch<BatchProvider>();
    final recipeProvider = context.watch<RecipeProvider>();

    if (recipeProvider.isLoading || batchProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Партия')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final batch = batchProvider.batches.firstWhere(
      (b) => b.id == widget.batchId,
      orElse: () => Batch(
        name: '',
        appleVariety: '',
        initialSugar: 0,
        juiceVolume: 0,
        pressDate: DateTime.now(),
      ),
    );

    // Умный поиск рецепта с многоуровневым фоллбэком
    Recipe? currentRecipe;
    if (batch.currentRecipeId != null && recipeProvider.recipes.isNotEmpty) {
      final matches = recipeProvider.recipes.where((r) => r.id == batch.currentRecipeId).toList();
      if (matches.isNotEmpty) {
        currentRecipe = matches.first;
      }
    }

    currentRecipe ??= recipeProvider.recipes.firstWhere(
      (r) {
        final isCalvados = r.id.contains('calvados') || (r.title['ru'] ?? '').toLowerCase().contains('кальвадос');
        return batch.type == BatchType.calvados ? isCalvados : !isCalvados;
      },
      orElse: () => recipeProvider.recipes.isNotEmpty
          ? recipeProvider.recipes.first
          : Recipe(
              title: {'ru': 'Стандартный'},
              description: {'ru': ''},
              steps: [],
            ),
    );

    final stepIndex = batch.currentStepIndex ?? 0;
    final currentStep = (currentRecipe.steps.isNotEmpty && stepIndex < currentRecipe.steps.length)
        ? currentRecipe.steps[stepIndex]
        : null;

    final dateFormat = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(batch.type == BatchType.calvados ? '🥃 ' : '🍏 '),
            Expanded(
              child: Text(
                batch.name.isNotEmpty ? batch.name : 'Партия',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Редактировать',
            onPressed: () => _showEditBatchDialog(context, batch),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Удалить партию',
            onPressed: () => _showDeleteBatchDialog(context, batch),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'Макет этикетки',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LabelTemplateListScreen(batch: batch),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.amber),
            tooltip: 'История измерений',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(batchId: batch.id),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow('Тип напитка', batch.type == BatchType.calvados ? 'Кальвадос' : 'Сидр'),
                    _infoRow('Сорт яблок', batch.appleVariety),
                    _infoRow('Объём сока', '${batch.juiceVolume} л'),
                    _infoRow('Начальный сахар', '${batch.initialSugar} г/100мл'),
                    _infoRow('Дата запуска', dateFormat.format(batch.pressDate)),

                    if (batch.type == BatchType.calvados) ...[
                      const Divider(),
                      if (batch.rawSpiritVolume != null)
                        _infoRow(
                          'Спирт-сырец',
                          '${batch.rawSpiritVolume} л (${batch.rawSpiritABV ?? 0}% об.)',
                        ),
                      if (batch.distillateVolume != null)
                        _infoRow(
                          'Дистиллят (Сердце)',
                          '${batch.distillateVolume} л (${batch.distillateABV ?? 0}% об.)',
                        ),
                      if (batch.barrelNotes != null && batch.barrelNotes!.isNotEmpty)
                        _infoRow('Выдержка', batch.barrelNotes!),
                      if (batch.daysInAging != null)
                        _infoRow('Срок выдержки', '${batch.daysInAging} дн.'),
                    ],

                    if (batch.notes.isNotEmpty)
                      _infoRow('Заметка', batch.notes),
                    if (batch.containerType != null && batch.containerType!.isNotEmpty)
                      _infoRow(
                        'Тара',
                        '${batch.containerType} (${batch.containerCount ?? 0} шт.)',
                      ),
                    if (batch.status == BatchStatus.completed) ...[
                      const Divider(),
                      _infoRow('Остаточный сахар', '${batch.finalSugar ?? 0} г/100мл'),
                      if (batch.primingSugarGrams != null && batch.primingSugarGrams! > 0)
                        _infoRow('Декстроза', '${batch.primingSugarGrams} г/л'),
                      if (batch.nonFermentableSugarGrams != null && batch.nonFermentableSugarGrams! > 0)
                        _infoRow('Несбращ. сахар', '${batch.nonFermentableSugarGrams} г/л'),
                      _infoRow(
                        'Расчётная сладость',
                        '${batch.calculatedFinalSweetness?.toStringAsFixed(1) ?? batch.finalSugar ?? 0} г/100мл',
                      ),
                      _infoRow('Крепость', '${batch.finalAlcohol ?? 0}% об.'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LabelTemplateListScreen(batch: batch),
                            ),
                          );
                        },
                        icon: const Icon(Icons.label_outlined),
                        label: const Text('Сформировать этикетку'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (batch.status == BatchStatus.inProgress && currentStep != null) ...[
              Text(
                'Шаг ${(batch.currentStepIndex ?? 0) + 1}: ${currentStep.getTitle('ru')}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                currentStep.getInstruction('ru'),
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),

              Theme(
                data: Theme.of(context).copyWith(
                  brightness: Brightness.light,
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                        brightness: Brightness.light,
                        onSurface: Colors.black87,
                      ),
                  inputDecorationTheme: const InputDecorationTheme(
                    labelStyle: TextStyle(color: Colors.black87),
                    hintStyle: TextStyle(color: Colors.black45),
                    helperStyle: TextStyle(color: Colors.black87),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black38),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.amber, width: 2),
                    ),
                  ),
                ),
                child: Card(
                  color: Colors.amber.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, color: Colors.amber),
                                const SizedBox(width: 8),
                                Text(
                                  batch.nextStepDate != null
                                      ? 'Планировался: ${dateFormat.format(batch.nextStepDate!)}'
                                      : 'Без срока',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.calculate_outlined, color: Colors.amber),
                              tooltip: 'Открыть калькулятор',
                              onPressed: () => _showHydrometrySheet(
                                context,
                                batch,
                                isBottlingStep: currentStep.isBottlingStep,
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),

                        InkWell(
                          onTap: () => _selectStepDate(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.amber.shade400),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 18, color: Colors.amber),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Дата выполнения: ${dateFormat.format(_selectedStepDate)}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.arrow_drop_down, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (currentStep.requiresSugarMeasurement) ...[
                          TextField(
                            controller: _sugarController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Замер сахара (г/100мл)',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.sync, color: Colors.amber),
                                onPressed: () => _recalculateAbv(batch),
                              ),
                            ),
                            onChanged: (_) => _recalculateAbv(batch),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (currentStep.requiresAlcoholMeasurement) ...[
                          TextField(
                            controller: _alcoholController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Крепость (% об.)',
                              helperText: _calculatedAbv != null
                                  ? 'Рассчитано по начальному сахару: ${_calculatedAbv!.toStringAsFixed(1)}%'
                                  : null,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (currentStep.isBottlingStep) ...[
                          TextField(
                            controller: _primingSugarController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.black87),
                            decoration: const InputDecoration(
                              labelText: 'Катализатор / Декстроза (г/л)',
                              hintText: 'Например: 7.0',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nonFermentableSugarController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.black87),
                            decoration: const InputDecoration(
                              labelText: 'Несбраживаемые сахара (г/л)',
                              hintText: 'Например: 15.0 (Ксилит / Эритрит)',
                              helperText: 'Увеличивает итоговую сладость готового сидра',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _containerTypeController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: const InputDecoration(
                              labelText: 'Тип тары (Бугель, Стекло, ПЭТ, Бочка)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _containerCountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.black87),
                            decoration: const InputDecoration(
                              labelText: 'Количество емкостей (шт.)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        TextField(
                          controller: _noteController,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.black87),
                          decoration: const InputDecoration(
                            labelText: 'Заметка к этапу',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    setState(() {
                                      _isSubmitting = true;
                                    });

                                    final messenger = ScaffoldMessenger.of(context);
                                    final baseSugar = double.tryParse(_sugarController.text);
                                    final primingGrams = double.tryParse(_primingSugarController.text) ?? 0.0;
                                    final nonFermentableGrams = double.tryParse(_nonFermentableSugarController.text) ?? 0.0;

                                    // Используем единую логику расчета сладости (г/л переводим в г/100мл делением на 10)
                                    final finalSweetness = (baseSugar != null)
                                        ? baseSugar + (nonFermentableGrams / 10.0)
                                        : null;

                                    try {
                                      await batchProvider.completeCurrentStep(
                                        batch: batch,
                                        recipe: currentRecipe!,
                                        sugarMeasured: baseSugar,
                                        alcoholMeasured: double.tryParse(_alcoholController.text),
                                        note: _noteController.text,
                                        containerType: _containerTypeController.text,
                                        containerCount: int.tryParse(_containerCountController.text),
                                        stepDate: _selectedStepDate,
                                        primingSugarGrams: primingGrams,
                                        nonFermentableSugarGrams: nonFermentableGrams,
                                        finalSugarWithPriming: finalSweetness,
                                      );

                                      if (mounted) {
                                        messenger.showSnackBar(
                                          const SnackBar(content: Text('Шаг успешно завершён')),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          _isSubmitting = false;
                                        });
                                      }
                                    }
                                  },
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(currentStep.isBottlingStep
                                ? 'Завершить и разлить'
                                : 'Шаг выполнен / Далее'),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showHydrometrySheet(BuildContext context, Batch batch, {bool isBottlingStep = false}) {
    final currentSugar = double.tryParse(_sugarController.text) ?? batch.initialSugar;
    final primingGrams = double.tryParse(_primingSugarController.text) ?? 0.0;
    final nonFermentableGrams = double.tryParse(_nonFermentableSugarController.text) ?? 0.0;

    final calculatedSweetness = currentSugar + (nonFermentableGrams / 10.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Быстрый гидрометр & Калькулятор',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.science_outlined, color: Colors.amber),
                title: const Text('Применить авторасчёт ABV'),
                subtitle: Text('Начальный сахар: ${batch.initialSugar} г/100мл'),
                onTap: () {
                  _recalculateAbv(batch);
                  Navigator.pop(context);
                },
              ),
              if (isBottlingStep) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.scale_outlined, color: Colors.amber),
                  title: const Text('Расчётная сладость розлива'),
                  subtitle: Text(
                    'Замер сахара: ${currentSugar.toStringAsFixed(1)} г/100мл\n'
                    'Декстроза (${primingGrams} г/л) → полностью сбродит в CO₂\n'
                    'Несбраживаемые (${nonFermentableGrams} г/л) → +${(nonFermentableGrams / 10.0).toStringAsFixed(1)} г/100мл\n'
                    'Итоговая сладость: ${calculatedSweetness.toStringAsFixed(1)} г/100мл',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}