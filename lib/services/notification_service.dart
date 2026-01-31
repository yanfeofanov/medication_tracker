// lib/services/notification_service.dart

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:medication_tracker/models/medication.dart';
import 'package:medication_tracker/models/medication_course.dart';
import 'dart:math';
import 'package:medication_tracker/models/medication_record.dart';
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      ),
    ]);

    // Запрашиваем разрешение
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    // Очищаем все старые уведомления при инициализации
    await cancelAllNotifications();
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
    final notificationId = _generateNotificationId(id);

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
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
      print('✅ Уведомление запланировано: $title в $hour:$minute');
    } catch (e) {
      print('❌ Ошибка при планировании уведомления: $e');
    }
  }

  // Запланировать уведомления для уколов по курсу
  static Future<void> scheduleInjectionNotifications(
    MedicationCourse course,
    String medicationName,
  ) async {
    try {
      print(
        '🔄 NotificationService: Начинаю планирование уведомлений для уколов препарата: $medicationName',
      );

      // Отменяем старые уведомления для этого препарата
      await cancelAllNotificationsForMedication(course.medicationId);

      // Если уведомления не включены, выходим
      if (!course.hasNotifications) {
        print('⚠️ NotificationService: Уведомления для курса отключены');
        return;
      }

      // Получаем user_id
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ NotificationService: Пользователь не авторизован');
        return;
      }

      // Запрос последней записи укола для этого препарата
      final response = await Supabase.instance.client
          .from('medication_records')
          .select('date_time, medication_type')
          .eq('user_id', userId)
          .eq('medication_id', course.medicationId)
          .order('date_time', ascending: false);

      // Фильтруем записи, чтобы оставить только уколы
      final List injectionRecords = response.where((record) {
        final type = record['medication_type'] as String?;
        return type == MedicationType.injection.toDbString() ||
            type == MedicationType.both.toDbString();
      }).toList();

      DateTime nextInjectionDate;

      if (injectionRecords.isNotEmpty &&
          injectionRecords[0]['date_time'] != null) {
        // Есть предыдущий укол - рассчитываем следующий
        final lastDate = DateTime.parse(
          injectionRecords[0]['date_time'] as String,
        ).toLocal();
        nextInjectionDate =
            _calculateNextInjectionDate(
              lastDate,
              course.injectionFrequency,
              course.injectionIntervalDays,
            ) ??
            lastDate.add(const Duration(days: 14));

        print(
          '📅 Найден последний укол: ${DateFormat('dd.MM.yyyy HH:mm').format(lastDate)}',
        );
      } else {
        // Нет предыдущих уколов - начинаем с сегодняшнего дня + интервал
        final firstInjectionDate = _calculateFirstInjectionDate(
          course.injectionFrequency,
          course.injectionIntervalDays,
        );
        nextInjectionDate =
            firstInjectionDate ?? DateTime.now().add(const Duration(days: 14));
        print(
          '📅 Нет предыдущих уколов, начинаем с: ${DateFormat('dd.MM.yyyy HH:mm').format(nextInjectionDate)}',
        );
      }

      print(
        '📅 NotificationService: Следующий укол: ${DateFormat('dd.MM.yyyy HH:mm').format(nextInjectionDate)}',
      );

      // Уведомление за день до (если включено)
      if (course.injectionNotifyDayBefore ?? true) {
        // Напоминания за 1, 2, 3 дня
        final List<int> reminderDays = [1, 2, 3];

        for (final int days in reminderDays) {
          final DateTime reminderDate = nextInjectionDate.subtract(
            Duration(days: days),
          );

          // Устанавливаем время напоминания на 9 утра
          final DateTime reminderDateTime = DateTime(
            reminderDate.year,
            reminderDate.month,
            reminderDate.day,
            9,
            0,
          );

          // Проверяем, что дата не в прошлом
          if (reminderDateTime.isAfter(DateTime.now())) {
            print(
              '📅 Уведомление за $days ${_getDayWord(days)} до: ${DateFormat('dd.MM.yyyy HH:mm').format(reminderDateTime)}',
            );

            await AwesomeNotifications().createNotification(
              content: NotificationContent(
                id: _generateNotificationId(
                  'injection_${days}_days_before_${course.medicationId}',
                ),
                channelKey: channelKey,
                title: '💉 Напоминание об уколе',
                body:
                    'Через $days ${_getDayWord(days)} необходимо сделать укол $medicationName',
                notificationLayout: NotificationLayout.Default,
                autoDismissible: false,
              ),
              schedule: NotificationCalendar.fromDate(
                date: reminderDateTime,
                allowWhileIdle: true,
                preciseAlarm: true,
              ),
            );
          } else {
            print('⚠️ Дата напоминания за $days дней уже прошла, пропускаем');
          }
        }
      }

      // Уведомление в день укола
      // Устанавливаем время на 9 утра в день укола
      final DateTime injectionDateTime = DateTime(
        nextInjectionDate.year,
        nextInjectionDate.month,
        nextInjectionDate.day,
        9,
        0,
      );

      // Проверяем, что дата не в прошлом
      if (injectionDateTime.isAfter(DateTime.now())) {
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
      } else {
        print('⚠️ Дата укола уже прошла, пропускаем');
      }

      // Также планируем уведомления для следующих уколов (на 2 месяца вперед)
      await _scheduleFutureInjectionNotifications(
        course,
        medicationName,
        nextInjectionDate,
      );
    } catch (e, stackTrace) {
      print(
        '❌ NotificationService.scheduleInjectionNotifications(): Ошибка: $e',
      );
      print('Stack trace: $stackTrace');
    }
  }

  // Расчет даты первого укола
  static DateTime? _calculateFirstInjectionDate(
    InjectionFrequency? frequency,
    int? intervalDays,
  ) {
    try {
      switch (frequency) {
        case InjectionFrequency.daily:
          return DateTime.now().add(const Duration(days: 1));
        case InjectionFrequency.weekly:
          return DateTime.now().add(const Duration(days: 7));
        case InjectionFrequency.biweekly:
          return DateTime.now().add(const Duration(days: 14));
        case InjectionFrequency.monthly:
          final now = DateTime.now();
          return DateTime(now.year, now.month + 1, now.day);
        case InjectionFrequency.custom:
          final interval = intervalDays ?? 14;
          return DateTime.now().add(Duration(days: interval));
        default:
          return DateTime.now().add(const Duration(days: 14));
      }
    } catch (e) {
      print('❌ Error calculating first injection date: $e');
      return null;
    }
  }

  // Запланировать уведомления для будущих уколов
  static Future<void> _scheduleFutureInjectionNotifications(
    MedicationCourse course,
    String medicationName,
    DateTime startDate,
  ) async {
    try {
      // Планируем на 2 месяца вперед
      final DateTime endDate = DateTime.now().add(const Duration(days: 60));
      DateTime nextDate = startDate;

      int notificationCount = 0;
      const int maxNotifications = 8; // Максимум 8 уведомлений

      while (nextDate.isBefore(endDate) &&
          notificationCount < maxNotifications) {
        // Пропускаем если дата в прошлом
        if (nextDate.isBefore(DateTime.now())) {
          nextDate =
              _calculateNextInjectionDate(
                nextDate,
                course.injectionFrequency,
                course.injectionIntervalDays,
              ) ??
              nextDate.add(const Duration(days: 14));
          continue;
        }

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

          // Только если дата в будущем
          if (reminderDateTime.isAfter(DateTime.now())) {
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
        }

        // Создаем уведомление в день укола
        final DateTime injectionDateTime = DateTime(
          nextDate.year,
          nextDate.month,
          nextDate.day,
          9,
          0,
        );

        // Только если дата в будущем
        if (injectionDateTime.isAfter(DateTime.now())) {
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
        }

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
    print('✅ NotificationService: Все уведомления отменены');
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
    print('✅ Мгновенное уведомление показано: $title');
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

  // Метод для проверки запланированных уведомлений
  static Future<void> listScheduledNotifications() async {
    final notifications = await AwesomeNotifications()
        .listScheduledNotifications();
    print('📋 Запланированные уведомления:');
    for (final notification in notifications) {
      print(
        '  - ID: ${notification.content?.id}, Title: ${notification.content?.title}',
      );
    }
  }

  static Future<void> scheduleAllNotificationsForCourses(
    List<MedicationCourse> courses,
    List<Medication> medications,
  ) async {
    try {
      print(
        '🔄 NotificationService: Начинаю планирование уведомлений для всех курсов',
      );

      // Сначала очищаем все старые уведомления
      await cancelAllNotifications();

      int scheduledCount = 0;

      for (final course in courses) {
        // Планируем только для активных курсов с включенными уведомлениями
        if (course.isActive && course.hasNotifications) {
          final medication = medications.firstWhereOrNull(
            (m) => m.id == course.medicationId,
          );

          if (medication == null) continue;

          // Для ТАБЛЕТОК
          if (course.isPillCourse) {
            await schedulePillNotifications(course, medication.name);
            scheduledCount++;
            print(
              '✅ Запланированы уведомления для таблеток: ${medication.name}',
            );
          }

          // Для УКОЛОВ
          if (course.isInjectionCourse) {
            await scheduleInjectionNotifications(course, medication.name);
            scheduledCount++;
            print('✅ Запланированы уведомления для уколов: ${medication.name}');
          }
        }
      }

      print('✅ Всего запланировано уведомлений для $scheduledCount курсов');

      // Для отладки выводим список запланированных уведомлений
      await listScheduledNotifications();
    } catch (e, stackTrace) {
      print('❌ Ошибка при планировании всех уведомлений: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Запланировать ежедневные уведомления для таблеток
  static Future<void> schedulePillNotifications(
    MedicationCourse course,
    String medicationName,
  ) async {
    try {
      print(
        '🔄 NotificationService: Начинаю планирование уведомлений для таблеток препарата: $medicationName',
      );

      // Отменяем старые уведомления для этого препарата
      await cancelAllNotificationsForMedication(course.medicationId);

      // Если уведомления не включены, выходим
      if (!course.hasNotifications) {
        print('⚠️ NotificationService: Уведомления для курса отключены');
        return;
      }

      // Если нет информации о количестве таблеток в день, выходим
      if (course.pillsPerDay == null || course.pillsPerDay! <= 0) {
        print('⚠️ NotificationService: Не указано количество таблеток в день');
        return;
      }

      // Время уведомлений (например: 9:00, 14:00, 20:00)
      final List<TimeOfDay> reminderTimes = [
        const TimeOfDay(hour: 9, minute: 0),
        const TimeOfDay(hour: 14, minute: 0),
        const TimeOfDay(hour: 20, minute: 0),
      ];

      // Создаем уведомления на основе pillsPerDay
      for (int i = 0; i < min(course.pillsPerDay!, reminderTimes.length); i++) {
        final time = reminderTimes[i];

        // Запланировать ежедневное уведомление
        await scheduleDailyNotification(
          id: 'pill_${course.medicationId}_$i',
          title: '💊 Время принять лекарство',
          body: 'Пора принять $medicationName',
          hour: time.hour,
          minute: time.minute,
          startDate: course.startDate,
          endDate: course.endDate,
        );
      }

      print('✅ NotificationService: Уведомления для таблеток запланированы');
    } catch (e, stackTrace) {
      print('❌ NotificationService.schedulePillNotifications(): Ошибка: $e');
      print('Stack trace: $stackTrace');
    }
  }
}
