import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/yeast_model.dart';
import '../../providers/yeast_provider.dart';

class YeastListScreen extends StatefulWidget {
  const YeastListScreen({super.key});

  @override
  State<YeastListScreen> createState() => _YeastListScreenState();
}

class _YeastListScreenState extends State<YeastListScreen> {
  @override
  void initState() {
    super.initState();
    // Загружаем список только если он еще не был загружен ранее (например, в MainShellScreen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final yeastProvider = context.read<YeastProvider>();
        if (yeastProvider.yeasts.isEmpty && !yeastProvider.isLoading) {
          yeastProvider.loadYeasts();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final yeastProvider = context.watch<YeastProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Справочник дрожжей'),
      ),
      body: yeastProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : yeastProvider.yeasts.isEmpty
              ? const Center(child: Text('Список дрожжей пуст'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: yeastProvider.yeasts.length,
                  itemBuilder: (context, index) {
                    final yeast = yeastProvider.yeasts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.shade100,
                          child: const Icon(Icons.grain, color: Colors.amber),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                yeast.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (!yeast.isCustom)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Базовый',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Категория: ${yeast.category}',
                              style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                            ),
                            if (yeast.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                yeast.description,
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                        trailing: yeast.isCustom
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                    onPressed: () => _showYeastDialog(context, yeast: yeast),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _showDeleteDialog(context, yeast),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () => _showYeastDialog(context),
              icon: const Icon(Icons.add),
              label: const Text(
                'Добавить дрожжи',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showYeastDialog(BuildContext context, {Yeast? yeast}) {
    final nameController = TextEditingController(text: yeast?.name ?? '');
    final categoryController = TextEditingController(text: yeast?.category ?? 'Cider');
    final descController = TextEditingController(text: yeast?.description ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(yeast == null ? 'Новые дрожжи' : 'Редактировать дрожжи'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название дрожжей',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Категория (Cider, Calvados, Universal)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Описание / особенности',
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
              if (nameController.text.trim().isNotEmpty) {
                final newYeast = Yeast(
                  id: yeast?.id,
                  name: nameController.text.trim(),
                  category: categoryController.text.trim(),
                  description: descController.text.trim(),
                  isCustom: true,
                );

                Navigator.pop(dialogContext);
                await context.read<YeastProvider>().saveYeast(newYeast);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Yeast yeast) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить дрожжи?'),
        content: Text('Вы уверены, что хотите удалить "${yeast.name}"?'),
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
              await context.read<YeastProvider>().deleteYeast(yeast.id);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}