import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cider_off/data/models/batch_container_model.dart';
import 'package:cider_off/presentation/providers/sweetener_provider.dart';

class ContainerFormDialog extends StatefulWidget {
  final String batchId;
  final BatchContainer? container;

  const ContainerFormDialog({
    super.key,
    required this.batchId,
    this.container,
  });

  @override
  State<ContainerFormDialog> createState() => _ContainerFormDialogState();
}

class _ContainerFormDialogState extends State<ContainerFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _sweetenerAmountController;
  late TextEditingController _volumeController;
  late TextEditingController _countController;

  String? _selectedSweetenerType;
  String _selectedContainerType = 'Бутылка (бугель)';

  final List<String> _containerOptions = [
    'Бутылка (бугель)',
    'Бутылка (кроненпропка)',
    'ПЭТ бутылка',
    'Кег (Корнелиус / Спидфит)',
    'Стеклянный бутыль / Банка',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.container;
    _titleController = TextEditingController(text: c?.title ?? 'Подпартия №1');
    _sweetenerAmountController = TextEditingController(
      text: c != null ? c.sweetenerAmountGramsPerLiter.toString() : '0.0',
    );
    _volumeController = TextEditingController(
      text: c != null ? c.containerVolumeLiters.toString() : '0.75',
    );
    _countController = TextEditingController(
      text: c != null ? c.count.toString() : '10',
    );

    _selectedSweetenerType = c?.sweetenerType;

    if (c != null && _containerOptions.contains(c.containerType)) {
      _selectedContainerType = c.containerType;
    }

    // Инициализация загрузки списка подсластителей из БД
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SweetenerProvider>().loadSweetenerTypes();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sweetenerAmountController.dispose();
    _volumeController.dispose();
    _countController.dispose();
    super.dispose();
  }

  double? _parseDouble(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.container == null ? 'Добавить тару / подпартию' : 'Редактировать тару'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Название подпартии',
                  hintText: 'Например: Сухой 0.75л или Ксилит 15г/л',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedContainerType,
                decoration: const InputDecoration(
                  labelText: 'Тип емкости',
                  border: OutlineInputBorder(),
                ),
                items: _containerOptions.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedContainerType = val);
                },
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _volumeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Объем 1 шт (л)',
                        hintText: '0.75',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final val = _parseDouble(v ?? '');
                        if (val == null || val <= 0) return 'Укажите объем';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _countController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Количество (шт)',
                        hintText: '12',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final val = int.tryParse(v?.trim() ?? '');
                        if (val == null || val <= 0) return 'Укажите кол-во';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Consumer<SweetenerProvider>(
                builder: (context, sweetenerProvider, child) {
                  if (sweetenerProvider.isLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final sweetenerNames = sweetenerProvider.sweetenerTypes
                      .map((sw) => sw.name)
                      .toList();

                  final String? validValue = sweetenerNames.contains(_selectedSweetenerType)
                      ? _selectedSweetenerType
                      : null;

                  return DropdownButtonFormField<String?>(
                    value: validValue,
                    decoration: const InputDecoration(
                      labelText: 'Подсластитель',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Без подсластителя'),
                      ),
                      ...sweetenerNames.map((swName) {
                        return DropdownMenuItem<String?>(
                          value: swName,
                          child: Text(swName),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedSweetenerType = val);
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              if (_selectedSweetenerType != null) ...[
                TextFormField(
                  controller: _sweetenerAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Количество подсластителя (г/л)',
                    helperText: 'Увеличивает итоговую расчетную сладость',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final val = _parseDouble(v ?? '');
                    if (val == null || val < 0) return 'Укажите дозировку';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
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
          onPressed: _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final isNoSweetener = _selectedSweetenerType == null;
      final sweetenerAmount = isNoSweetener ? 0.0 : (_parseDouble(_sweetenerAmountController.text) ?? 0.0);

      final resultContainer = BatchContainer(
        id: widget.container?.id,
        batchId: widget.batchId,
        title: _titleController.text.trim(),
        containerType: _selectedContainerType,
        containerVolumeLiters: _parseDouble(_volumeController.text) ?? 0.75,
        count: int.tryParse(_countController.text.trim()) ?? 1,
        sweetenerType: _selectedSweetenerType,
        sweetenerAmountGramsPerLiter: sweetenerAmount,
      );

      Navigator.pop(context, resultContainer);
    }
  }
}