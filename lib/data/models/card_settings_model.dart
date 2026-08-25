class CardSettingsModel {
  final bool showVariety;
  final bool showVolume;
  final bool showNextStepTitle; // <-- Новое поле
  final bool showNextStepDate;
  final bool showDaysLeft;
  final bool showAgingDays;
  final bool showSugar;
  final bool showAlcohol;
  final bool showContainers;
  final bool showTypeBadge;

  CardSettingsModel({
    this.showVariety = true,
    this.showVolume = true,
    this.showNextStepTitle = true, // По умолчанию включено
    this.showNextStepDate = true,
    this.showDaysLeft = true,
    this.showAgingDays = true,
    this.showSugar = true,
    this.showAlcohol = true,
    this.showContainers = true,
    this.showTypeBadge = true,
  });

  CardSettingsModel copyWith({
    bool? showVariety,
    bool? showVolume,
    bool? showNextStepTitle,
    bool? showNextStepDate,
    bool? showDaysLeft,
    bool? showAgingDays,
    bool? showSugar,
    bool? showAlcohol,
    bool? showContainers,
    bool? showTypeBadge,
  }) {
    return CardSettingsModel(
      showVariety: showVariety ?? this.showVariety,
      showVolume: showVolume ?? this.showVolume,
      showNextStepTitle: showNextStepTitle ?? this.showNextStepTitle,
      showNextStepDate: showNextStepDate ?? this.showNextStepDate,
      showDaysLeft: showDaysLeft ?? this.showDaysLeft,
      showAgingDays: showAgingDays ?? this.showAgingDays,
      showSugar: showSugar ?? this.showSugar,
      showAlcohol: showAlcohol ?? this.showAlcohol,
      showContainers: showContainers ?? this.showContainers,
      showTypeBadge: showTypeBadge ?? this.showTypeBadge,
    );
  }
}