import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cider_off/presentation/providers/app_settings_provider.dart';
import 'package:cider_off/presentation/providers/batch_provider.dart';
import '../cellar/cellar_screen.dart';
import 'widgets/dashboard_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final batchProvider = context.watch<BatchProvider>();
    final settings = context.watch<AppSettingsProvider>().dashboardSettings;

    final inProgressBatches = batchProvider.inProgressBatches;
    final completedBatches = batchProvider.completedBatches;

    // Подсчет агрегированных данных
    final totalInProgressVolume = inProgressBatches.fold<double>(
      0.0,
      (sum, b) => sum + b.juiceVolume,
    );

    final ciderCount = batchProvider.batches.where((b) => b.type.name == 'cider').length;
    final calvadosCount = batchProvider.batches.where((b) => b.type.name == 'calvados').length;

    // Поиск ближайшей партии по дате следующего шага
    final activeWithDates = inProgressBatches.where((b) => b.nextStepDate != null).toList();
    if (activeWithDates.isNotEmpty) {
      activeWithDates.sort((a, b) => a.nextStepDate!.compareTo(b.nextStepDate!));
    }
    final nearestBatch = activeWithDates.isNotEmpty ? activeWithDates.first : null;

    // Формирование динамического списка активных виджетов
    final List<Widget> activeWidgets = [];

    if (settings.showTotalCompletedVolume) {
      activeWidgets.add(
        TotalCompletedVolumeCard(
          completedBatches: completedBatches,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CellarScreen()),
            );
          },
        ),
      );
    }
    if (settings.showTotalInProgressVolume) {
      activeWidgets.add(TotalInProgressVolumeCard(volumeLiters: totalInProgressVolume));
    }
    if (settings.showNearestStep) {
      activeWidgets.add(NearestStepCard(nearestBatch: nearestBatch));
    }
    if (settings.showTypeDistribution) {
      activeWidgets.add(TypeDistributionCard(ciderCount: ciderCount, calvadosCount: calvadosCount));
    }
    if (settings.showActiveFermentationCount) {
      activeWidgets.add(ActiveFermentationsCard(count: inProgressBatches.length));
    }
    if (settings.showActiveYeasts) {
      activeWidgets.add(ActiveYeastsCard(batches: batchProvider.batches));
    }
    if (settings.showFinishedPackaging) {
      activeWidgets.add(PackagingVolumeDistributionCard(batches: batchProvider.batches));
    }
    if (settings.showQuickCalculatorCard) {
      activeWidgets.add(const QuickCalculatorCard());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Дашборд', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: batchProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: settings.crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.3,
                ),
                itemCount: activeWidgets.length,
                itemBuilder: (context, index) => activeWidgets[index],
              ),
            ),
    );
  }
}