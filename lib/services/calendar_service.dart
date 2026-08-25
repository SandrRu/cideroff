import 'dart:io';
import 'package:flutter/services.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  /// Запрос разрешений и добавление события в календарь
  Future<bool> addStepToCalendar({
    required String batchName,
    required String stepTitle,
    required String instruction,
    required DateTime targetDate,
  }) async {
    // 1. Проверка платформы: device_calendar поддерживается только на Android и iOS
    if (!Platform.isAndroid && !Platform.isIOS) {
      // На десктопе пропускаем интеграцию с системным календарем
      return false;
    }

    try {
      // 2. Запрос разрешений
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && !(permissionsGranted.data ?? false)) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess || !(permissionsGranted.data ?? false)) {
          return false;
        }
      }

      // 3. Получение списка доступных календарей
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess ||
          calendarsResult.data == null ||
          calendarsResult.data!.isEmpty) {
        return false;
      }

      // Выбираем первый календарь, доступный для записи (не read-only)
      final writableCalendars = calendarsResult.data!.where((c) => c.isReadOnly != true).toList();
      if (writableCalendars.isEmpty) return false;

      final calendar = writableCalendars.first;
      final calendarId = calendar.id;
      if (calendarId == null) return false;

      // 4. Подготовка времени события (10:00 утра)
      final startDate = DateTime(targetDate.year, targetDate.month, targetDate.day, 10, 0);
      final endDate = startDate.add(const Duration(hours: 1));

      // Инициализация базы часовых поясов timezone для TZDateTime
      tz.initializeTimeZones();
      final location = tz.getLocation(tz.local.name);

      final event = Event(
        calendarId,
        title: 'CiderOff: [$batchName] — $stepTitle',
        description: instruction,
        start: tz.TZDateTime.from(startDate, location),
        end: tz.TZDateTime.from(endDate, location),
        reminders: [Reminder(minutes: 60)], // Напоминание за 1 час
      );

      // 5. Создание события
      final createResult = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      return createResult?.isSuccess ?? false;

    } on MissingPluginException {
      // Перехват ошибки вызова на неподдерживаемой платформе
      return false;
    } catch (e) {
      // Игнорируем или логируем прочие ошибки
      return false;
    }
  }
}