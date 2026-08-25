import 'package:flutter/material.dart';
import '../../../data/datasources/database_service.dart';
import '../../../data/models/batch_model.dart';
import '../../../data/models/label_template_model.dart';
import 'label_preview_screen.dart';

class LabelTemplateListScreen extends StatefulWidget {
  final Batch? batch;

  const LabelTemplateListScreen({super.key, this.batch});

  @override
  State<LabelTemplateListScreen> createState() => _LabelTemplateListScreenState();
}

class _LabelTemplateListScreenState extends State<LabelTemplateListScreen> {
  List<LabelTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final list = await DatabaseService.instance.getAllLabelTemplates();
    if (list.isEmpty) {
      final defaultTpl = LabelTemplate(
        name: 'Стандартная термоэтикетка (58×40 мм)',
        widthMm: 58.0,
        heightMm: 40.0,
        schemaJson: '{}',
      );
      await DatabaseService.instance.insertLabelTemplate(defaultTpl);
      _templates = [defaultTpl];
    } else {
      _templates = list;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.batch != null ? 'Этикетка: ${widget.batch!.name}' : 'Макеты наклеек'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final item = _templates[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_2, color: Colors.amber),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Размер: ${item.widthMm} × ${item.heightMm} мм'),
              onTap: widget.batch != null
                  ? () {
                      _showPrintPreviewDialog(item);
                    }
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Редактировать',
                    onPressed: () => _showEditTemplateDialog(item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Удалить макет',
                    onPressed: () => _showDeleteTemplateDialog(item),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTemplateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Новый макет'),
      ),
    );
  }

  void _showPrintPreviewDialog(LabelTemplate template) {
    if (widget.batch != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LabelPreviewScreen(
            batch: widget.batch!,
            template: template,
          ),
        ),
      );
    }
  }

  /// Диалог подтверждения удаления макета
  void _showDeleteTemplateDialog(LabelTemplate template) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить макет?'),
        content: Text('Вы уверены, что хотите удалить макет "${template.name}"?'),
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
              final dialogNav = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(context);

              await DatabaseService.instance.deleteLabelTemplate(template.id);

              if (mounted) {
                dialogNav.pop();
                _loadTemplates();
                messenger.showSnackBar(
                  SnackBar(content: Text('Макет "${template.name}" удалён')),
                );
              }
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  /// Диалог редактирования существующего макета
  void _showEditTemplateDialog(LabelTemplate template) {
    final nameController = TextEditingController(text: template.name);
    final widthController = TextEditingController(text: template.widthMm.toString());
    final heightController = TextEditingController(text: template.heightMm.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Редактирование макета'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название макета'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widthController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Ширина (мм)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Высота (мм)'),
                  ),
                ),
              ],
            )
          ],
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
              if (nameController.text.isNotEmpty) {
                final dialogNav = Navigator.of(dialogContext);

                final updatedTpl = LabelTemplate(
                  id: template.id,
                  name: nameController.text.trim(),
                  widthMm: double.tryParse(widthController.text) ?? template.widthMm,
                  heightMm: double.tryParse(heightController.text) ?? template.heightMm,
                  schemaJson: template.schemaJson,
                );

                await DatabaseService.instance.updateLabelTemplate(updatedTpl);
                
                if (mounted) {
                  dialogNav.pop();
                  _loadTemplates();
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showAddTemplateDialog() {
    final nameController = TextEditingController();
    final widthController = TextEditingController(text: '58');
    final heightController = TextEditingController(text: '40');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Создание макета'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название макета'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widthController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Ширина (мм)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Высота (мм)'),
                  ),
                ),
              ],
            )
          ],
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
              if (nameController.text.isNotEmpty) {
                final dialogNav = Navigator.of(dialogContext);

                final tpl = LabelTemplate(
                  name: nameController.text.trim(),
                  widthMm: double.tryParse(widthController.text) ?? 58.0,
                  heightMm: double.tryParse(heightController.text) ?? 40.0,
                  schemaJson: '{}',
                );
                await DatabaseService.instance.insertLabelTemplate(tpl);
                if (mounted) {
                  dialogNav.pop();
                  _loadTemplates();
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}