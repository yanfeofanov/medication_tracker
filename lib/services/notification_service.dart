// lib/services/notification_service.dart

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:medication_tracker/models/medication_course.dart';

class NotificationService {
  static const String channelKey = 'medication_reminders';
  static const String channelName = 'Напоминания о лекарствах';
  static const String channelDescription =
      'Уведомления о приеме лекарств и уколах';

  // Инициализация уведомлений
  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(null, [
      NotificationChannel(
        channelKey: channelKey,
        channelName: channelName,
        channelDescription: channelDescription,
        defaultColor: const Color(0xFF2196F3),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        locked: true,
        defaultPrivacy: NotificationPrivacy.Public,
        // Убрали soundSource чтобы избежать ошибки
        // soundSource: 'resource://raw/res_notification_sound',
      ),
    ]);

    // Запрашиваем разрешение
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  // Запланировать ежедневное уведомление
  static Future<void> scheduleDailyNotification({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _generateNotificationId(id),
        channelKey: channelKey,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        autoDismissible: false,
      ),
      schedule: NotificationCalendar(
        hour: hour,
        minute: minute,
        second: 0,
        millisecond: 0,
        repeats: true,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
  }

  // Запланировать уведомления для уколов по курсу
  static Future<void> scheduleInjectionNotifications(
    MedicationCourse course,
    String medicationName,
  ) async {
    try {
      print(
        '🔄 NotificationService: Начинаю планирование уведомлений для уколов',
      );

      // Отменяем старые уведомления для этого препарата
      await cancelAllNotificationsForMedication(course.medicationId);

      // Если уведомления не включены, выходим
      if (!course.hasNotifications) {
        print('⚠️ NotificationService: Уведомления для курса отключены');
        return;
      }

      // Получаем дату следующего укола (используем пустой список записей для расчета)
      final DateTime? calculatedDate = course.getNextInjectionDate([]);
      if (calculatedDate == null) {
        print(
          '⚠️ NotificationService: Не удалось определить дату следующего укола',
        );
        return;
      }

      // Используем calculatedDate, теперь это не-null значение
      final DateTime nextInjection = calculatedDate;

      print(
        '📅 NotificationService: Следующий укол: ${DateFormat('dd.MM.yyyy HH:mm').format(nextInjection)}',
      );

      // Уведомление за день до (если включено)
      if (course.injectionNotifyDayBefore ?? true) {
        final DateTime reminderDate = nextInjection.subtract(
          const Duration(days: 1),
        );

        // Устанавливаем время напоминания на 9 утра
        final DateTime reminderDateTime = DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          9,
          0,
        );

        print(
          '📅 NotificationService: Уведомление за день до: ${DateFormat('dd.MM.yyyy HH:mm').format(reminderDateTime)}',
        );

        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: _generateNotificationId(
              'injection_day_before_${course.medicationId}',
            ),
            channelKey: channelKey,
            title: '💉 Напоминание об уколе завтра',
            body: 'Завтра необходимо сделать укол $medicationName',
            notificationLayout: NotificationLayout.Default,
            autoDismissible: false,
          ),
          schedule: NotificationCalendar.fromDate(
            date: reminderDateTime,
            allowWhileIdle: true,
            preciseAlarm: true,
          ),
        );

        print('✅ NotificationService: Уведомление за день до запланировано');
      }

      // Уведомление в день укола
      // Устанавливаем время на 9 утра в день укола
      final DateTime injectionDateTime = DateTime(
        nextInjection.year,
        nextInjection.month,
        nextInjection.day,
        9,
        0,
      );

      print(
        '📅 NotificationService: Уведомление в день укола: ${DateFormat('dd.MM.yyyy HH:mm').format(injectionDateTime)}',
      );

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _generateNotificationId('injection_day_${course.medicationId}'),
          channelKey: channelKey,
          title: '💉 Время сделать укол',
          body: 'Сегодня необходимо сделать укол $medicationName',
          notificationLayout: NotificationLayout.Default,
          autoDismissible: false,
        ),
        schedule: NotificationCalendar.fromDate(
          date: injectionDateTime,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );

      print('✅ NotificationService: Уведомление в день укола запланировано');

      // Также планируем уведомления для следующих уколов (на 2 месяца вперед)
      await _scheduleFutureInjectionNotifications(course, medicationName);
    } catch (e, stackTrace) {
      print(
        '❌ NotificationService.scheduleInjectionNotifications(): Ошибка: $e',
      );
      print('Stack trace: $stackTrace');
    }
  }

  // Запланировать уведомления для будущих уколов
  static Future<void> _scheduleFutureInjectionNotifications(
    MedicationCourse course,
    String medicationName,
  ) async {
    try {
      // Планируем на 2 месяца вперед
      final DateTime endDate = DateTime.now().add(const Duration(days: 60));
      DateTime? nextDateNullable = course.getNextInjectionDate([]);

      // Если не можем получить следующую дату, выходим
      if (nextDateNullable == null) {
        print(
          '⚠️ NotificationService: Не удалось получить начальную дату для будущих уведомлений',
        );
        return;
      }

      // Теперь у нас есть гарантированно не-null значение
      DateTime nextDate = nextDateNullable;

      int notificationCount = 0;
      const int maxNotifications = 8; // Максимум 8 уведомлений

      while (nextDate.isBefore(endDate) &&
          notificationCount < maxNotifications) {
        // Создаем уведомление за день до
        if (course.injectionNotifyDayBefore ?? true) {
          final DateTime reminderDate = nextDate.subtract(
            const Duration(days: 1),
          );
          final DateTime reminderDateTime = DateTime(
            reminderDate.year,
            reminderDate.month,
            reminderDate.day,
            9,
            0,
          );

          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: _generateNotificationId(
                'future_day_before_${course.medicationId}_$notificationCount',
              ),
              channelKey: channelKey,
              title: '💉 Напоминание об уколе завтра',
              body: 'Завтра необходимо сделать укол $medicationName',
              notificationLayout: NotificationLayout.Default,
              autoDismissible: false,
            ),
            schedule: NotificationCalendar.fromDate(
              date: reminderDateTime,
              allowWhileIdle: true,
              preciseAlarm: true,
            ),
          );
        }

        // Создаем уведомление в день укола
        final DateTime injectionDateTime = DateTime(
          nextDate.year,
          nextDate.month,
          nextDate.day,
          9,
          0,
        );

        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: _generateNotificationId(
              'future_injection_${course.medicationId}_$notificationCount',
            ),
            channelKey: channelKey,
            title: '💉 Время сделать укол',
            body: 'Сегодня необходимо сделать укол $medicationName',
            notificationLayout: NotificationLayout.Default,
            autoDismissible: false,
          ),
          schedule: NotificationCalendar.fromDate(
            date: injectionDateTime,
            allowWhileIdle: true,
            preciseAlarm: true,
          ),
        );

        notificationCount++;

        // Рассчитываем следующую дату укола
        final DateTime? newDate = _calculateNextInjectionDate(
          nextDate,
          course.injectionFrequency,
          course.injectionIntervalDays,
        );
        if (newDate == null) break;
        nextDate = newDate;
      }

      print(
        '✅ NotificationService: Запланировано $notificationCount будущих уведомлений',
      );
    } catch (e) {
      print(
        '❌ NotificationService._scheduleFutureInjectionNotifications(): Ошибка: $e',
      );
    }
  }

  // Вспомогательный метод для расчета следующей даты укола
  static DateTime? _calculateNextInjectionDate(
    DateTime currentDate,
    InjectionFrequency? frequency,
    int? intervalDays,
  ) {
    try {
      switch (frequency) {
        case InjectionFrequency.daily:
          return currentDate.add(const Duration(days: 1));
        case InjectionFrequency.weekly:
          return currentDate.add(const Duration(days: 7));
        case InjectionFrequency.biweekly:
          return currentDate.add(const Duration(days: 14));
        case InjectionFrequency.monthly:
          return DateTime(
            currentDate.year,
            currentDate.month + 1,
            currentDate.day,
          );
        case InjectionFrequency.custom:
          final int interval = intervalDays ?? 14;
          return currentDate.add(Duration(days: interval));
        default:
          return currentDate.add(const Duration(days: 14));
      }
    } catch (e) {
      print('❌ Error calculating next injection date: $e');
      return null;
    }
  }

  // Старый метод (оставляем для обратной совместимости)
  static Future<void> scheduleInjectionNotification(
    DateTime nextInjectionDate,
  ) async {
    final List<int> daysBefore = [1, 3]; // Напоминать за 1 и 3 дня
    for (final int days in daysBefore) {
      final DateTime reminderDate = nextInjectionDate.subtract(
        Duration(days: days),
      );
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _generateNotificationId('injection_reminder_$days'),
          channelKey: channelKey,
          title: '💉 Напоминание об уколе',
          body: 'Через $days ${_getDayWord(days)} назначен укол',
          notificationLayout: NotificationLayout.Default,
        ),
        schedule: NotificationCalendar.fromDate(
          date: reminderDate,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );
    }
  }

  // Отменить все уведомления для препарата
  static Future<void> cancelAllNotificationsForMedication(
    String medicationId,
  ) async {
    try {
      // Отменяем ежедневные уведомления
      for (int i = 0; i < 3; i++) {
        final int notificationId = _generateNotificationId(
          '${medicationId}_$i',
        );
        await AwesomeNotifications().cancel(notificationId);
      }

      // Отменяем уколы
      await AwesomeNotifications().cancel(
        _generateNotificationId('injection_day_before_$medicationId'),
      );
      await AwesomeNotifications().cancel(
        _generateNotificationId('injection_day_$medicationId'),
      );

      // Отменяем будущие уведомления
      for (int i = 0; i < 8; i++) {
        await AwesomeNotifications().cancel(
          _generateNotificationId('future_day_before_${medicationId}_$i'),
        );
        await AwesomeNotifications().cancel(
          _generateNotificationId('future_injection_${medicationId}_$i'),
        );
      }

      print(
        '✅ NotificationService: Все уведомления для $medicationId отменены',
      );
    } catch (e) {
      print('❌ Error cancelling notifications for $medicationId: $e');
    }
  }

  // Отменить все уведомления
  static Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }

  // Показать немедленное уведомление
  static Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _generateNotificationId(
          'instant_${DateTime.now().millisecondsSinceEpoch}',
        ),
        channelKey: channelKey,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  // Генерация уникального ID для уведомления
  static int _generateNotificationId(String seed) {
    return seed.hashCode.abs() % 2147483647; // Максимальное значение для int
  }

  static String _getDayWord(int days) {
    if (days % 10 == 1 && days % 100 != 11) return 'день';
    if (days % 10 >= 2 &&
        days % 10 <= 4 &&
        (days % 100 < 10 || days % 100 >= 20)) {
      return 'дня';
    }
    return 'дней';
  }

  // Проверить, включены ли уведомления
  static Future<bool> areNotificationsEnabled() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }

  // Открыть настройки уведомлений
  static Future<void> openNotificationSettings() async {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }
}
