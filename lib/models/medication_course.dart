// lib/models/medication_course.dart
import 'package:intl/intl.dart';
import 'package:medication_tracker/models/medication_record.dart';

enum CourseDurationType {
  week('Неделя'),
  twoWeeks('Две недели'),
  month('Месяц'),
  threeMonths('3 месяца'),
  sixMonths('6 месяцев'),
  year('Год'),
  custom('Выбрать дату'),
  lifetime('Пожизненно');

  final String displayName;
  const CourseDurationType(this.displayName);
}

// Новый enum для частоты уколов
enum InjectionFrequency {
  daily('Ежедневно'),
  weekly('Раз в неделю'),
  biweekly('Раз в две недели'),
  monthly('Раз в месяц'),
  custom('Произвольная частота');

  final String displayName;
  const InjectionFrequency(this.displayName);
}

class MedicationCourse {
  final String id;
  final String userId;
  final String medicationId;
  final DateTime startDate;
  final CourseDurationType durationType;
  final DateTime? customEndDate;
  final int? pillsPerDay; // Для таблеток
  final int totalPills; // Общее количество таблеток
  final bool hasNotifications;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Новые поля для уколов
  final InjectionFrequency? injectionFrequency;
  final int? injectionIntervalDays; // Интервал в днях для кастомной частоты
  final List<String>? injectionDaysOfWeek; // Дни недели для уколов
  final bool? injectionNotifyDayBefore; // Уведомлять за день до

  MedicationCourse({
    required this.id,
    required this.userId,
    required this.medicationId,
    required this.startDate,
    required this.durationType,
    this.customEndDate,
    this.pillsPerDay = 1,
    this.totalPills = 0,
    this.hasNotifications = true,
    required this.createdAt,
    required this.updatedAt,

    // Новые параметры
    this.injectionFrequency,
    this.injectionIntervalDays,
    this.injectionDaysOfWeek,
    this.injectionNotifyDayBefore = true,
  });

  factory MedicationCourse.fromMap(Map<String, dynamic> map) {
    return MedicationCourse(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      medicationId: map['medication_id'] as String,
      startDate: DateTime.parse(map['start_date'] as String).toLocal(),
      durationType: _durationTypeFromString(map['duration_type'] as String),
      customEndDate: map['custom_end_date'] != null
          ? DateTime.parse(map['custom_end_date'] as String).toLocal()
          : null,
      pillsPerDay: map['pills_per_day'] as int? ?? 1,
      totalPills: map['total_pills'] as int? ?? 0,
      hasNotifications: map['has_notifications'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),

      // Новые поля
      injectionFrequency: map['injection_frequency'] != null
          ? _injectionFrequencyFromString(map['injection_frequency'] as String)
          : null,
      injectionIntervalDays: map['injection_interval_days'] as int?,
      injectionDaysOfWeek: map['injection_days_of_week'] != null
          ? (map['injection_days_of_week'] as String).split(',')
          : null,
      injectionNotifyDayBefore:
          map['injection_notify_day_before'] as bool? ?? true,
    );
  }

  static CourseDurationType _durationTypeFromString(String value) {
    switch (value) {
      case 'week':
        return CourseDurationType.week;
      case 'twoWeeks':
        return CourseDurationType.twoWeeks;
      case 'month':
        return CourseDurationType.month;
      case 'threeMonths':
        return CourseDurationType.threeMonths;
      case 'sixMonths':
        return CourseDurationType.sixMonths;
      case 'year':
        return CourseDurationType.year;
      case 'custom':
        return CourseDurationType.custom;
      case 'lifetime':
        return CourseDurationType.lifetime;
      default:
        return CourseDurationType.month;
    }
  }

  static String _durationTypeToString(CourseDurationType type) {
    return type.toString().split('.').last;
  }

  static InjectionFrequency _injectionFrequencyFromString(String value) {
    switch (value) {
      case 'daily':
        return InjectionFrequency.daily;
      case 'weekly':
        return InjectionFrequency.weekly;
      case 'biweekly':
        return InjectionFrequency.biweekly;
      case 'monthly':
        return InjectionFrequency.monthly;
      case 'custom':
        return InjectionFrequency.custom;
      default:
        return InjectionFrequency.biweekly;
    }
  }

  static String _injectionFrequencyToString(InjectionFrequency? frequency) {
    if (frequency == null) return '';
    return frequency.toString().split('.').last;
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'medication_id': medicationId,
      'start_date': startDate.toUtc().toIso8601String(),
      'duration_type': _durationTypeToString(durationType),
      'custom_end_date': customEndDate?.toUtc().toIso8601String(),
      'pills_per_day': pillsPerDay,
      'total_pills': totalPills,
      'has_notifications': hasNotifications,

      // Новые поля
      'injection_frequency': _injectionFrequencyToString(injectionFrequency),
      'injection_interval_days': injectionIntervalDays,
      'injection_days_of_week': injectionDaysOfWeek?.join(','),
      'injection_notify_day_before': injectionNotifyDayBefore,
    };
  }

  // Рассчитать дату окончания курса
  DateTime? get endDate {
    switch (durationType) {
      case CourseDurationType.week:
        return startDate.add(const Duration(days: 7));
      case CourseDurationType.twoWeeks:
        return startDate.add(const Duration(days: 14));
      case CourseDurationType.month:
        return DateTime(startDate.year, startDate.month + 1, startDate.day);
      case CourseDurationType.threeMonths:
        return DateTime(startDate.year, startDate.month + 3, startDate.day);
      case CourseDurationType.sixMonths:
        return DateTime(startDate.year, startDate.month + 6, startDate.day);
      case CourseDurationType.year:
        return DateTime(startDate.year + 1, startDate.month, startDate.day);
      case CourseDurationType.custom:
        return customEndDate;
      case CourseDurationType.lifetime:
        return null;
    }
  }

  // Рассчитать сколько дней осталось
  int? get daysLeft {
    if (durationType == CourseDurationType.lifetime) return null;
    final end = endDate;
    if (end == null) return null;
    final now = DateTime.now();
    final difference = end.difference(now).inDays;
    return difference > 0 ? difference : 0;
  }

  // Проверить, активен ли курс
  bool get isActive {
    if (durationType == CourseDurationType.lifetime) return true;
    final end = endDate;
    if (end == null) return false;
    return DateTime.now().isBefore(end);
  }

  // Рассчитать оставшееся количество таблеток
  int calculatePillsLeft(List<MedicationRecord> records) {
    if (durationType == CourseDurationType.lifetime) {
      // Для пожизненного приема считаем общее количество принятых таблеток
      final pillsTaken = records
          .where((record) => record.medicationId == medicationId)
          .where(
            (record) =>
                record.medicationType == MedicationType.pill ||
                record.medicationType == MedicationType.both,
          )
          .length;

      // Если указано общее количество таблеток
      if (totalPills > 0) {
        return totalPills - pillsTaken;
      }
      return 0;
    }

    // Для курсов с конечной датой
    final end = endDate;
    if (end == null || pillsPerDay == null) return 0;
    final now = DateTime.now();
    if (now.isAfter(end)) return 0;

    // Рассчитываем сколько дней осталось
    final daysLeft = end.difference(now).inDays;

    // Учитываем уже принятые сегодня таблетки
    final today = DateFormat('dd.MM.yyyy').format(now);
    final pillsTakenToday = records
        .where((record) => record.medicationId == medicationId)
        .where(
          (record) =>
              record.medicationType == MedicationType.pill ||
              record.medicationType == MedicationType.both,
        )
        .where((record) => record.dateOnly == today)
        .length;

    final pillsForToday = pillsTakenToday >= pillsPerDay! ? 0 : 1;

    // Рассчитываем оставшиеся таблетки
    final remainingPills = (daysLeft + pillsForToday) * pillsPerDay!;

    // Вычитаем уже принятые таблетки
    final allPillsTaken = records
        .where((record) => record.medicationId == medicationId)
        .where(
          (record) =>
              record.medicationType == MedicationType.pill ||
              record.medicationType == MedicationType.both,
        )
        .length;

    final result = remainingPills - allPillsTaken;
    return result < 0 ? 0 : result;
  }

  // Рассчитать дату следующего укола
  DateTime? getNextInjectionDate(List<MedicationRecord> records) {
    if (injectionFrequency == null) return null;

    final lastInjection =
        records
            .where((record) => record.medicationId == medicationId)
            .where(
              (record) =>
                  record.medicationType == MedicationType.injection ||
                  record.medicationType == MedicationType.both,
            )
            .toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    if (lastInjection.isEmpty) {
      // Если уколов не было, следующий - сегодня
      return DateTime.now();
    }

    if (lastInjection.isEmpty) {
      // Если уколов не было, следующий - сегодня + интервал
      return _calculateFirstInjectionDate();
    }

    final lastDate = lastInjection.first.dateTime;

    // Рассчитываем следующую дату на основе частоты
    switch (injectionFrequency!) {
      case InjectionFrequency.daily:
        return lastDate.add(const Duration(days: 1));
      case InjectionFrequency.weekly:
        return lastDate.add(const Duration(days: 7));
      case InjectionFrequency.biweekly:
        return lastDate.add(const Duration(days: 14));
      case InjectionFrequency.monthly:
        return DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
      case InjectionFrequency.custom:
        final interval = injectionIntervalDays ?? 14;
        return lastDate.add(Duration(days: interval));
    }
  }

  DateTime _calculateFirstInjectionDate() {
    switch (injectionFrequency) {
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
        final interval = injectionIntervalDays ?? 14;
        return DateTime.now().add(Duration(days: interval));
      default:
        return DateTime.now().add(const Duration(days: 14));
    }
  }

  // Получить информацию для отображения
  String get displayInfo {
    if (durationType == CourseDurationType.lifetime) {
      return 'Пожизненно';
    }

    final end = endDate;
    if (end == null) return 'Без срока';

    return 'До ${DateFormat('dd.MM.yyyy').format(end)}';
  }

  // Получить информацию о частоте уколов
  String get injectionInfo {
    if (injectionFrequency == null) return '';

    switch (injectionFrequency!) {
      case InjectionFrequency.daily:
        return 'Ежедневно';
      case InjectionFrequency.weekly:
        return 'Раз в неделю';
      case InjectionFrequency.biweekly:
        return 'Раз в две недели';
      case InjectionFrequency.monthly:
        return 'Раз в месяц';
      case InjectionFrequency.custom:
        return 'Каждые ${injectionIntervalDays ?? 14} дней';
    }
  }
}
