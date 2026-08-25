import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../../data/models/batch_model.dart';
import '../../../data/models/label_template_model.dart';
import '../../../services/label_pdf_service.dart';

class LabelPreviewScreen extends StatefulWidget {
  final Batch batch;
  final LabelTemplate? template;

  const LabelPreviewScreen({
    super.key,
    required this.batch,
    this.template,
  });

  @override
  State<LabelPreviewScreen> createState() => _LabelPreviewScreenState();
}

class _LabelPreviewScreenState extends State<LabelPreviewScreen> {
  late LabelTemplate _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _selectedTemplate = widget.template ??
        LabelTemplate(
          name: 'Стандартная термоэтикетка (58x40 мм)',
          widthMm: 58.0,
          heightMm: 40.0,
          schemaJson: '{}',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Этикетка: ${widget.batch.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Поделиться / Сохранить PDF',
            onPressed: () => _sharePdf(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfPreview(
              build: (format) => LabelPdfService.generateLabelPdf(
                batch: widget.batch,
                template: _selectedTemplate,
              ),
              allowPrinting: true,
              allowSharing: false,
              canChangeOrientation: false,
              canChangePageFormat: false,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    final pdfBytes = await LabelPdfService.generateLabelPdf(
      batch: widget.batch,
      template: _selectedTemplate,
    );

    final sanitizeName = widget.batch.name.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final fileName = 'Label_$sanitizeName.pdf';

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить этикетку PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(pdfBytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Этикетка сохранена: $outputFile')),
          );
        }
      }
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Этикетка сидра: ${widget.batch.name}',
      );
    }
  }
}