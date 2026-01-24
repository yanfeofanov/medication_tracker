// lib/repositories/medication_repository.dart

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medication_record.dart';

class MedicationRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Получить все записи пользователя
  Future<List<MedicationRecord>> getRecords(String userId) async {
    try {
      final response = await _client
          .from('medication_records')
          .select()
          .eq('user_id', userId)
          .order('date_time', ascending: false);

      return response
          .map((item) => MedicationRecord.fromMap(item))
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
}
