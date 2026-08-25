import 'package:flutter/material.dart';
import '../../data/models/card_settings_model.dart';

class AppSettingsProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('ru');
  ThemeMode _themeMode = ThemeMode.system;
  CardSettingsModel _cardSettings = CardSettingsModel();

  Locale get currentLocale => _currentLocale;
  ThemeMode get themeMode => _themeMode;
  CardSettingsModel get cardSettings => _cardSettings;

  void updateCardSettings(CardSettingsModel newSettings) {
    _cardSettings = newSettings;
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