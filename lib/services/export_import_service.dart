import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cider_off/data/datasources/database_service.dart';
import 'package:cider_off/data/models/batch_model.dart';
import 'package:cider_off/data/models/batch_history_model.dart';
import 'package:cider_off/data/models/recipe_model.dart';
import 'package:cider_off/data/models/label_template_model.dart';

class ExportImportService {
  final DatabaseService _db = DatabaseService.instance;

  // --- РЕЗЕРВНОЕ КОПИРОВАНИЕ И ВОССТАНОВЛЕНИЕ (БЭКАП) ---

  /// Генерация полных данных приложения в формат JSON и экспорт
  Future<void> exportFullBackup() async {
    final batches = await _db.getAllBatches();
    final recipes = await _db.getAllRecipes();
    final templates = await _db.getAllLabelTemplates();

    final List<Map<String, dynamic>> allHistory = [];
    for (var batch in batches) {
      final historyList = await _db.getHistoryForBatch(batch.id);
      allHistory.addAll(historyList.map((h) => h.toJson()));
    }

    final backupData = {
      'app': 'CiderOff',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'batches': batches.map((b) => b.toJson()).toList(),
      'history': allHistory,
      'recipes': recipes.map((r) => r.toJson()).toList(),
      'templates': templates.map((t) => t.toJson()).toList(),
    };

    final jsonString = jsonEncode(backupData);
    final fileName = 'CiderOff_Backup_${DateTime.now().millisecondsSinceEpoch}.ciderbak';

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить резервную копию',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['ciderbak'],
      );
      
      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonString);
      }
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Резервная копия CiderOff',
      );
    }
  }

  /// Восстановление базы данных из файла .ciderbak / .json
  Future<bool> importFullBackup() async {
    // На мобильных (особенно Android) используем FileType.any,
    // чтобы системный проводник не делал .ciderbak файлы серыми.
    final result = await FilePicker.platform.pickFiles(
      type: Platform.isAndroid || Platform.isIOS 
          ? FileType.any 
          : FileType.custom,
      allowedExtensions: Platform.isAndroid || Platform.isIOS 
          ? null 
          : ['ciderbak', 'json'],
    );

    if (result == null || result.files.single.path == null) return false;

    final filePath = result.files.single.path!;
    final lowerPath = filePath.toLowerCase();

    // Явная проверка расширения файла
    if (!lowerPath.endsWith('.ciderbak') && !lowerPath.endsWith('.json')) {
      throw const FormatException('Выберите файл с расширением .ciderbak или .json');
    }

    final file = File(filePath);
    final content = await file.readAsString();
    final Map<String, dynamic> data = jsonDecode(content);

    if (data['app'] != 'CiderOff') {
      throw const FormatException('Неверный формат файла резервной копии');
    }

    // 1. Восстанавливаем рецепты
    if (data['recipes'] != null) {
      for (var item in data['recipes']) {
        await _db.insertRecipe(Recipe.fromJson(item));
      }
    }

    // 2. Восстанавливаем партии
    if (data['batches'] != null) {
      for (var item in data['batches']) {
        await _db.insertBatch(Batch.fromJson(item));
      }
    }

    // 3. Восстанавливаем историю всех замеров и пройденных шагов
    if (data['history'] != null) {
      for (var item in data['history']) {
        await _db.insertHistory(BatchHistory.fromJson(item));
      }
    }

    // 4. Восстанавливаем макеты этикеток
    if (data['templates'] != null) {
      for (var item in data['templates']) {
        await _db.insertLabelTemplate(LabelTemplate.fromJson(item));
      }
    }

    return true;
  }

  // --- ИМПОРТ И ЭКСПОРТ РЕЦЕПТОВ ---

  /// Экспорт одного рецепта в файл .ciderrecipe и отправка
  Future<void> exportRecipe(Recipe recipe) async {
    final recipeData = {
      'version': 1,
      'type': 'cider_recipe',
      'data': recipe.toJson(),
    };

    final jsonString = jsonEncode(recipeData);
    
    // Юникод-регулярка, защищающая кириллицу от превращения в "_"
    final safeTitle = recipe
        .getTitle('ru')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s\-]', unicode: true), '_');
    final fileName = 'Recipe_$safeTitle.ciderrecipe';

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить рецепт',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['ciderrecipe'],
      );
      
      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonString);
      }
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Рецепт сидра: ${recipe.getTitle('ru')}',
      );
    }
  }

  /// Импорт рецепта из файла .ciderrecipe / .json
  Future<Recipe?> importRecipe() async {
    final result = await FilePicker.platform.pickFiles(
      type: Platform.isAndroid || Platform.isIOS 
          ? FileType.any 
          : FileType.custom,
      allowedExtensions: Platform.isAndroid || Platform.isIOS 
          ? null 
          : ['ciderrecipe', 'json'],
    );

    if (result == null || result.files.single.path == null) return null;

    final filePath = result.files.single.path!;
    final lowerPath = filePath.toLowerCase();

    // Проверка расширения файла рецепта
    if (!lowerPath.endsWith('.ciderrecipe') && !lowerPath.endsWith('.json')) {
      throw const FormatException('Выберите файл с расширением .ciderrecipe или .json');
    }

    final file = File(filePath);
    final content = await file.readAsString();
    final Map<String, dynamic> parsed = jsonDecode(content);

    if (parsed['type'] != 'cider_recipe' || parsed['data'] == null) {
      throw const FormatException('Файл не содержит корректного рецепта CiderOff');
    }

    final recipe = Recipe.fromJson(parsed['data']);
    await _db.insertRecipe(recipe);
    return recipe;
  }

  /// Генерация JSON-строки бэкапа в памяти
  Future<String> generateBackupJsonString() async {
    final batches = await _db.getAllBatches();
    final recipes = await _db.getAllRecipes();
    final templates = await _db.getAllLabelTemplates();

    final List<Map<String, dynamic>> allHistory = [];
    for (var batch in batches) {
      final historyList = await _db.getHistoryForBatch(batch.id);
      allHistory.addAll(historyList.map((h) => h.toJson()));
    }

    final backupData = {
      'app': 'CiderOff',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'batches': batches.map((b) => b.toJson()).toList(),
      'history': allHistory,
      'recipes': recipes.map((r) => r.toJson()).toList(),
      'templates': templates.map((t) => t.toJson()).toList(),
    };

    return jsonEncode(backupData);
  }

  /// Импорт бэкапа по прямому пути к файлу (нужно для облака)
  Future<bool> importBackupFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;
    
    final content = await file.readAsString();
    final Map<String, dynamic> data = jsonDecode(content);

    if (data['app'] != 'CiderOff') {
      throw const FormatException('Неверный формат файла резервной копии');
    }

    // Восстановление данных в БД (логика аналогична текущему importFullBackup)
    if (data['recipes'] != null) {
      for (var item in data['recipes']) {
        await _db.insertRecipe(Recipe.fromJson(item));
      }
    }
    if (data['batches'] != null) {
      for (var item in data['batches']) {
        await _db.insertBatch(Batch.fromJson(item));
      }
    }
    if (data['history'] != null) {
      for (var item in data['history']) {
        await _db.insertHistory(BatchHistory.fromJson(item));
      }
    }
    if (data['templates'] != null) {
      for (var item in data['templates']) {
        await _db.insertLabelTemplate(LabelTemplate.fromJson(item));
      }
    }
    return true;
  }
}