// lib/repositories/medication_repository.dart

import 'package:intl/intl.dart';
import 'package:medication_tracker/models/medication.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medication_record.dart';

class MedicationRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Получить все записи пользователя
  Future<List<MedicationRecord>> getRecords(String userId) async {
    try {
      final response = await _client
          .from('medication_records')
          .select('*, medications!left(*)') // Используем left join
          .eq('user_id', userId)
          .order('date_time', ascending: false)
          .limit(100); // ← ОГРАНИЧИВАЕМ количество записей

      return response
          .map((item) {
            final record = MedicationRecord.fromMap(item);

            // Если есть связанный препарат
            if (item['medications'] != null && item['medications'] is Map) {
              record.medication = Medication.fromMap(item['medications']);
            }

            return record;
          })
          .toList()
          .cast<MedicationRecord>();
    } catch (e) {
      print('Error getting records: $e');
      rethrow;
    }
  }

  // Добавить запись
  Future<void> addRecord(MedicationRecord record) async {
    try {
      await _client.from('medication_records').insert(record.toMap());
    } catch (e) {
      print('Error adding record: $e');
      rethrow;
    }
  }

  // Удалить запись
  Future<void> deleteRecord(String recordId) async {
    try {
      await _client.from('medication_records').delete().eq('id', recordId);
    } catch (e) {
      print('Error deleting record: $e');
      rethrow;
    }
  }

  // Получить запись по ID
  Future<MedicationRecord?> getRecordById(String recordId) async {
    try {
      final response = await _client
          .from('medication_records')
          .select()
          .eq('id', recordId)
          .single();
      return MedicationRecord.fromMap(response);
    } catch (e) {
      print('Error getting record by id: $e');
      return null;
    }
  }

  // Подписаться на изменения в реальном времени
  RealtimeChannel getRealtimeChannel(String userId) {
    return _client
        .channel('medication_records_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'medication_records',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            // Обработка изменений
          },
        );
  }

  // Получить количество записей по дням для статистики
  Future<Map<String, int>> getRecordsByDay(String userId) async {
    try {
      final response = await _client
          .from('medication_records')
          .select('date_time')
          .eq('user_id', userId);

      final Map<String, int> result = {};

      for (final record in response) {
        final date = DateTime.parse(record['date_time'] as String);
        final dateString = DateFormat('yyyy-MM-dd').format(date);

        result.update(dateString, (value) => value + 1, ifAbsent: () => 1);
      }

      return result;
    } catch (e) {
      print('Error getting records by day: $e');
      return {};
    }
  }

  // Получить все препараты пользователя
  Future<List<Medication>> getMedications(String userId) async {
    try {
      final response = await _client
          .from('medications')
          .select()
          .eq('user_id', userId)
          .order('name', ascending: true);

      return response
          .map((item) => Medication.fromMap(item))
          .toList()
          .cast<Medication>();
    } catch (e) {
      print('Error getting medications: $e');
      rethrow;
    }
  }

  // Получить препарат по ID
  Future<Medication?> getMedicationById(String medicationId) async {
    try {
      final response = await _client
          .from('medications')
          .select()
          .eq('id', medicationId)
          .single();

      return Medication.fromMap(response);
    } catch (e) {
      print('Error getting medication by id: $e');
      return null;
    }
  }

  // Добавить препарат
  Future<Medication> addMedication(Medication medication) async {
    try {
      final response = await _client
          .from('medications')
          .insert(medication.toMap())
          .select()
          .single();

      return Medication.fromMap(response);
    } catch (e) {
      print('Error adding medication: $e');
      rethrow;
    }
  }

  // Получить препараты по типу
  Future<List<Medication>> getMedicationsByType(
    String userId,
    MedicationType type,
  ) async {
    try {
      String dbType;
      switch (type) {
        case MedicationType.pill:
          dbType = 'Таблетка';
          break;
        case MedicationType.injection:
          dbType = 'Укол';
          break;
        case MedicationType.both:
          dbType = 'Таблетка+укол';
          break;
      }

      final response = await _client
          .from('medications')
          .select()
          .eq('user_id', userId)
          .eq('type', dbType)
          .order('name', ascending: true);

      return response
          .map((item) => Medication.fromMap(item))
          .toList()
          .cast<Medication>();
    } catch (e) {
      print('Error getting medications by type: $e');
      return [];
    }
  }
}
