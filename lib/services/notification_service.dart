import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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

    tz.initializeTimeZones();
    
    try {
      final dynamic timeZoneResult = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneResult.toString();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Ошибка определения таймзоны, используем UTC fallback: $e');
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

    await flutterLocalNotificationsPlugin.initialize(settings: initSettings);

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
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: const NotificationDetails(
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
      );
    } catch (e) {
      debugPrint('Ошибка при планировании уведомления: $e');
    }
  }

/// Отмена уведомления по ID
  Future<void> cancelNotification(int id) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    // Передача именованного параметра id: id для v22.x
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  /// Отмена всех запланированных уведомлений
  Future<void> cancelAllNotifications() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}