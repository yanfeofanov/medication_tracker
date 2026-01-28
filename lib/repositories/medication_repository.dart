// lib/repositories/medication_repository.dart

import 'package:intl/intl.dart';
import 'package:medication_tracker/models/medication.dart';
import 'package:medication_tracker/models/medication_course.dart';
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

  // Получить все курсы пользователя (НОВЫЙ МЕТОД)
  Future<List<MedicationCourse>> getAllCourses(String userId) async {
    try {
      final response = await _client
          .from('medication_courses')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      return response
          .map((item) => MedicationCourse.fromMap(item))
          .toList()
          .cast<MedicationCourse>();
    } catch (e) {
      print('Error getting all courses: $e');
      return [];
    }
  }

  // Получить курс для препарата
  Future<MedicationCourse?> getMedicationCourse(String medicationId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('medication_courses')
          .select()
          .eq('medication_id', medicationId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return MedicationCourse.fromMap(response);
    } catch (e) {
      print('Error getting medication course: $e');
      return null;
    }
  }

  // Создать или обновить курс для препарата (ИСПРАВЛЕННЫЙ МЕТОД)
  Future<MedicationCourse> saveMedicationCourse(MedicationCourse course) async {
    try {
      print(
        '💾 MedicationRepository.saveMedicationCourse(): Сохраняю курс для препарата ${course.medicationId}',
      );

      // Сначала проверяем, существует ли уже курс
      final existingCourse = await getMedicationCourse(course.medicationId);

      if (existingCourse != null) {
        // Если курс уже существует, используем его ID
        print('🔄 Обновляю существующий курс с ID: ${existingCourse.id}');

        // Создаем обновленный курс с тем же ID
        final updatedCourse = MedicationCourse(
          id: existingCourse.id,
          userId: course.userId,
          medicationId: course.medicationId,
          startDate: course.startDate,
          durationType: course.durationType,
          customEndDate: course.customEndDate,
          pillsPerDay: course.pillsPerDay,
          totalPills: course.totalPills,
          hasNotifications: course.hasNotifications,
          createdAt:
              existingCourse.createdAt, // Сохраняем оригинальную дату создания
          updatedAt: DateTime.now(),
          injectionFrequency: course.injectionFrequency,
          injectionIntervalDays: course.injectionIntervalDays,
          injectionDaysOfWeek: course.injectionDaysOfWeek,
          injectionNotifyDayBefore: course.injectionNotifyDayBefore,
        );

        print('📊 Данные для обновления: ${updatedCourse.toMap()}');

        // Используем update для обновления существующего курса
        final response = await _client
            .from('medication_courses')
            .update(updatedCourse.toMap())
            .eq('id', existingCourse.id)
            .select()
            .single();

        print('✅ Существующий курс успешно обновлен');
        return MedicationCourse.fromMap(response);
      } else {
        // Если курс не существует, создаем новый
        print('🆕 Создаю новый курс для препарата ${course.medicationId}');

        final newCourse = MedicationCourse(
          id: '',
          userId: course.userId,
          medicationId: course.medicationId,
          startDate: course.startDate,
          durationType: course.durationType,
          customEndDate: course.customEndDate,
          pillsPerDay: course.pillsPerDay,
          totalPills: course.totalPills,
          hasNotifications: course.hasNotifications,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          injectionFrequency: course.injectionFrequency,
          injectionIntervalDays: course.injectionIntervalDays,
          injectionDaysOfWeek: course.injectionDaysOfWeek,
          injectionNotifyDayBefore: course.injectionNotifyDayBefore,
        );

        print('📊 Данные для создания: ${newCourse.toMap()}');

        final response = await _client
            .from('medication_courses')
            .insert(newCourse.toMap())
            .select()
            .single();

        print('✅ Новый курс успешно создан');
        return MedicationCourse.fromMap(response);
      }
    } catch (e, stackTrace) {
      print('❌ Ошибка в MedicationRepository.saveMedicationCourse(): $e');
      print('Stack trace: $stackTrace');

      // Если возникает ошибка уникальности, пробуем альтернативный подход
      if (e.toString().contains('23505') ||
          e.toString().contains('duplicate')) {
        print(
          '🔄 Пробую альтернативный метод сохранения из-за ошибки уникальности...',
        );
        return await _saveMedicationCourseAlternative(course);
      }

      // Если возникает ошибка check constraint
      if (e.toString().contains('23514')) {
        print('🔄 Пробую сохранить курс с очищенными полями для уколов...');
        return await _saveMedicationCourseWithoutInjectionFields(course);
      }

      rethrow;
    }
  }

  // Метод сохранения курса без полей для уколов (для таблеток)
  Future<MedicationCourse> _saveMedicationCourseWithoutInjectionFields(
    MedicationCourse course,
  ) async {
    try {
      print(
        '🔄 _saveMedicationCourseWithoutInjectionFields: Сохраняю курс без полей уколов',
      );

      // Создаем курс без полей для уколов
      final cleanCourse = MedicationCourse(
        id: course.id,
        userId: course.userId,
        medicationId: course.medicationId,
        startDate: course.startDate,
        durationType: course.durationType,
        customEndDate: course.customEndDate,
        pillsPerDay: course.pillsPerDay,
        totalPills: course.totalPills,
        hasNotifications: course.hasNotifications,
        createdAt: course.createdAt,
        updatedAt: DateTime.now(),
        // Оставляем null для полей уколов
        injectionFrequency: null,
        injectionIntervalDays: null,
        injectionDaysOfWeek: null,
        injectionNotifyDayBefore: null,
      );

      // Проверяем существующий курс
      final existingCourse = await getMedicationCourse(course.medicationId);

      if (existingCourse != null) {
        // Обновляем существующий
        final response = await _client
            .from('medication_courses')
            .update(cleanCourse.toMap())
            .eq('id', existingCourse.id)
            .select()
            .single();

        print('✅ Курс успешно обновлен без полей уколов');
        return MedicationCourse.fromMap(response);
      } else {
        // Создаем новый
        final response = await _client
            .from('medication_courses')
            .insert(cleanCourse.toMap())
            .select()
            .single();

        print('✅ Курс успешно создан без полей уколов');
        return MedicationCourse.fromMap(response);
      }
    } catch (e) {
      print('❌ Ошибка в _saveMedicationCourseWithoutInjectionFields: $e');
      rethrow;
    }
  }

  // Альтернативный метод сохранения курса
  Future<MedicationCourse> _saveMedicationCourseAlternative(
    MedicationCourse course,
  ) async {
    try {
      print(
        '🔄 _saveMedicationCourseAlternative: Пробую сохранить курс альтернативным методом',
      );

      // Получаем user_id
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Пользователь не авторизован');
      }

      // Сначала пытаемся удалить существующий курс
      try {
        await _client
            .from('medication_courses')
            .delete()
            .eq('medication_id', course.medicationId)
            .eq('user_id', userId);

        print('🗑️ Удален существующий курс перед созданием нового');
      } catch (deleteError) {
        print('ℹ️ Не удалось удалить существующий курс: $deleteError');
        // Продолжаем в любом случае
      }

      // Создаем новый курс с правильными полями
      final newCourse = MedicationCourse(
        id: '',
        userId: course.userId,
        medicationId: course.medicationId,
        startDate: course.startDate,
        durationType: course.durationType,
        customEndDate: course.customEndDate,
        pillsPerDay: course.pillsPerDay,
        totalPills: course.totalPills,
        hasNotifications: course.hasNotifications,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        injectionFrequency: course.injectionFrequency,
        injectionIntervalDays: course.injectionIntervalDays,
        injectionDaysOfWeek: course.injectionDaysOfWeek,
        injectionNotifyDayBefore: course.injectionNotifyDayBefore,
      );

      final response = await _client
          .from('medication_courses')
          .insert(newCourse.toMap())
          .select()
          .single();

      print('✅ Курс успешно сохранен альтернативным методом');
      return MedicationCourse.fromMap(response);
    } catch (e) {
      print('❌ Ошибка в _saveMedicationCourseAlternative: $e');
      rethrow;
    }
  }

  // Удалить курс для препарата
  Future<void> deleteMedicationCourse(String courseId) async {
    try {
      await _client.from('medication_courses').delete().eq('id', courseId);
    } catch (e) {
      print('Error deleting medication course: $e');
      rethrow;
    }
  }

  // Удалить курс по medicationId
  Future<void> deleteCourseByMedicationId(String medicationId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client
          .from('medication_courses')
          .delete()
          .eq('medication_id', medicationId)
          .eq('user_id', userId);
    } catch (e) {
      print('Error deleting course by medication id: $e');
      rethrow;
    }
  }

  // Получить активные курсы
  Future<List<MedicationCourse>> getActiveCourses(String userId) async {
    try {
      final allCourses = await getAllCourses(userId);
      return allCourses.where((course) => course.isActive).toList();
    } catch (e) {
      print('Error getting active courses: $e');
      return [];
    }
  }
}
