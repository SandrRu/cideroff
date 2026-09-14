// lib/presentation/screens/label/upload_svg_template_dialog.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/models/label_template_model.dart';
import '../../../data/datasources/database_service.dart';

class UploadSvgTemplateDialog extends StatefulWidget {
  const UploadSvgTemplateDialog({super.key});

  @override
  State<UploadSvgTemplateDialog> createState() => _UploadSvgTemplateDialogState();
}

class _UploadSvgTemplateDialogState extends State<UploadSvgTemplateDialog> {
  final _nameController = TextEditingController();
  final _widthController = TextEditingController(text: '58.0');
  final _heightController = TextEditingController(text: '40.0');
  
  String? _svgString;
  String? _fileName;

  Future<void> _pickSvgFile() async {
    // В v12.x вызов делается напрямую через статический метод FilePicker.pickFile()
    final PlatformFile? pickedFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['svg'],
    );

    if (pickedFile != null) {
      String? content;

      // В v12.x считывание байтов делается через метод readAsBytes()
      try {
        final bytes = await pickedFile.readAsBytes();
        content = utf8.decode(bytes);
      } catch (_) {
        // Фоллбек для файлов на диске (Desktop/Mobile), если чтение байтов завершилось ошибкой
        if (pickedFile.path != null) {
          final file = File(pickedFile.path!);
          if (await file.exists()) {
            content = await file.readAsString();
          }
        }
      }

      if (content != null && content.isNotEmpty) {
        setState(() {
          _svgString = content;
          _fileName = pickedFile.name;
          if (_nameController.text.isEmpty) {
            _nameController.text = _fileName!.replaceAll('.svg', '');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Загрузить SVG-макет'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: _pickSvgFile,
              icon: const Icon(Icons.file_upload),
              label: Text(_fileName ?? 'Выбрать SVG-файл'),
            ),
            if (_svgString != null) ...[
              const SizedBox(height: 8),
              const Text('✅ Файл успешно загружен', style: TextStyle(color: Colors.green, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Название шаблона', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Ширина (мм)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Высота (мм)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null), // Явно возвращаем null вместо bool
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
          onPressed: _svgString == null ? null : _saveTemplate,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  void _saveTemplate() async {
    final template = LabelTemplate(
      name: _nameController.text.trim().isEmpty ? 'Мой SVG Макет' : _nameController.text.trim(),
      widthMm: double.tryParse(_widthController.text) ?? 58.0,
      heightMm: double.tryParse(_heightController.text) ?? 40.0,
      svgContent: _svgString,
      isCustomSvg: true,
    );

    await DatabaseService.instance.insertLabelTemplate(template);
    if (!mounted) return;
    Navigator.pop(context, true);
  }
}