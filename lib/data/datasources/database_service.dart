import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' hide Batch;
import '../models/batch_model.dart';
import '../models/batch_history_model.dart';
import '../models/recipe_model.dart';
import '../models/label_template_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cider_off.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const realNullable = 'REAL';
    const realType = 'REAL NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const integerNullable = 'INTEGER';

    // 1. Таблица Партий
    await db.execute('''
      CREATE TABLE batches (
        id $textType PRIMARY KEY,
        name $textType,
        appleVariety $textType,
        initialSugar $realType,
        juiceVolume $realType,
        pressDate $textType,
        status $textType,
        type TEXT DEFAULT 'cider',
        currentRecipeId $textNullable,
        currentStepIndex $integerNullable,
        nextStepDate $textNullable,
        containerType $textNullable,
        containerCount $integerNullable,
        finalSugar $realNullable,
        finalAlcohol $realNullable,
        primingSugarGrams $realNullable,
        nonFermentableSugarGrams $realNullable,
        finalSugarWithPriming $realNullable,
        notes $textNullable,
        rawSpiritVolume $realNullable,
        rawSpiritABV $realNullable,
        distillateVolume $realNullable,
        distillateABV $realNullable,
        barrelDilutedABV $realNullable,
        agingStartDate $textNullable,
        barrelNotes $textNullable,
        FOREIGN KEY (currentRecipeId) REFERENCES recipes (id) ON DELETE SET NULL
      )
    ''');

    // 2. Таблица Истории
    await db.execute('''
      CREATE TABLE history (
        id $textType PRIMARY KEY,
        batchId $textType,
        timestamp $textType,
        stepTitle $textType,
        actionName $textType,
        sugarMeasured $realNullable,
        alcoholMeasured $realNullable,
        nonFermentableSugarGrams $realNullable,
        note $textNullable,
        FOREIGN KEY (batchId) REFERENCES batches (id) ON DELETE CASCADE
      )
    ''');

    // 3. Таблица Рецептов
    await db.execute('''
      CREATE TABLE recipes (
        id $textType PRIMARY KEY,
        title $textType,
        description $textNullable,
        isCustom $integerType,
        isFavorite $integerType,
        steps $textType
      )
    ''');

    // 4. Таблица Макетов Этикеток
    await db.execute('''
      CREATE TABLE label_templates (
        id $textType PRIMARY KEY,
        name $textType,
        widthMm $realType,
        heightMm $realType,
        schemaJson $textType
      )
    ''');
  }

  /// Безопасная миграция структуры БД при обновлении версии
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfNotExists(db, 'batches', 'type', "TEXT DEFAULT 'cider'");
      await _addColumnIfNotExists(db, 'batches', 'rawSpiritVolume', 'REAL');
      await _addColumnIfNotExists(db, 'batches', 'rawSpiritABV', 'REAL');
      await _addColumnIfNotExists(db, 'batches', 'distillateVolume', 'REAL');
      await _addColumnIfNotExists(db, 'batches', 'distillateABV', 'REAL');
      await _addColumnIfNotExists(db, 'batches', 'barrelDilutedABV', 'REAL');
      await _addColumnIfNotExists(db, 'batches', 'agingStartDate', 'TEXT');
      await _addColumnIfNotExists(db, 'batches', 'barrelNotes', 'TEXT');
    }

    if (oldVersion < 3) {
      await _addColumnIfNotExists(db, 'batches', 'primingSugarGrams', 'REAL');
      await _addColumnIfNotExists(db, 'batches', 'finalSugarWithPriming', 'REAL');
    }

    if (oldVersion < 4) {
      await _addColumnIfNotExists(db, 'batches', 'nonFermentableSugarGrams', 'REAL');
    }
    
    if (oldVersion < 5) {
      await _addColumnIfNotExists(db, 'history', 'nonFermentableSugarGrams', 'REAL');
    }    
  }

  /// Проверка существования колонки перед добавлением для предотвращения Duplicate Column Error
  Future<void> _addColumnIfNotExists(
    Database db,
    String table,
    String column,
    String typeDefinition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $typeDefinition');
    }
  }

  // --- CRUD ДЛЯ ПАРТИЙ ---

  Future<void> insertBatch(Batch batch) async {
    final db = await instance.database;
    await db.insert('batches', batch.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Batch>> getAllBatches() async {
    final db = await instance.database;
    final result = await db.query('batches', orderBy: 'pressDate DESC');
    
    final List<Batch> batches = [];
    for (final json in result) {
      try {
        batches.add(Batch.fromJson(json));
      } catch (e, stack) {
        debugPrint('Ошибка парсинга партии ID ${json['id']}: $e');
        debugPrint(stack.toString());
      }
    }
    return batches;
  }

  Future<Batch?> getBatchById(String id) async {
    final db = await instance.database;
    final maps = await db.query('batches', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      try {
        return Batch.fromJson(maps.first);
      } catch (e) {
        debugPrint('Ошибка парсинга партии по ID $id: $e');
      }
    }
    return null;
  }

  Future<void> updateBatch(Batch batch) async {
    final db = await instance.database;
    await db.update(
      'batches',
      batch.toJson(),
      where: 'id = ?',
      whereArgs: [batch.id],
    );
  }

  Future<void> deleteBatch(String id) async {
    final db = await instance.database;
    await db.delete('batches', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD ДЛЯ ИСТОРИИ ---

  Future<void> insertHistory(BatchHistory history) async {
    final db = await instance.database;
    await db.insert('history', history.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BatchHistory>> getHistoryForBatch(String batchId) async {
    final db = await instance.database;
    final result = await db.query(
      'history',
      where: 'batchId = ?',
      whereArgs: [batchId],
      orderBy: 'timestamp DESC',
    );
    return result.map((json) => BatchHistory.fromJson(json)).toList();
  }

  // --- CRUD ДЛЯ РЕЦЕПТОВ ---

  Future<void> insertRecipe(Recipe recipe) async {
    final db = await instance.database;
    final data = recipe.toJson();
    data['title'] = jsonEncode(data['title']);
    data['description'] = data['description'] != null ? jsonEncode(data['description']) : null;
    data['isCustom'] = recipe.isCustom ? 1 : 0;
    data['isFavorite'] = recipe.isFavorite ? 1 : 0;
    data['steps'] = jsonEncode(data['steps']);

    await db.insert('recipes', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Recipe>> getAllRecipes() async {
    final db = await instance.database;
    final result = await db.query('recipes');
    return result.map((map) {
      final mutable = Map<String, dynamic>.from(map);
      
      if (mutable['title'] is String) {
        mutable['title'] = jsonDecode(mutable['title'] as String);
      }
      if (mutable['description'] is String) {
        mutable['description'] = jsonDecode(mutable['description'] as String);
      } else if (mutable['description'] == null) {
        mutable['description'] = {};
      }
      
      // Безопасное приведение числовых/булевых типов
      mutable['isCustom'] = mutable['isCustom'] == 1 || mutable['isCustom'] == true;
      mutable['isFavorite'] = mutable['isFavorite'] == 1 || mutable['isFavorite'] == true;
      
      if (mutable['steps'] is String) {
        mutable['steps'] = jsonDecode(mutable['steps'] as String);
      }
      
      return Recipe.fromJson(mutable);
    }).toList();
  }

  // --- CRUD ДЛЯ МАКЕТОВ ---

  Future<void> insertLabelTemplate(LabelTemplate template) async {
    final db = await instance.database;
    await db.insert('label_templates', template.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LabelTemplate>> getAllLabelTemplates() async {
    final db = await instance.database;
    final result = await db.query('label_templates');
    return result.map((json) => LabelTemplate.fromJson(json)).toList();
  }

  Future<int> updateLabelTemplate(LabelTemplate template) async {
    final db = await instance.database;
    return await db.update(
      'label_templates',
      template.toJson(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  Future<int> deleteLabelTemplate(String id) async {
    final db = await instance.database;
    return await db.delete(
      'label_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Полная очистка всех пользовательских данных
  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('history');
    await db.delete('batches');
    await db.delete('recipes', where: 'isCustom = 1');
  }

  // --- CRUD ДЛЯ ИСТОРИИ ---

  Future<int> updateHistory(BatchHistory history) async {
    final db = await instance.database;
    return await db.update(
      'history',
      history.toJson(),
      where: 'id = ?',
      whereArgs: [history.id],
    );
  }

  Future<int> deleteHistory(String id) async {
    final db = await instance.database;
    return await db.delete(
      'history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}