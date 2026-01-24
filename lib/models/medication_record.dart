// lib/models/medication_record.dart

import 'package:intl/intl.dart';

enum MedicationType {
  pill('Таблетка', '💊'),
  injection('Укол', '💉'),
  both('Таблетка+укол', '💊💉');

  final String displayName;
  final String emoji;

  const MedicationType(this.displayName, this.emoji);

  String toDbString() => displayName;

  static MedicationType fromDbString(String value) {
    return MedicationType.values.firstWhere(
      (type) => type.displayName == value,
      orElse: () => MedicationType.pill,
    );
  }
}

enum InjectionSite {
  rightLeg('Правая нога', '🦵'),
  leftLeg('Левая нога', '🦵'),
  rightArm('Правая рука', '💪'),
  leftArm('Левая рука', '💪'),
  stomach('Живот', '👕');

  final String displayName;
  final String emoji;

  const InjectionSite(this.displayName, this.emoji);

  String toDbString() => displayName;

  static InjectionSite? fromDbString(String? value) {
    if (value == null) return null;
    return InjectionSite.values.firstWhere(
      (site) => site.displayName == value,
      orElse: () => InjectionSite.rightLeg,
    );
  }
}

class MedicationRecord {
  final String id;
  final String userId;
  final MedicationType medicationType;
  final InjectionSite? injectionSite;
  final DateTime dateTime;
  final DateTime createdAt;

  MedicationRecord({
    required this.id,
    required this.userId,
    required this.medicationType,
    this.injectionSite,
    required this.dateTime,
    required this.createdAt,
  });

  factory MedicationRecord.fromMap(Map<String, dynamic> map) {
    return MedicationRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      medicationType: MedicationType.fromDbString(
        map['medication_type'] as String,
      ),
      injectionSite: InjectionSite.fromDbString(
        map['injection_site'] as String?,
      ),
      dateTime: DateTime.parse(map['date_time'] as String).toLocal(),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'medication_type': medicationType.toDbString(),
      'injection_site': injectionSite?.toDbString(),
      'date_time': dateTime.toUtc().toIso8601String(),
    };
  }

  String get formattedDate => DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
  String get timeOnly => DateFormat('HH:mm').format(dateTime);
  String get dateOnly => DateFormat('dd.MM.yyyy').format(dateTime);

  // Проверка: можно ли принимать таблетку сегодня
  bool get canTakePillToday {
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
    return dateOnly != today;
  }

  // Проверка: можно ли делать укол сегодня
  bool get canTakeInjectionToday {
    final today = DateTime.now();
    final daysSinceLastInjection = today.difference(dateTime).inDays;
    return daysSinceLastInjection >= 14;
  }

  // Получить дату следующего укола (через 2 недели)
  DateTime get nextInjectionDate => dateTime.add(const Duration(days: 14));

  // Форматированная дата следующего укола
  String get formattedNextInjectionDate =>
      DateFormat('dd.MM.yyyy').format(nextInjectionDate);

  // Осталось дней до следующего укола
  int get daysUntilNextInjection {
    final now = DateTime.now();
    final difference = nextInjectionDate.difference(now);
    return difference.inDays;
  }

  String get displayInfo {
    if (medicationType == MedicationType.pill) {
      return '$emoji $formattedDate';
    } else if (medicationType == MedicationType.injection) {
      return '$emoji ${injectionSite?.emoji} $formattedDate';
    } else {
      return '$emoji ${injectionSite?.emoji} $formattedDate';
    }
  }

  String get emoji => medicationType.emoji;

  // Статический метод для подсчета количества уколов
  static int getInjectionCount(List<MedicationRecord> records) {
    return records.where((record) {
      return record.medicationType == MedicationType.injection ||
          record.medicationType == MedicationType.both;
    }).length;
  }

  // Статический метод для подсчета количества таблеток
  static int getPillCount(List<MedicationRecord> records) {
    return records.where((record) {
      return record.medicationType == MedicationType.pill ||
          record.medicationType == MedicationType.both;
    }).length;
  }
}

// Класс для отслеживания прогресса
class MedicationProgress {
  static final DateTime pillsEndDate = DateTime(2026, 5, 20);

  // Рассчитать оставшееся количество таблеток
  static int calculatePillsLeft(List<MedicationRecord> records) {
    final today = DateTime.now();

    // Если текущая дата позже даты окончания
    if (today.isAfter(pillsEndDate)) {
      return 0;
    }

    // Вычисляем сколько дней осталось принимать таблетки
    final daysLeft = pillsEndDate.difference(today).inDays;

    // Вычитаем уже принятые сегодня таблетки
    final todayPills = records
        .where((record) {
          return record.medicationType == MedicationType.pill ||
              record.medicationType == MedicationType.both;
        })
        .where((record) {
          return record.dateOnly == DateFormat('dd.MM.yyyy').format(today);
        })
        .length;

    // Предполагаем, что в день нужно принимать 1 таблетку
    // Исключаем сегодняшнюю, если уже приняли
    final pillsLeft = daysLeft + (todayPills > 0 ? 0 : 1);
    return pillsLeft < 0 ? 0 : pillsLeft;
  }

  // Получить ближайшую дату следующего укола
  static DateTime? getNextInjectionDate(List<MedicationRecord> records) {
    final injectionRecords = records.where((record) {
      return record.medicationType == MedicationType.injection ||
          record.medicationType == MedicationType.both;
    }).toList();

    if (injectionRecords.isEmpty) return null;

    // Сортируем по дате (последний укол первый)
    injectionRecords.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // Берем последний укол и добавляем 2 недели
    return injectionRecords.first.nextInjectionDate;
  }

  // Получить прогресс по таблеткам в процентах
  static double getPillsProgress(List<MedicationRecord> records) {
    final totalDays = DateTime(
      2025,
      1,
      1,
    ).difference(pillsEndDate).inDays.abs();

    final daysPassed = DateTime.now().difference(DateTime(2025, 1, 12)).inDays;

    if (daysPassed >= totalDays) return 1.0;
    if (daysPassed <= 0) return 0.0;

    final progress = daysPassed / totalDays;
    return progress > 1.0 ? 1.0 : progress;
  }

  // Получить статус для отображения
  static String getStatusMessage(List<MedicationRecord> records) {
    final pillsLeft = calculatePillsLeft(records);
    final nextInjection = getNextInjectionDate(records);

    if (pillsLeft > 0 && nextInjection != null) {
      return 'Таблетки: $pillsLeft осталось | Следующий укол: ${DateFormat('dd.MM.yyyy').format(nextInjection)}';
    } else if (pillsLeft > 0) {
      return 'Осталось таблеток: $pillsLeft';
    } else if (nextInjection != null) {
      return 'Следующий укол: ${DateFormat('dd.MM.yyyy').format(nextInjection)}';
    }

    return 'Нет активных лекарств';
  }
}
