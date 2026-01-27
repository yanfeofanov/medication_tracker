// lib/services/local_storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class LocalStorageService {
  static const String _nextInjectionKey = 'next_injection_date';
  static const String _injectionIntervalKey = 'injection_interval_days';

  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  // Сохранить дату следующего укола
  static Future<void> saveNextInjectionDate(DateTime date) async {
    final prefs = await _prefs;
    await prefs.setString(_nextInjectionKey, date.toIso8601String());
  }

  // Получить дату следующего укола
  static Future<DateTime?> getNextInjectionDate() async {
    final prefs = await _prefs;
    final dateString = prefs.getString(_nextInjectionKey);
    if (dateString == null) return null;

    try {
      return DateTime.parse(dateString).toLocal();
    } catch (e) {
      return null;
    }
  }

  // Сохранить интервал между уколами
  static Future<void> saveInjectionInterval(int days) async {
    final prefs = await _prefs;
    await prefs.setInt(_injectionIntervalKey, days);
  }

  // Получить интервал между уколами
  static Future<int> getInjectionInterval() async {
    final prefs = await _prefs;
    return prefs.getInt(_injectionIntervalKey) ?? 14; // По умолчанию 14 дней
  }

  // Очистить данные об уколах
  static Future<void> clearInjectionData() async {
    final prefs = await _prefs;
    await prefs.remove(_nextInjectionKey);
    await prefs.remove(_injectionIntervalKey);
  }

  // Получить оставшееся количество дней до следующего укола
  static Future<int> getDaysUntilNextInjection() async {
    final nextInjection = await getNextInjectionDate();
    if (nextInjection == null) return -1;

    final now = DateTime.now();
    final difference = nextInjection.difference(now).inDays;
    return difference;
  }

  // Проверить, нужно ли делать укол сегодня
  static Future<bool> shouldTakeInjectionToday() async {
    final nextInjection = await getNextInjectionDate();
    if (nextInjection == null) return true;

    final now = DateTime.now();
    return now.isAfter(nextInjection) ||
        DateFormat('yyyy-MM-dd').format(now) ==
            DateFormat('yyyy-MM-dd').format(nextInjection);
  }

  // Обновить дату следующего укола (при добавлении нового укола)
  static Future<void> updateNextInjectionDate() async {
    final interval = await getInjectionInterval();
    final nextDate = DateTime.now().add(Duration(days: interval));
    await saveNextInjectionDate(nextDate);
  }

  // Проверить, прошло ли достаточно времени с последнего укола
  static Future<bool> canTakeInjectionNow() async {
    final nextInjection = await getNextInjectionDate();
    if (nextInjection == null) return true;

    final now = DateTime.now();
    return now.isAfter(nextInjection);
  }

  // Получить отформатированную дату следующего укола
  static Future<String> getFormattedNextInjectionDate() async {
    final date = await getNextInjectionDate();
    if (date == null) return 'Не установлено';

    final now = DateTime.now();
    if (date.isBefore(now)) {
      return 'Пора сделать укол!';
    }

    final daysLeft = date.difference(now).inDays;
    if (daysLeft == 0) {
      return 'Сегодня';
    } else if (daysLeft == 1) {
      return 'Завтра (${DateFormat('dd.MM.yyyy').format(date)})';
    } else {
      return 'Через $daysLeft дней (${DateFormat('dd.MM.yyyy').format(date)})';
    }
  }
}
