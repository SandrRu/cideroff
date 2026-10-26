import 'package:flutter/material.dart';
import '../../../data/datasources/database_service.dart';
import '../../../data/models/batch_container_model.dart';
import '../../../data/models/batch_model.dart';
import '../../../data/models/label_template_model.dart';
import 'label_preview_screen.dart';
import 'upload_svg_template_dialog.dart';

class LabelTemplateListScreen extends StatefulWidget {
  final Batch? batch;
  final BatchContainer? selectedContainer;

  const LabelTemplateListScreen({
    super.key,
    this.batch,
    this.selectedContainer,
  });

  @override
  State<LabelTemplateListScreen> createState() =>
      _LabelTemplateListScreenState();
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
    if (!mounted) return;

    if (list.isEmpty) {
      final defaultTpl = LabelTemplate(
        name: 'Стандартная термоэтикетка (58×40 мм)',
        widthMm: 58.0,
        heightMm: 40.0,
        schemaJson: '{}',
      );
      await DatabaseService.instance.insertLabelTemplate(defaultTpl);
      if (!mounted) return;
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
        title: Text(widget.batch != null
            ? 'Этикетка: ${widget.batch!.name}'
            : 'Макеты наклеек'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Переменные для SVG',
            onPressed: () => _showSvgVariablesHelpDialog(context),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final item = _templates[index];
          final isSvg = item.schemaJson.contains('.svg') ||
              item.schemaJson.contains('<svg');

          return Card(
            child: ListTile(
              leading: Icon(
                isSvg ? Icons.extension_outlined : Icons.qr_code_2,
                color: isSvg ? Colors.deepPurpleAccent : Colors.amber,
              ),
              title: Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
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
        onPressed: _showAddTemplateOptions,
        icon: const Icon(Icons.add),
        label: const Text('Добавить макет'),
      ),
    );
  }

  /// Меню выбора способа создания макета (стандартный или загрузка SVG)
  void _showAddTemplateOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.amber),
                title: const Text('Создать текстовый макет'),
                subtitle: const Text('Задать ширину и высоту вручную'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _showAddTemplateDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file,
                    color: Colors.deepPurpleAccent),
                title: const Text('Загрузить SVG-шаблон'),
                subtitle: const Text('Импортировать готовый макет SVG'),
                trailing: IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.grey),
                  tooltip: 'Список переменных',
                  onPressed: () {
                    Navigator.pop(bottomSheetContext);
                    _showSvgVariablesHelpDialog(context);
                  },
                ),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  await showDialog(
                    context: context,
                    builder: (_) => const UploadSvgTemplateDialog(),
                  );
                  if (!mounted) return;
                  _loadTemplates();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSvgVariablesHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Переменные для SVG-макета'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Используйте данные метки (плейсхолдеры) в тексте вашего SVG-файла. При печати этикетки они заменятся на данные партии:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                SizedBox(height: 12),
                _VariableGroup(
                  title: 'Партия',
                  items: [
                    '{{BATCH_NAME}} — Имя партии',
                    '{{BATCH_ID}} — ID партии',
                  ],
                ),
                _VariableGroup(
                  title: 'Сорт яблок',
                  items: [
                    '{{APPLE_VARIETY}} — Сорт яблок',
                  ],
                ),
                _VariableGroup(
                  title: 'Даты',
                  items: [
                    '{{PRESS_DATE}} — Дата отжима',
                    '{{BOTTLING_DATE}} — Дата розлива',
                  ],
                ),
                _VariableGroup(
                  title: 'Сладость и Тип',
                  items: [
                    '{{SWEETNESS_CATEGORY}} — Сладость',
                    '{{DRINK_TYPE}} — Категория напитка',
                  ],
                ),
                _VariableGroup(
                  title: 'Крепость и Сахар',
                  items: [
                    '{{ABV}} — Крепость',
                    '{{SUGAR}} — Начальный сахар',
                    '{{FINAL_SUGAR}} — Конечный сахар',
                  ],
                ),
                _VariableGroup(
                  title: 'Заметки и Описание',
                  items: [
                    '{{NOTES}} — Заметки',
                    '{{description}} — Описание',
                  ],
                ),
                _VariableGroup(
                  title: 'Дрожжи',
                  items: [
                    '{{YEAST_NAME}} — Название дрожжей',
                  ],
                ),
                _VariableGroup(
                  title: 'Тара и Подсластитель',
                  items: [
                    '{{CONTAINER_TITLE}} — Название тары',
                    '{{CONTAINER_TYPE}} — Тип тары',
                    '{{SWEETENER}} — Подсластитель',
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
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
            container: widget.selectedContainer,
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
        content:
            Text('Вы уверены, что хотите удалить макет "${template.name}"?'),
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
              Navigator.pop(dialogContext);

              await DatabaseService.instance.deleteLabelTemplate(template.id);

              if (!mounted) return;

              _loadTemplates();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Макет "${template.name}" удалён')),
              );
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
    final widthController =
        TextEditingController(text: template.widthMm.toString());
    final heightController =
        TextEditingController(text: template.heightMm.toString());

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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Ширина (мм)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: heightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                final updatedTpl = LabelTemplate(
                  id: template.id,
                  name: nameController.text.trim(),
                  widthMm:
                      double.tryParse(widthController.text) ?? template.widthMm,
                  heightMm: double.tryParse(heightController.text) ??
                      template.heightMm,
                  schemaJson: template.schemaJson,
                );

                Navigator.pop(dialogContext);

                await DatabaseService.instance.updateLabelTemplate(updatedTpl);

                if (!mounted) return;
                _loadTemplates();
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Ширина (мм)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: heightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                final tpl = LabelTemplate(
                  name: nameController.text.trim(),
                  widthMm: double.tryParse(widthController.text) ?? 58.0,
                  heightMm: double.tryParse(heightController.text) ?? 40.0,
                  schemaJson: '{}',
                );

                Navigator.pop(dialogContext);

                await DatabaseService.instance.insertLabelTemplate(tpl);

                if (!mounted) return;
                _loadTemplates();
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

class _VariableGroup extends StatelessWidget {
  final String title;
  final List<String> items;

  const _VariableGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 4),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                child: SelectableText(
                  item,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
