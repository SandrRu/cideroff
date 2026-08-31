import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/recipe_model.dart';
import '../../../services/export_import_service.dart';
import '../../providers/recipe_provider.dart';
import 'recipe_detail_screen.dart';
import 'recipe_editor_screen.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isCalvadosRecipe(Recipe recipe) {
    final ruTitle = (recipe.title['ru'] ?? '').toLowerCase();
    final idLower = recipe.id.toLowerCase();
    return idLower.contains('calvados') || ruTitle.contains('кальвадос');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final langCode = Localizations.localeOf(context).languageCode;

    final ciderRecipes = provider.recipes.where((r) => !_isCalvadosRecipe(r)).toList();
    final calvadosRecipes = provider.recipes.where((r) => _isCalvadosRecipe(r)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Книга рецептов'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '🍏 Сидр (${ciderRecipes.length})'),
            Tab(text: '🥃 Кальвадос (${calvadosRecipes.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Импорт рецепта',
            onPressed: () async {
              final recipeProvider = context.read<RecipeProvider>();
              final recipe = await ExportImportService().importRecipe();

              if (!context.mounted) return;

              if (recipe != null) {
                await recipeProvider.loadRecipes();
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Рецепт "${recipe.getTitle(langCode)}" импортирован'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRecipeList(context, ciderRecipes, langCode),
                _buildRecipeList(context, calvadosRecipes, langCode),
              ],
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

  Widget _buildRecipeList(
    BuildContext context,
    List<Recipe> recipes,
    String langCode,
  ) {
    if (recipes.isEmpty) {
      return const Center(child: Text('Рецепты не найдены'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(recipe: recipe),
                ),
              );
            },
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    recipe.getTitle(langCode),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (!recipe.isCustom)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Системный',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
              ],
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
                    if (value == 'export') {
                      await ExportImportService().exportRecipe(recipe);
                    } else if (value == 'duplicate') {
                      await context
                          .read<RecipeProvider>()
                          .duplicateAsCustom(recipe);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Создана копия рецепта "${recipe.getTitle(langCode)}"',
                          ),
                        ),
                      );
                    } else if (value == 'edit') {
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecipeEditorScreen(recipe: recipe),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy, size: 20, color: Colors.amber),
                          SizedBox(width: 8),
                          Text('Дублировать как свой'),
                        ],
                      ),
                    ),
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
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            recipe.isCustom ? Icons.edit : Icons.visibility,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            recipe.isCustom ? 'Редактировать' : 'Просмотреть',
                          ),
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
    );
  }
}