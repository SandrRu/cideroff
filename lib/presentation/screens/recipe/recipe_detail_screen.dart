import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/recipe_model.dart';
import '../../../services/export_import_service.dart';
import '../../providers/recipe_provider.dart';
import 'recipe_editor_screen.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final langCode = Localizations.localeOf(context).languageCode;

    // Ищем актуальную версию рецепта из провайдера, если она обновлялась
    final currentRecipe = recipeProvider.recipes.firstWhere(
      (r) => r.id == recipe.id,
      orElse: () => recipe,
    );

    final isReadOnly = !currentRecipe.isCustom;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentRecipe.getTitle(langCode)),
        actions: [
          IconButton(
            icon: Icon(
              currentRecipe.isFavorite ? Icons.star : Icons.star_border,
              color: currentRecipe.isFavorite ? Colors.amber : null,
            ),
            tooltip: 'В избранное',
            onPressed: () {
              context.read<RecipeProvider>().toggleFavorite(currentRecipe);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Поделиться',
            onPressed: () async {
              await ExportImportService().exportRecipe(currentRecipe);
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Копировать рецепт',
            onPressed: () => _duplicateRecipe(context, currentRecipe),
          ),
          if (!isReadOnly)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Редактировать',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeEditorScreen(recipe: currentRecipe),
                  ),
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isReadOnly)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: Colors.amber),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Это системный базовый рецепт. Его нельзя изменять напрямую, но вы можете сделать копию.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _duplicateRecipe(context, currentRecipe),
                    child: const Text('Копировать'),
                  ),
                ],
              ),
            ),
          
          if (currentRecipe.getDescription(langCode).isNotEmpty) ...[
            Text(
              'Описание',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              currentRecipe.getDescription(langCode),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
          ],

          Text(
            'Этапы приготовления (${currentRecipe.steps.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          ...List.generate(currentRecipe.steps.length, (index) {
            final step = currentRecipe.steps[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.amber,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.getTitle(langCode),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Chip(
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${step.durationDays} дн.',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    if (step.getInstruction(langCode).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        step.getInstruction(langCode),
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (step.requiresSugarMeasurement)
                          const Chip(
                            avatar: Icon(Icons.science_outlined, size: 14),
                            visualDensity: VisualDensity.compact,
                            label: Text('Замер сахара', style: TextStyle(fontSize: 11)),
                          ),
                        if (step.requiresAlcoholMeasurement)
                          const Chip(
                            avatar: Icon(Icons.local_bar_outlined, size: 14),
                            visualDensity: VisualDensity.compact,
                            label: Text('Замер спирта', style: TextStyle(fontSize: 11)),
                          ),
                        if (step.isBottlingStep)
                          const Chip(
                            backgroundColor: Color(0xFFE8F5E9),
                            avatar: Icon(Icons.wine_bar_outlined, size: 14, color: Colors.green),
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              'Розлив / Финал',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: isReadOnly
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => _duplicateRecipe(context, currentRecipe),
                    icon: const Icon(Icons.copy),
                    label: const Text(
                      'Создать редактируемую копию',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _duplicateRecipe(BuildContext context, Recipe sourceRecipe) async {
    final messenger = ScaffoldMessenger.of(context);
    final recipeProvider = context.read<RecipeProvider>();

    await recipeProvider.duplicateAsCustom(sourceRecipe);

    messenger.showSnackBar(
      SnackBar(
        content: Text('Создана копия рецепта "${sourceRecipe.getTitle('ru')}"'),
      ),
    );
  }
}