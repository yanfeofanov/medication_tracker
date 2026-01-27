// lib/models/medication.dart

import 'package:medication_tracker/models/medication_course.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum MedicationDbType {
  pill('Таблетка'),
  injection('Укол'),
  both('Таблетка+укол');

  final String displayName;
  const MedicationDbType(this.displayName);

  String toDbString() => displayName;

  static MedicationDbType fromDbString(String value) {
    return MedicationDbType.values.firstWhere(
      (type) => type.displayName == value,
      orElse: () => MedicationDbType.pill,
    );
  }
}

class Medication {
  final String id;
  final String userId;
  final String name;
  final MedicationDbType type;
  final String? dosage;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Новые поля для настройки курса
  final CourseDurationType? defaultDurationType;
  final int? defaultPillsPerDay;
  final int? defaultTotalPills;
  final bool? defaultHasNotifications;

  Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.dosage,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.defaultDurationType,
    this.defaultPillsPerDay = 1,
    this.defaultTotalPills,
    this.defaultHasNotifications = true,
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      type: MedicationDbType.fromDbString(map['type'] as String),
      dosage: map['dosage'] as String?,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      defaultDurationType: map['default_duration_type'] != null
          ? _durationTypeFromString(map['default_duration_type'] as String)
          : null,
      defaultPillsPerDay: map['default_pills_per_day'] as int? ?? 1,
      defaultTotalPills: map['default_total_pills'] as int?,
      defaultHasNotifications:
          map['default_has_notifications'] as bool? ?? true,
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

  static String _durationTypeToString(CourseDurationType? type) {
    if (type == null) return '';
    return type.toString().split('.').last;
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'type': type.toDbString(),
      'dosage': dosage,
      'description': description,
      'default_duration_type': _durationTypeToString(defaultDurationType),
      'default_pills_per_day': defaultPillsPerDay,
      'default_total_pills': defaultTotalPills,
      'default_has_notifications': defaultHasNotifications,
    };
  }

  bool get isPill =>
      type == MedicationDbType.pill || type == MedicationDbType.both;

  bool get isInjection =>
      type == MedicationDbType.injection || type == MedicationDbType.both;

  String get displayType {
    switch (type) {
      case MedicationDbType.pill:
        return '💊 Таблетка';
      case MedicationDbType.injection:
        return '💉 Укол';
      case MedicationDbType.both:
        return '💊💉 Таблетка+укол';
    }
  }
}
