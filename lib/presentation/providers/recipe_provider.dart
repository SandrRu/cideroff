import 'package:flutter/material.dart';
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
}