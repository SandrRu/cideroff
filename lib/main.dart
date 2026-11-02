import 'dart:async';
import 'dart:io';

import 'package:cider_off/core/utils/test_data_seeder.dart';
import 'package:cider_off/presentation/providers/app_settings_provider.dart';
import 'package:cider_off/presentation/providers/batch_provider.dart';
import 'package:cider_off/presentation/providers/recipe_provider.dart';
import 'package:cider_off/presentation/providers/sweetener_provider.dart';
import 'package:cider_off/presentation/providers/yeast_provider.dart';
import 'package:cider_off/presentation/screens/main/main_shell_screen.dart';
import 'package:cider_off/services/app_logger.dart';
import 'package:cider_off/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final logger = AppLogger.instance;

  // Любая ошибка должна быть залогирована, а не оставлять белый экран.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Логгер поднимаем первым, чтобы поймать ошибки инициализации.
      await logger.init();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        logger.error('Flutter error: ${details.exceptionAsString()}', details.exception, details.stack);
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        logger.error('Необработанная ошибка платформы', error, stack);
        return true;
      };

      if (kReleaseMode) {
        // В релизе вместо красного экрана — понятное сообщение.
        ErrorWidget.builder = (details) => const _UnexpectedErrorWidget();
      }

      // Инициализация FFI для Windows / Linux / macOS
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      // Сбой уведомлений или подготовки данных не должен блокировать запуск.
      try {
        await NotificationService.instance.init();
      } catch (error, stack) {
        logger.error('Ошибка инициализации уведомлений', error, stack);
      }

      try {
        // Справочники и встроенные рецепты нужны всегда,
        // демонстрационные партии — только в debug-сборке.
        await TestDataSeeder.seedDatabase(includeDemoData: kDebugMode);
      } catch (error, stack) {
        logger.error('Ошибка подготовки данных приложения', error, stack);
      }

      logger.info('Лог-файл: ${logger.logFilePath}');
      runApp(const CiderOffApp());
    },
    (error, stack) => logger.error('Необработанная ошибка', error, stack),
  );
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
        ChangeNotifierProvider(create: (_) => YeastProvider()),
        ChangeNotifierProvider(create: (_) => SweetenerProvider()),
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
              inputDecorationTheme: const InputDecorationTheme(
                labelStyle: TextStyle(color: Colors.black87),
                hintStyle: TextStyle(color: Colors.black45),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black38),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.amber, width: 2),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.amber,
              brightness: Brightness.dark,
              inputDecorationTheme: const InputDecorationTheme(
                labelStyle: TextStyle(color: Colors.white70),
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.amber, width: 2),
                ),
              ),
            ),
            themeMode: settings.themeMode,
            locale: settings.currentLocale,
            supportedLocales: const [
              Locale('ru'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MainShellScreen(),
          );
        },
      ),
    );
  }
}

class _UnexpectedErrorWidget extends StatelessWidget {
  const _UnexpectedErrorWidget();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFDF3E7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.error_outline, size: 40, color: Color(0xFFB3261E)),
              SizedBox(height: 12),
              Text(
                'Не удалось отобразить этот раздел',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Попробуйте вернуться назад или перезапустить приложение.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
