import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/export_import_service.dart';
import '../../providers/recipe_provider.dart';
import 'recipe_editor_screen.dart';

class RecipeListScreen extends StatelessWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final langCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Рецепты сидра'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Импорт рецепта',
            onPressed: () async {
              final recipeProvider = context.read<RecipeProvider>();
              final messenger = ScaffoldMessenger.of(context);

              final recipe = await ExportImportService().importRecipe();
              
              if (recipe != null && context.mounted) {
                await recipeProvider.loadRecipes();
                messenger.showSnackBar(
                  SnackBar(content: Text('Рецепт "${recipe.getTitle(langCode)}" импортирован')),
                );
              }
            },
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.recipes.isEmpty
              ? const Center(child: Text('Рецепты не найдены'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: provider.recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = provider.recipes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          recipe.getTitle(langCode),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          recipe.getDescription(langCode),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                recipe.isFavorite ? Icons.star : Icons.star_border,
                                color: recipe.isFavorite ? Colors.amber : Colors.grey,
                              ),
                              onPressed: () {
                                context.read<RecipeProvider>().toggleFavorite(recipe);
                              },
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                final navigator = Navigator.of(context);
                                
                                if (value == 'export') {
                                  await ExportImportService().exportRecipe(recipe);
                                } else if (value == 'edit') {
                                  navigator.push(
                                    MaterialPageRoute(
                                      builder: (_) => RecipeEditorScreen(recipe: recipe),
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'export',
                                  child: Row(
                                    children: [
                                      Icon(Icons.share, size: 20),
                                      SizedBox(width: 8),
                                      Text('Поделиться'),
                                    ],
                                  ),
                                ),
                                if (recipe.isCustom)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Редактировать'),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecipeEditorScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Новый рецепт'),
      ),
    );
  }
}