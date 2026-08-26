import '../../data/datasources/database_service.dart';
import '../../data/models/batch_model.dart';
import '../../data/models/batch_history_model.dart';
import '../../data/models/recipe_model.dart';
import '../../data/models/label_template_model.dart';

class TestDataSeeder {
  static Future<void> seedDatabase({bool forceUpdateRecipes = false}) async {
    final db = DatabaseService.instance;

    final existingRecipes = await db.getAllRecipes();
    final existingBatches = await db.getAllBatches();

    // 1. Проверка наличия данных перед инициализацией.
    // Если данные уже существуют и не запрошено принудительное обновление, выходим.
    if (!forceUpdateRecipes && (existingRecipes.isNotEmpty || existingBatches.isNotEmpty)) {
      return; 
    }

    // 2. Предустановленный рецепт Сидра
    final defaultRecipe = Recipe(
      id: 'recipe_classic_dry',
      title: {'ru': 'Классический сухой сидр', 'en': 'Classic Dry Cider'},
      description: {
        'ru': 'Традиционный сухой сидр с естественной карбонизацией декстрозой и выдержкой.',
        'en': 'Traditional dry cider naturally carbonated with dextrose and aged.'
      },
      isCustom: false,
      isFavorite: true,
      steps: [
        RecipeStep(
          stepIndex: 0,
          title: {'ru': 'Первичное брожение', 'en': 'Primary Fermentation'},
          instruction: {'ru': 'Установите гидрозатвор. Температура 18-22°C.', 'en': 'Attach airlock. Temp 18-22°C.'},
          durationDays: 14,
          requiresSugarMeasurement: true,
        ),
        RecipeStep(
          stepIndex: 1,
          title: {'ru': 'Снятие с осадка (Тихое брожение)', 'en': 'Secondary Fermentation'},
          instruction: {'ru': 'Слейте с дрожжевого осадка в чистый бутыль.', 'en': 'Rack off sediment into clean carboy.'},
          durationDays: 30,
          requiresSugarMeasurement: true,
          requiresAlcoholMeasurement: true,
        ),
        RecipeStep(
          stepIndex: 2,
          title: {'ru': 'Розлив и внесение декстрозы', 'en': 'Bottling & Priming'},
          instruction: {
            'ru': 'Разлейте по бутылкам. Внесите катализатор (декстрозу) из расчета 7-8 г/л.',
            'en': 'Bottle cider. Add dextrose (7-8 g/L) for carbonation.'
          },
          durationDays: 1,
          requiresSugarMeasurement: true,
          requiresAlcoholMeasurement: true,
          isBottlingStep: true,
        ),
        RecipeStep(
          stepIndex: 3,
          title: {'ru': 'Созревание в тепле', 'en': 'Warm Conditioning'},
          instruction: {
            'ru': 'Держите бутылки при комнатной температуре (20-22°C) 14 дней для естественной карбонизации.',
            'en': 'Keep bottles at room temperature for 14 days for natural carbonation.'
          },
          durationDays: 14,
        ),
        RecipeStep(
          stepIndex: 4,
          title: {'ru': 'Созревание на холоде (2 месяца)', 'en': 'Cold Conditioning'},
          instruction: {
            'ru': 'Уберите бутылки в прохладное место (погреб/холодильник) на 2 месяца (60 дней) для осветления и округления вкуса.',
            'en': 'Store bottles in a cool place (cellar/fridge) for 2 months (60 days).'
          },
          durationDays: 60,
        ),
      ],
    );
    await db.insertRecipe(defaultRecipe);

    // 3. Предустановленный рецепт Кальвадоса
    final calvadosRecipe = Recipe(
      id: 'recipe_classic_calvados',
      title: {'ru': 'Классический Кальвадос', 'en': 'Classic Calvados'},
      description: {
        'ru': 'Традиционный рецепт: сбраживание сока, двойная дистилляция и выдержка в дубовой бочке.',
        'en': 'Traditional recipe: fermentation, double distillation, and oak barrel aging.'
      },
      isCustom: false,
      isFavorite: true,
      steps: [
        RecipeStep(
          stepIndex: 0,
          title: {'ru': 'Отжим и запуск брожения', 'en': 'Primary Fermentation'},
          instruction: {'ru': 'Отожмите сок из кислых и горько-сладких яблок (цель: 13-15 г/100мл сахара). Внесите сидровые дрожжи.', 'en': 'Press juice from bitter-sweet apples. Pitch yeast.'},
          durationDays: 21,
          requiresSugarMeasurement: true,
        ),
        RecipeStep(
          stepIndex: 1,
          title: {'ru': 'Снятие с осадка и осветление', 'en': 'Racking'},
          instruction: {'ru': 'Слейте сухой сидр с дрожжевого осадка перед дистилляцией.', 'en': 'Rack dry cider off yeast sediment.'},
          durationDays: 7,
          requiresSugarMeasurement: true,
          requiresAlcoholMeasurement: true,
        ),
        RecipeStep(
          stepIndex: 2,
          title: {'ru': 'Первый перегон (Спирт-сырец)', 'en': 'First Distillation'},
          instruction: {'ru': 'Перегоните сидр на максимальной скорости до 0% в струе.', 'en': 'Distill down to 0% ABV in stream.'},
          durationDays: 1,
          requiresAlcoholMeasurement: true,
        ),
        RecipeStep(
          stepIndex: 3,
          title: {'ru': 'Второй дробный перегон', 'en': 'Second Distillation'},
          instruction: {'ru': 'Отберите 5% "голов". "Тело" отбирайте до 58-60% в струе.', 'en': 'Collect 5% heads. Cut tails at 58-60% ABV.'},
          durationDays: 1,
          requiresAlcoholMeasurement: true,
        ),
        RecipeStep(
          stepIndex: 4,
          title: {'ru': 'Разбавление и заливка в бочку', 'en': 'Barrel Filling'},
          instruction: {'ru': 'Разбавьте дистиллят водой до 55-60% об. и залейте в дубовую бочку.', 'en': 'Dilute to 55-60% ABV and fill barrel.'},
          durationDays: 1,
          requiresAlcoholMeasurement: true,
        ),
        RecipeStep(
          stepIndex: 5,
          title: {'ru': 'Созревание и выдержка', 'en': 'Barrel Aging'},
          instruction: {'ru': 'Выдерживайте в бочке от 6 месяцев.', 'en': 'Age for 6+ months in barrel.'},
          durationDays: 180,
        ),
        RecipeStep(
          stepIndex: 6,
          title: {'ru': 'Финишное разбавление и розлив', 'en': 'Final Bottling'},
          instruction: {'ru': 'Разбавьте до питьевых 40-42% об., дайте отдохнуть 14 дней в стекле и разлейте.', 'en': 'Dilute to 40-42% ABV and bottle.'},
          durationDays: 14,
          requiresSugarMeasurement: true,
          requiresAlcoholMeasurement: true,
          isBottlingStep: true,
        ),
      ],
    );
    await db.insertRecipe(calvadosRecipe);

    // 4. Шаблон термоэтикетки
    final defaultTemplate = LabelTemplate(
      id: 'template_58x40',
      name: 'Стандартная 58x40 мм',
      widthMm: 58.0,
      heightMm: 40.0,
      schemaJson: '{}',
    );
    await db.insertLabelTemplate(defaultTemplate);

    // 5. Активная партия
    final activeBatch = Batch(
      id: 'batch_active_01',
      name: 'Антоновка 2026',
      appleVariety: 'Антоновка десертная',
      initialSugar: 12.5,
      juiceVolume: 25.0,
      pressDate: DateTime.now().subtract(const Duration(days: 10)),
      status: BatchStatus.inProgress,
      currentRecipeId: defaultRecipe.id,
      currentStepIndex: 1,
      nextStepDate: DateTime.now().add(const Duration(days: 4)),
      containerCount: 0,
      notes: 'Отличный аромат, высокий уровень кислотности.',
    );
    await db.insertBatch(activeBatch);

    await db.insertHistory(
      BatchHistory(
        batchId: activeBatch.id,
        timestamp: DateTime.now().subtract(const Duration(days: 10)),
        stepTitle: 'Первичное брожение',
        actionName: 'Партия создана',
        sugarMeasured: 12.5,
        alcoholMeasured: 0.0,
        note: 'Залито 25 литров сока',
      ),
    );

    // 6. Готовая партия
    final completedBatch = Batch(
      id: 'batch_completed_01',
      name: 'Штрифлинг Резерв',
      appleVariety: 'Штрифлинг, Коричное',
      initialSugar: 13.0,
      juiceVolume: 15.0,
      pressDate: DateTime.now().subtract(const Duration(days: 60)),
      status: BatchStatus.completed,
      containerType: 'Бугельная бутылка 0.75л',
      containerCount: 20,
      finalSugar: 0.0,
      finalAlcohol: 6.1,
      notes: 'Освежающий, прозрачный, хорошая естественная газация.',
    );
    await db.insertBatch(completedBatch);

    await db.insertHistory(
      BatchHistory(
        batchId: completedBatch.id,
        timestamp: DateTime.now().subtract(const Duration(days: 60)),
        stepTitle: 'Первичное брожение',
        actionName: 'Партия создана',
        sugarMeasured: 13.0,
        alcoholMeasured: 0.0,
      ),
    );
  }
}