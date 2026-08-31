import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' hide Batch;
import '../models/batch_model.dart';
import '../models/batch_history_model.dart';
import '../models/recipe_model.dart';
import '../models/label_template_model.dart';
import '../models/yeast_model.dart';
import '../models/batch_container_model.dart';

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
      version: 7,
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
        lossVolume $realNullable,
        notes $textNullable,
        rawSpiritVolume $realNullable,
        rawSpiritABV $realNullable,
        distillateVolume $realNullable,
        distillateABV $realNullable,
        barrelDilutedABV $realNullable,
        agingStartDate $textNullable,
        barrelNotes $textNullable,
        yeastId $textNullable,
        FOREIGN KEY (currentRecipeId) REFERENCES recipes (id) ON DELETE SET NULL,
        FOREIGN KEY (yeastId) REFERENCES yeasts (id) ON DELETE SET NULL
      )
    ''');

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

    await db.execute('''
      CREATE TABLE label_templates (
        id $textType PRIMARY KEY,
        name $textType,
        widthMm $realType,
        heightMm $realType,
        schemaJson $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE yeasts (
        id $textType PRIMARY KEY,
        name $textType,
        category $textType,
        description $textNullable,
        isCustom $integerType
      )
    ''');

    await db.execute('''
      CREATE TABLE batch_containers (
        id $textType PRIMARY KEY,
        batchId $textType,
        title $textType,
        sweetenerType $textNullable,
        sweetenerAmountGramsPerLiter $realType,
        containerType $textType,
        containerVolumeLiters $realType,
        count $integerType,
        FOREIGN KEY (batchId) REFERENCES batches (id) ON DELETE CASCADE
      )
    ''');
  }

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

    if (oldVersion < 6) {
      await _addColumnIfNotExists(db, 'batches', 'yeastId', 'TEXT');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS yeasts (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          description TEXT,
          isCustom INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS batch_containers (
          id TEXT PRIMARY KEY,
          batchId TEXT NOT NULL,
          title TEXT NOT NULL,
          sweetenerType TEXT,
          sweetenerAmountGramsPerLiter REAL NOT NULL DEFAULT 0.0,
          containerType TEXT NOT NULL,
          containerVolumeLiters REAL NOT NULL DEFAULT 0.75,
          count INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (batchId) REFERENCES batches (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 7) {
      await _addColumnIfNotExists(db, 'batches', 'lossVolume', 'REAL');
    }
  }

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

  // --- CRUD ДЛЯ ПАРТИЙ С ПОДДЕРЖКОЙ ПОДПАРТИЙ ---

  Future<void> insertBatch(Batch batch) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('batches', batch.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);

      if (batch.containers.isNotEmpty) {
        await txn.delete('batch_containers', where: 'batchId = ?', whereArgs: [batch.id]);
        for (final container in batch.containers) {
          await txn.insert('batch_containers', container.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<List<Batch>> getAllBatches() async {
    final db = await instance.database;
    final result = await db.query('batches', orderBy: 'pressDate DESC');
    
    final List<Batch> batches = [];
    for (final json in result) {
      try {
        final batchId = json['id'] as String;
        final containers = await getContainersForBatch(batchId);
        batches.add(Batch.fromJson(json, containers: containers));
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
        final containers = await getContainersForBatch(id);
        return Batch.fromJson(maps.first, containers: containers);
      } catch (e) {
        debugPrint('Ошибка парсинга партии по ID $id: $e');
      }
    }
    return null;
  }

  Future<void> updateBatch(Batch batch) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'batches',
        batch.toJson(),
        where: 'id = ?',
        whereArgs: [batch.id],
      );

      await txn.delete('batch_containers', where: 'batchId = ?', whereArgs: [batch.id]);
      for (final container in batch.containers) {
        await txn.insert('batch_containers', container.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
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

  // --- CRUD ДЛЯ РЕЦЕПТОВ ---

  Future<void> insertRecipe(Recipe recipe) async {
    final db = await instance.database;

    // Проверяем, существует ли уже такой рецепт
    final existing = await db.query('recipes', where: 'id = ?', whereArgs: [recipe.id]);

    if (existing.isNotEmpty) {
      final isExistingCustom = (existing.first['isCustom'] == 1 || existing.first['isCustom'] == true);

      // Блокируем изменение системного рецепта (разрешаем обновлять только isFavorite)
      if (!isExistingCustom) {
        final existingTitle = existing.first['title'] as String;
        final existingDesc = existing.first['description'] != null ? existing.first['description'] as String : null;
        final existingSteps = existing.first['steps'] as String;

        await db.update(
          'recipes',
          {
            'title': existingTitle,
            'description': existingDesc,
            'isCustom': 0,
            'isFavorite': recipe.isFavorite ? 1 : 0,
            'steps': existingSteps,
          },
          where: 'id = ?',
          whereArgs: [recipe.id],
        );
        return;
      }
    }

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
      
      mutable['isCustom'] = mutable['isCustom'] == 1 || mutable['isCustom'] == true;
      mutable['isFavorite'] = mutable['isFavorite'] == 1 || mutable['isFavorite'] == true;
      
      if (mutable['steps'] is String) {
        mutable['steps'] = jsonDecode(mutable['steps'] as String);
      }
      
      return Recipe.fromJson(mutable);
    }).toList();
  }

  Future<int> deleteRecipe(String id) async {
    final db = await instance.database;
    return await db.delete('recipes', where: 'id = ? AND isCustom = 1', whereArgs: [id]);
  }

  // --- CRUD ДЛЯ ДРОЖЖЕЙ ---

  Future<void> insertYeast(Yeast yeast) async {
    final db = await instance.database;
    await db.insert('yeasts', yeast.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Yeast>> getAllYeasts() async {
    final db = await instance.database;
    final result = await db.query('yeasts', orderBy: 'name ASC');
    return result.map((json) => Yeast.fromJson(json)).toList();
  }

  Future<int> deleteYeast(String id) async {
    final db = await instance.database;
    return await db.delete('yeasts', where: 'id = ? AND isCustom = 1', whereArgs: [id]);
  }

  // --- CRUD ДЛЯ ПОДПАРТИЙ / ТАРЫ ---

  Future<void> insertBatchContainer(BatchContainer container) async {
    final db = await instance.database;
    await db.insert('batch_containers', container.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BatchContainer>> getContainersForBatch(String batchId) async {
    final db = await instance.database;
    final result = await db.query(
      'batch_containers',
      where: 'batchId = ?',
      whereArgs: [batchId],
    );
    return result.map((json) => BatchContainer.fromJson(json)).toList();
  }

  Future<int> deleteBatchContainer(String id) async {
    final db = await instance.database;
    return await db.delete('batch_containers', where: 'id = ?', whereArgs: [id]);
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

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('history');
      await txn.delete('batch_containers');
      await txn.delete('batches');
      await txn.delete('recipes', where: 'isCustom = 1');
      await txn.delete('yeasts', where: 'isCustom = 1');
    });
  }
}