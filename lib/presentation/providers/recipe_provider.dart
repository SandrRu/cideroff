import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // <-- Добавлен пропущенный импорт Uuid
import '../../data/datasources/database_service.dart';
import '../../data/models/recipe_model.dart';

class RecipeProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<Recipe> _recipes = [];
  bool _isLoading = false;

  List<Recipe> get recipes => _recipes;
  List<Recipe> get favoriteRecipes => _recipes.where((r) => r.isFavorite).toList();
  bool get isLoading => _isLoading;

  RecipeProvider();

  /// Загрузка всех рецептов из базы данных
  Future<void> loadRecipes() async {
    _isLoading = true;
    notifyListeners();

    _recipes = await _db.getAllRecipes();

    _isLoading = false;
    notifyListeners();
  }

  /// Сохранение или обновление рецепта
  Future<void> saveRecipe(Recipe recipe) async {
    await _db.insertRecipe(recipe);
    await loadRecipes();
  }

  /// Переключение состояния «Избранное»
  Future<void> toggleFavorite(Recipe recipe) async {
    final updated = recipe.copyWith(isFavorite: !recipe.isFavorite);
    await _db.insertRecipe(updated);
    await loadRecipes();
  }

  /// Дублирование любого (в т.ч. системного) рецепта в пользовательский для редактирования
  Future<void> duplicateAsCustom(Recipe sourceRecipe, {String? newTitle}) async {
    final ruTitle = sourceRecipe.getTitle('ru');
    final titleText = newTitle?.trim().isNotEmpty == true 
        ? newTitle!.trim() 
        : '$ruTitle (Копия)';

    final newRecipe = sourceRecipe.copyWith(
      id: const Uuid().v4(),
      title: {'ru': titleText, 'en': '${sourceRecipe.getTitle('en')} (Copy)'},
      isCustom: true,
      isFavorite: false,
    );
    await _db.insertRecipe(newRecipe);
    await loadRecipes();
  }
}