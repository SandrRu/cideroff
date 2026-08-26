import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cider_off/data/models/batch_model.dart';
import 'package:cider_off/presentation/providers/batch_provider.dart';
import 'package:cider_off/presentation/providers/recipe_provider.dart';
import 'package:cider_off/presentation/screens/batch/batch_detail_screen.dart';
import 'package:cider_off/presentation/screens/batch/create_batch_screen.dart';
import 'package:cider_off/presentation/screens/calculator/calculator_screen.dart';
import 'package:cider_off/presentation/screens/settings/settings_screen.dart';
import 'package:cider_off/presentation/providers/app_settings_provider.dart';
import 'package:cider_off/data/models/recipe_model.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BatchProvider>().loadBatches();
        context.read<RecipeProvider>().loadRecipes();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatchProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CiderOff', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Калькулятор сидродела',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CalculatorScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Настройки',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'В процессе (${provider.inProgressBatches.length})'),
            Tab(text: 'Готовые (${provider.completedBatches.length})'),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBatchList(provider.inProgressBatches, isCompleted: false),
                _buildBatchList(provider.completedBatches, isCompleted: true),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateBatchScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Новая партия'),
      ),
    );
  }

  Widget _buildBatchList(List<Batch> batches, {required bool isCompleted}) {
    if (batches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCompleted ? Icons.inventory_2_outlined : Icons.science_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              isCompleted ? 'Нет готовых партий' : 'Нет активных партий',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: batches.length,
      itemBuilder: (context, index) {
        final batch = batches[index];
        return _BatchCard(batch: batch, isCompleted: isCompleted);
      },
    );
  }
}

class _BatchCard extends StatelessWidget {
  final Batch batch;
  final bool isCompleted;

  const _BatchCard({required this.batch, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final isCalvados = batch.type == BatchType.calvados;
    final settings = context.select((AppSettingsProvider p) => p.cardSettings);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BatchDetailScreen(batchId: batch.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isCalvados
                              ? const Color(0xFFD48115)
                              : const Color(0xFFE8C245),
                          child: Text(
                            isCalvados ? '🥃' : '🍏',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            batch.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (settings.showTypeBadge) ...[
                    const SizedBox(width: 8),
                    Chip(
                      labelStyle: const TextStyle(fontSize: 12),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: isCompleted
                          ? Colors.green.shade100
                          : (isCalvados ? Colors.orange.shade100 : Colors.amber.shade100),
                      label: Text(
                        isCompleted 
                            ? (isCalvados ? 'Выдержан' : 'Розлито') 
                            : (isCalvados ? 'Перегон / Бочка' : 'Бродильня'),
                        style: TextStyle(
                          color: isCompleted
                              ? Colors.green.shade900
                              : (isCalvados ? Colors.orange.shade900 : Colors.amber.shade900),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (settings.showVariety || settings.showVolume) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (settings.showVariety)
                      Text(
                        'Сорт: ${batch.appleVariety}',
                        style: TextStyle(color: Colors.grey.shade700),
                      )
                    else
                      const SizedBox.shrink(),
                    if (settings.showVolume)
                      Text(
                        '${batch.juiceVolume} л сока',
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ],
              
              if (settings.showAgingDays && isCalvados && batch.daysInAging != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.wine_bar_outlined, size: 16, color: Colors.brown),
                    const SizedBox(width: 4),
                    Text(
                      'Выдерживается: ${batch.daysInAging} дн.',
                      style: const TextStyle(
                        color: Colors.brown,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],

              if (!isCompleted && (settings.showNextStepTitle || settings.showNextStepDate || settings.showDaysLeft)) ...[
                const Divider(height: 20),

                // Название следующего шага
                if (settings.showNextStepTitle) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Следующий шаг: ',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      Expanded(
                        child: Selector<RecipeProvider, String>(
                          selector: (_, recipeProvider) {
                            if (batch.notes.trim().isNotEmpty) {
                              return batch.notes.trim();
                            }

                            Recipe? foundRecipe;

                            // 1. Пробуем найти рецепт по строгому ID
                            if (batch.currentRecipeId != null && recipeProvider.recipes.isNotEmpty) {
                              final matches = recipeProvider.recipes
                                  .where((r) => r.id == batch.currentRecipeId)
                                  .toList();
                              if (matches.isNotEmpty) {
                                foundRecipe = matches.first;
                              }
                            }

                            // 2. Фоллбэк: если по ID не нашли, ищем первый подходящий по типу (Сидр / Кальвадос)
                            if (foundRecipe == null && recipeProvider.recipes.isNotEmpty) {
                              final isCalvados = batch.type == BatchType.calvados;
                              foundRecipe = recipeProvider.recipes.firstWhere(
                                (r) {
                                  final isRecipeCalvados = r.id.contains('calvados') ||
                                      (r.title['ru'] ?? '').toLowerCase().contains('кальвадос');
                                  return isCalvados ? isRecipeCalvados : !isRecipeCalvados;
                                },
                                orElse: () => recipeProvider.recipes.first,
                              );
                            }

                            // 3. Извлекаем название текущего шага
                            if (foundRecipe != null && foundRecipe.steps.isNotEmpty) {
                              final stepIdx = batch.currentStepIndex ?? 0;
                              if (stepIdx < foundRecipe.steps.length) {
                                final step = foundRecipe.steps[stepIdx];
                                final title = step.getTitle('ru');
                                if (title.isNotEmpty) {
                                  return title;
                                }
                              }
                            }

                            return 'Ожидание следующего этапа';
                          },
                          builder: (context, stepTitle, _) {
                            return Text(
                              stepTitle,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],

                // Дата выполнения
                if (settings.showNextStepDate)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Дата выполнения:',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      Text(
                        batch.nextStepDate != null
                            ? dateFormat.format(batch.nextStepDate!)
                            : '—',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                // Осталось дней
                if (settings.showDaysLeft && batch.daysUntilNextStep != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Осталось: ${batch.daysUntilNextStep} дн.',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ] else if (isCompleted && (settings.showSugar || settings.showAlcohol || settings.showContainers)) ...[
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (settings.showSugar)
                      Text('Сахар: ${batch.finalSugar ?? batch.initialSugar} г/100мл'),
                    if (settings.showAlcohol)
                      Text('Алкоголь: ${batch.finalAlcohol ?? 0}% об.'),
                  ],
                ),
                if (settings.showContainers) ...[
                  const SizedBox(height: 4),
                  Text('Тара: ${batch.containerType ?? "—"} (${batch.containerCount ?? 0} шт.)'),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}