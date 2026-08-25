import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Инициализация плагина и часовых поясов
  Future<void> init() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // Инициализируем базы часовых поясов
    tz.initializeTimeZones();
    
    // Автоматическое определение локальной часовой зоны через имя или смещение
    try {
      final String timeZoneName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Фолбэк на UTC, если системная часовая зона не нашлась в базе tz
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Запрос разрешений для Android 13+
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  /// Запланировать уведомление о следующем шаге
  Future<void> scheduleStepNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (scheduledDate.isBefore(DateTime.now())) return;

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'batch_reminders',
            'Напоминания о партиях',
            channelDescription: 'Уведомления о наступлении следующего этапа брожения',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('Ошибка при планировании уведомления: $e');
    }
  }

  /// Отмена уведомления
  Future<void> cancelNotification(int id) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}