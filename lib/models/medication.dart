// lib/models/medication.dart
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

  Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.dosage,
    this.description,
    required this.createdAt,
    required this.updatedAt,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'type': type.toDbString(),
      'dosage': dosage,
      'description': description,
    };
  }

  // Проверка, является ли препарат таблеткой
  bool get isPill =>
      type == MedicationDbType.pill || type == MedicationDbType.both;

  // Проверка, является ли препарат уколом
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
