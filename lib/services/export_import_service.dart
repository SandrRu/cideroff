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
import 'package:cider_off/data/models/yeast_model.dart';
import 'package:cider_off/data/models/drink_type_model.dart';
import 'package:cider_off/data/models/sweetener_type_model.dart';
import 'package:cider_off/data/models/batch_recipe_link_model.dart';

/// Результат разбора бэкапа: данные уже проверены, но ещё не записаны в БД.
class _BackupPayload {
    const _BackupPayload({
    required this.yeasts,
    required this.drinkTypes,
    required this.sweeteners,
    required this.recipes,
    required this.templates,
    required this.batches,
    required this.recipeLinks,
    required this.history,
  });

  final List<Yeast> yeasts;
  final List<DrinkType> drinkTypes;
  final List<SweetenerType> sweeteners;
  final List<Recipe> recipes;
  final List<LabelTemplate> templates;
  final List<Batch> batches;
  final List<BatchRecipeLink> recipeLinks;
  final List<BatchHistory> history;
}

class ExportImportService {
  final DatabaseService _db = DatabaseService.instance;

  // --- РЕЗЕРВНОЕ КОПИРОВАНИЕ И ВОССТАНОВЛЕНИЕ (БЭКАП) ---

  /// Генерация полных данных приложения в формат JSON и экспорт
  Future<void> exportFullBackup() async {
    final jsonString = await generateBackupJsonString();
    final fileName =
        'CiderOff_Backup_${DateTime.now().millisecondsSinceEpoch}.ciderbak';
    final bytes = utf8.encode(jsonString);

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final outputFile = await FilePicker.saveFile(
        dialogTitle: 'Сохранить резервную копию',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['ciderbak'],
      );

      if (outputFile != null) {
        final filePath = outputFile.toFilePath();
        final file = File(filePath);

        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsString(jsonString);
        }
      }
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsString(jsonString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Резервная копия CiderOff',
        ),
      );
    }
  }

  /// Восстановление базы данных из файла .ciderbak / .json
  Future<bool> importFullBackup() async {
    final result = await FilePicker.pickFiles(
      type:
          Platform.isAndroid || Platform.isIOS ? FileType.any : FileType.custom,
      allowedExtensions:
          Platform.isAndroid || Platform.isIOS ? null : ['ciderbak', 'json'],
    );

    if (result.isEmpty) return false;

        final filePath = result.first.path;
    if (filePath == null || filePath.isEmpty) return false;

    // Пользователь ожидает «восстановление», то есть замену данных,
    // а не слияние со текущей базой.
    return await importBackupFromFile(filePath, replaceExisting: true);
  }

  /// Генерация JSON-строки бэкапа в памяти
  Future<String> generateBackupJsonString() async {
    final rawBatches = await _db.getAllBatches();
    final recipes = await _db.getAllRecipes();
    final templates = await _db.getAllLabelTemplates();
        final yeasts = await _db.getAllYeasts();
    final drinkTypes = await _db.getAllDrinkTypes();
    final sweeteners = await _db.getAllSweetenerTypes();

    final List<Map<String, dynamic>> allHistory = [];
    final List<Map<String, dynamic>> allRecipeLinks = [];
    final List<Batch> batches = [];

    for (var batch in rawBatches) {
      // 1. Получаем историю
      final historyList = await _db.getHistoryForBatch(batch.id);
      allHistory.addAll(historyList.map((h) => h.toJson()));

      // 2. Получаем связи партии с рецептами
      final recipeLinks = await _db.getRecipeLinksForBatch(batch.id);
      allRecipeLinks.addAll(recipeLinks.map((link) => link.toJson()));

      // 3. Подгружаем подпартии (контейнеры) для каждой партии
      final containers = await _db.getContainersForBatch(batch.id);
      batches.add(batch.copyWith(containers: containers));
    }

    final backupData = {
      'app': 'CiderOff',
      'version': 3,
      'exportedAt': DateTime.now().toIso8601String(),
      'batches': batches.map((b) => b.toJson()).toList(),
      'batchRecipeLinks': allRecipeLinks,
      'history': allHistory,
      'recipes': recipes.map((r) => r.toJson()).toList(),
      'templates': templates.map((t) => t.toJson()).toList(),
            'yeasts': yeasts.map((y) => y.toJson()).toList(),
      'drinkTypes': drinkTypes.map((dt) => dt.toJson()).toList(),
      'sweetenerTypes': sweeteners.map((s) => s.toJson()).toList(),
    };

    return jsonEncode(backupData);
  }

    /// Импорт бэкапа по прямому пути к файлу.
  /// [replaceExisting] = true заменяет пользовательские данные данными из файла.
  Future<bool> importBackupFromFile(String filePath,
      {bool replaceExisting = false}) async {
    final lowerPath = filePath.toLowerCase();
    if (!lowerPath.endsWith('.ciderbak') && !lowerPath.endsWith('.json')) {
      throw const FormatException(
          'Выберите файл с расширением .ciderbak или .json');
    }

    final file = File(filePath);
    if (!await file.exists()) return false;

        final content = await file.readAsString();
    return await importBackupFromJsonString(content,
        replaceExisting: replaceExisting);
  }

  /// Импорт и парсинг бэкапа из JSON-строки.
  ///
  /// Сначала данные полностью разбираются и проверяются, затем пишутся одной
  /// транзакцией: при любой ошибке база остаётся в исходном состоянии.
  /// [replaceExisting] = true очищает пользовательские данные перед импортом.
  Future<bool> importBackupFromJsonString(
    String jsonString, {
    bool replaceExisting = false,
  }) async {
    final payload = _parseBackupPayload(jsonString);

    await _db.inTransaction((txn) async {
      if (replaceExisting) {
        await txn.delete('history');
        await txn.delete('batch_containers');
        await txn.delete('batch_recipes');
        await txn.delete('batches');
        await txn.delete('recipes', where: 'isCustom = 1');
        await txn.delete('yeasts', where: 'isCustom = 1');
        await txn.delete('drink_types', where: 'isCustom = 1');
        await txn.delete('sweetener_types', where: 'isCustom = 1');
      }

      for (final yeast in payload.yeasts) {
        await _db.insertYeast(yeast, executor: txn);
      }
            for (final drinkType in payload.drinkTypes) {
        await _db.insertDrinkType(drinkType, executor: txn);
      }
      for (final sweetener in payload.sweeteners) {
        await _db.insertSweetenerType(sweetener, executor: txn);
      }
      for (final recipe in payload.recipes) {
        await _db.insertRecipe(recipe, executor: txn);
      }
      for (final template in payload.templates) {
        await _db.insertLabelTemplate(template, executor: txn);
      }
      for (final batch in payload.batches) {
        // Тара партии вставляется вместе с самой партией.
        await _db.insertBatch(batch, executor: txn);
      }
      for (final link in payload.recipeLinks) {
        await _db.linkRecipeToBatch(
          batchId: link.batchId,
          recipeId: link.recipeId,
          sequenceOrder: link.sequenceOrder,
          assignedAt: link.assignedAt,
          notes: link.notes,
          executor: txn,
        );
      }
      for (final entry in payload.history) {
        await _db.insertHistory(entry, executor: txn);
      }
    });

    return true;
  }

  /// Разбор бэкапа без записи в БД: ошибки формата всплывают до транзакции.
  _BackupPayload _parseBackupPayload(String jsonString) {
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw const FormatException(
          'Файл резервной копии повреждён: ожидался JSON-объект');
    }

    final data = <String, dynamic>{
      for (final entry in decoded.entries) entry.key.toString(): entry.value,
    };

    if (data['app'] != 'CiderOff') {
      throw const FormatException('Неверный формат файла резервной копии');
    }

    List<T> parseSection<T>(
        String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = data[key];
      if (raw == null) return <T>[];

      if (raw is! List) {
        throw FormatException('Некорректная секция "$key" в резервной копии');
      }

      final items = <T>[];
      for (final item in raw) {
        if (item is! Map) {
          throw FormatException('Некорректная запись в секции "$key"');
        }
        items.add(fromJson(<String, dynamic>{
          for (final entry in item.entries) entry.key.toString(): entry.value,
        }));
      }
      return items;
    }

        return _BackupPayload(
      yeasts: parseSection('yeasts', Yeast.fromJson),
      drinkTypes: parseSection('drinkTypes', DrinkType.fromJson),
      sweeteners: parseSection('sweetenerTypes', SweetenerType.fromJson),
      recipes: parseSection('recipes', Recipe.fromJson),
      templates: parseSection('templates', LabelTemplate.fromJson),
      batches: parseSection('batches', Batch.fromJson),
      recipeLinks: parseSection('batchRecipeLinks', BatchRecipeLink.fromJson),
      history: parseSection('history', BatchHistory.fromJson),
    );
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

    final safeTitle = recipe
        .getTitle('ru')
        .replaceAll(RegExp(r'[^\w\s\-\u0400-\u04FF]'), '_');
    final fileName = 'Recipe_$safeTitle.ciderrecipe';
    final bytes = utf8.encode(jsonString);

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final outputFile = await FilePicker.saveFile(
        dialogTitle: 'Сохранить рецепт',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['ciderrecipe'],
      );

      if (outputFile != null) {
        final filePath = outputFile.toFilePath();
        final file = File(filePath);

        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsString(jsonString);
        }
      }
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsString(jsonString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Рецепт сидра: ${recipe.getTitle('ru')}',
        ),
      );
    }
  }

  /// Импорт рецепта из файла .ciderrecipe / .json
  Future<Recipe?> importRecipe() async {
    final result = await FilePicker.pickFiles(
      type:
          Platform.isAndroid || Platform.isIOS ? FileType.any : FileType.custom,
      allowedExtensions:
          Platform.isAndroid || Platform.isIOS ? null : ['ciderrecipe', 'json'],
    );

    if (result.isEmpty) return null;

    final filePath = result.first.path;
    if (filePath == null || filePath.isEmpty) return null;

    final lowerPath = filePath.toLowerCase();
    if (!lowerPath.endsWith('.ciderrecipe') && !lowerPath.endsWith('.json')) {
      throw const FormatException(
          'Выберите файл с расширением .ciderrecipe или .json');
    }

    final file = File(filePath);
    final content = await file.readAsString();
    final Map<String, dynamic> parsed = jsonDecode(content);

    if (parsed['type'] != 'cider_recipe' || parsed['data'] == null) {
      throw const FormatException(
          'Файл не содержит корректного рецепта CiderOff');
    }

    final recipe = Recipe.fromJson(parsed['data']);
    await _db.insertRecipe(recipe);
    return recipe;
  }
}
