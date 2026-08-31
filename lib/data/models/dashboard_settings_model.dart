class DashboardSettingsModel {
  final int crossAxisCount; // Количество колонок (1–3)
  final bool showTotalCompletedVolume; // Общий объем готового напитка (л)
  final bool showTotalInProgressVolume; // Общий объем в процессе (л)
  final bool showNearestStep; // Ближайший шаг
  final bool showTypeDistribution; // Распределение по типам (Сидр vs Кальвадос)
  final bool showActiveFermentationCount; // Активные брожения
  final bool showActiveYeasts; // Используемые дрожжи в ходу
  final bool showFinishedPackaging; // Готовность по видам тары
  final bool showQuickCalculatorCard; // Быстрый калькулятор

  DashboardSettingsModel({
    this.crossAxisCount = 2,
    this.showTotalCompletedVolume = true,
    this.showTotalInProgressVolume = true,
    this.showNearestStep = true,
    this.showTypeDistribution = true,
    this.showActiveFermentationCount = true,
    this.showActiveYeasts = true,
    this.showFinishedPackaging = true,
    this.showQuickCalculatorCard = true,
  });

  DashboardSettingsModel copyWith({
    int? crossAxisCount,
    bool? showTotalCompletedVolume,
    bool? showTotalInProgressVolume,
    bool? showNearestStep,
    bool? showTypeDistribution,
    bool? showActiveFermentationCount,
    bool? showActiveYeasts,
    bool? showFinishedPackaging,
    bool? showQuickCalculatorCard,
  }) {
    return DashboardSettingsModel(
      crossAxisCount: crossAxisCount ?? this.crossAxisCount,
      showTotalCompletedVolume: showTotalCompletedVolume ?? this.showTotalCompletedVolume,
      showTotalInProgressVolume: showTotalInProgressVolume ?? this.showTotalInProgressVolume,
      showNearestStep: showNearestStep ?? this.showNearestStep,
      showTypeDistribution: showTypeDistribution ?? this.showTypeDistribution,
      showActiveFermentationCount: showActiveFermentationCount ?? this.showActiveFermentationCount,
      showActiveYeasts: showActiveYeasts ?? this.showActiveYeasts,
      showFinishedPackaging: showFinishedPackaging ?? this.showFinishedPackaging,
      showQuickCalculatorCard: showQuickCalculatorCard ?? this.showQuickCalculatorCard,
    );
  }
}