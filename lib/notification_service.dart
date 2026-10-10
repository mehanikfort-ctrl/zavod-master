import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // 1. Инициализируем базу часовых поясов
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Если не удалось определить — оставляем UTC
    }

    // 2. Настройки для Android
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // 3. Настройки для Windows
    const windowsSettings = WindowsInitializationSettings(
      appName: 'Завод-Механик',
      appUserModelId: 'Com.ZavodMaster.App',
      guid: 'd49b0314-ee7a-4626-bf79-97cdb8a991bb',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(initSettings);

    // 4. Запрашиваем разрешения на Android 13+
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  /// Показывает уведомление сразу
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'zavod_master_channel',
      'Задачи',
      channelDescription: 'Напоминания о задачах',
      importance: Importance.high,
      priority: Priority.high,
    );

    const windowsDetails = WindowsNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      windows: windowsDetails,
    );

    await _plugin.show(id, title, body, details);
  }

  /// Планирует уведомление на конкретную дату и время.
  /// Работает и на Android, и на Windows.
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    await init();

    // Если время уже прошло — не планируем
    if (dateTime.isBefore(DateTime.now())) return;

    final scheduledTZ = tz.TZDateTime.from(dateTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'zavod_master_channel',
      'Задачи',
      channelDescription: 'Напоминания о задачах',
      importance: Importance.high,
      priority: Priority.high,
    );

    const windowsDetails = WindowsNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      windows: windowsDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTZ,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Отменяет уведомление по id
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Отменяет все уведомления
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
