import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cider_off/presentation/providers/app_settings_provider.dart'; // <-- Импорт провайдера
import 'package:cider_off/presentation/providers/batch_provider.dart';
import 'package:cider_off/presentation/providers/recipe_provider.dart';
import 'package:cider_off/core/utils/test_data_seeder.dart';
import 'package:cider_off/presentation/screens/main/main_screen.dart';
import 'package:cider_off/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация FFI для Windows / Linux / macOS
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Инициализация push-уведомлений и таймзон
  await NotificationService.instance.init();

  // Заполнение базы тестовыми данными
  await TestDataSeeder.seedDatabase();

  runApp(const CiderOffApp());
}

class CiderOffApp extends StatelessWidget {
  const CiderOffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => BatchProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'CiderOff',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.amber,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.amber,
              brightness: Brightness.dark,
            ),
            themeMode: settings.themeMode,
            locale: settings.currentLocale,
            supportedLocales: const [
              Locale('ru', ''),
              Locale('en', ''),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}