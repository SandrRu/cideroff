import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cider_off/presentation/providers/app_settings_provider.dart';

class DashboardSettingsScreen extends StatelessWidget {
  const DashboardSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<AppSettingsProvider>();
    final dashboardSettings = settingsProvider.dashboardSettings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки Дашборда'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Количество колонок сетки:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1 колонка')),
                ButtonSegment(value: 2, label: Text('2 колонки')),
                ButtonSegment(value: 3, label: Text('3 колонки')),
              ],
              selected: {dashboardSettings.crossAxisCount},
              onSelectionChanged: (selection) {
                settingsProvider.updateDashboardSettings(
                  dashboardSettings.copyWith(crossAxisCount: selection.first),
                );
              },
            ),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Отображаемые карточки:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Объем готового напитка'),
            value: dashboardSettings.showTotalCompletedVolume,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateDashboardSettings(
                  dashboardSettings.copyWith(showTotalCompletedVolume: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Объем в процессе'),
            value: dashboardSettings.showTotalInProgressVolume,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateDashboardSettings(
                  dashboardSettings.copyWith(showTotalInProgressVolume: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Ближайший шаг'),
            value: dashboardSettings.showNearestStep,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateDashboardSettings(
                  dashboardSettings.copyWith(showNearestStep: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Распределение по типам'),
            value: dashboardSettings.showTypeDistribution,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateDashboardSettings(
                  dashboardSettings.copyWith(showTypeDistribution: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Активные брожения'),
            value: dashboardSettings.showActiveFermentationCount,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateDashboardSettings(
                  dashboardSettings.copyWith(showActiveFermentationCount: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Дрожжи в работе'),
            value: dashboardSettings.showActiveYeasts,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateDashboardSettings(
                  dashboardSettings.copyWith(showActiveYeasts: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Готовность по видам тары'),
            value: dashboardSettings.showFinishedPackaging,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateDashboardSettings(
                  dashboardSettings.copyWith(showFinishedPackaging: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Быстрый калькулятор'),
            value: dashboardSettings.showQuickCalculatorCard,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateDashboardSettings(
                  dashboardSettings.copyWith(showQuickCalculatorCard: val),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}