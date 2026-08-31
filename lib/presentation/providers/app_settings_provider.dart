import 'package:flutter/material.dart';
import '../../data/models/card_settings_model.dart';
import '../../data/models/dashboard_settings_model.dart';

class AppSettingsProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('ru');
  ThemeMode _themeMode = ThemeMode.system;
  CardSettingsModel _cardSettings = CardSettingsModel();
  DashboardSettingsModel _dashboardSettings = DashboardSettingsModel();

  Locale get currentLocale => _currentLocale;
  ThemeMode get themeMode => _themeMode;
  CardSettingsModel get cardSettings => _cardSettings;
  DashboardSettingsModel get dashboardSettings => _dashboardSettings;

  void updateCardSettings(CardSettingsModel newSettings) {
    _cardSettings = newSettings;
    notifyListeners();
  }

  void updateDashboardSettings(DashboardSettingsModel newSettings) {
    _dashboardSettings = newSettings;
    notifyListeners();
  }

  void setLocale(Locale locale) {
    _currentLocale = locale;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}