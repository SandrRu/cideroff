import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/hydrometry_calculator.dart';
import '../../../data/models/batch_model.dart';
import '../../../data/models/batch_container_model.dart';
import '../../../data/models/recipe_model.dart';
import '../../../data/models/yeast_model.dart';
import '../../providers/batch_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/yeast_provider.dart';
import '../history/history_screen.dart';
import '../label/label_template_list_screen.dart';
import 'widgets/containers_inline_list.dart';

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
  final _primingSugarController = TextEditingController(text: '7.0');

  List<BatchContainer> _draftContainers = [];
  bool _isContainersInitialized = false;

  String? _selectedYeastId;
  bool _isYeastInitialized = false;

  double? _calculatedAbv;
  DateTime _selectedStepDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _sugarController.dispose();
    _alcoholController.dispose();
    _noteController.dispose();
    _primingSugarController.dispose();
    super.dispose();
  }

  double? _parseDouble(String? text) {
    if (text == null) return null;
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  void _recalculateAbv(Batch batch) {
    final currentSugarGrams = _parseDouble(_sugarController.text);
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

                final updatedBatch = batch.copyWith(
                  name: nameEditController.text.trim(),
                  notes: notesEditController.text.trim(),
                  rawSpiritVolume: _parseDouble(rawSpiritVolumeEdit.text),
                  rawSpiritABV: _parseDouble(rawSpiritAbvEdit.text),
                  barrelNotes: barrelNotesEdit.text.trim(),
                );

                Navigator.pop(dialogContext);

                await batchProvider.updateBatch(updatedBatch);

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Партия обновлена')),
                );
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

                Navigator.pop(dialogContext);
                await batchProvider.deleteBatch(batch.id);

                if (!mounted) return;

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Партия "${batch.name}" удалена')),
                );
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
    final yeastProvider = context.watch<YeastProvider>();

    if (recipeProvider.isLoading || batchProvider.isLoading || yeastProvider.isLoading) {
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

    if (!_isContainersInitialized && batch.containers.isNotEmpty) {
      _draftContainers = List.from(batch.containers);
      _isContainersInitialized = true;
    }

    if (!_isYeastInitialized) {
      _selectedYeastId = batch.yeastId;
      _isYeastInitialized = true;
    }

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

    String? currentYeastName;
    if (batch.yeastId != null && yeastProvider.yeasts.isNotEmpty) {
      final yMatches = yeastProvider.yeasts.where((y) => y.id == batch.yeastId);
      if (yMatches.isNotEmpty) {
        currentYeastName = yMatches.first.name;
      }
    }

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
                    if (currentYeastName != null)
                      _infoRow('Дрожжи', currentYeastName),
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
                      _infoRow('Крепость', '${batch.finalAlcohol ?? 0}% об.'),
                      if (batch.lossVolume != null)
                        _infoRow('Осадок / Потери', '${batch.lossVolume!.toStringAsFixed(1)} л'),
                      
                      if (batch.containers.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Разлитые подпартии:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...batch.containers.map((c) {
                          final hasSweetener = c.sweetenerType != null && c.sweetenerAmountGramsPerLiter > 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '• ${c.title} (${c.containerType})'
                                    '${hasSweetener ? ' [${c.sweetenerType}: ${c.sweetenerAmountGramsPerLiter} г/л]' : ''}',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${c.count} шт. × ${c.containerVolumeLiters}л (${c.totalVolumeLiters.toStringAsFixed(1)}л)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
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

                        if (stepIndex == 0) ...[
                          DropdownButtonFormField<String?>(
                            value: yeastProvider.yeasts.any((y) => y.id == _selectedYeastId)
                                ? _selectedYeastId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Выберите штамм дрожжей',
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
                          const SizedBox(height: 16),

                          ContainersInlineList(
                            batchId: batch.id,
                            totalJuiceVolume: batch.juiceVolume,
                            containers: _draftContainers,
                            onChanged: (newList) {
                              setState(() {
                                _draftContainers = newList;
                              });
                            },
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

                                    final baseSugar = _parseDouble(_sugarController.text);
                                    final primingGrams = _parseDouble(_primingSugarController.text) ?? 0.0;

                                    try {
                                      if (stepIndex == 0 && _selectedYeastId != batch.yeastId) {
                                        final updatedYeastBatch = batch.copyWith(yeastId: _selectedYeastId);
                                        await batchProvider.updateBatch(updatedYeastBatch);
                                      }

                                      await batchProvider.completeCurrentStep(
                                        batch: batch,
                                        recipe: currentRecipe!,
                                        sugarMeasured: baseSugar,
                                        alcoholMeasured: _parseDouble(_alcoholController.text),
                                        note: _noteController.text,
                                        containers: currentStep.isBottlingStep ? _draftContainers : null,
                                        stepDate: _selectedStepDate,
                                        primingSugarGrams: primingGrams,
                                        finalSugarWithPriming: baseSugar,
                                      );

                                      if (!mounted) return;

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Шаг успешно завершён')),
                                      );
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
                                ? 'Завершить и разлить по подпартиям'
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
    final currentSugar = _parseDouble(_sugarController.text) ?? batch.initialSugar;
    final primingGrams = _parseDouble(_primingSugarController.text) ?? 0.0;

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
                    'Итоговая базовая сладость: ${currentSugar.toStringAsFixed(1)} г/100мл',
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