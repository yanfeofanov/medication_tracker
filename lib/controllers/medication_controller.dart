// lib/controllers/medication_controller.dart

import 'dart:developer' as developer;

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:medication_tracker/models/medication_course.dart';
import 'package:medication_tracker/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../models/medication_record.dart';
import '../models/medication.dart';
import '../repositories/medication_repository.dart';
import '../services/supabase_service.dart';

class MedicationController extends GetxController {
  final MedicationRepository _repository = MedicationRepository();

  // Observable список записей
  final RxList<MedicationRecord> records = <MedicationRecord>[].obs;

  // Observable список препаратов
  final RxList<Medication> medications = <Medication>[].obs;

  // Observable список курсов
  final RxList<MedicationCourse> courses = <MedicationCourse>[].obs;

  // Observable переменные для формы
  final Rx<MedicationType> selectedType = MedicationType.pill.obs;
  final Rx<InjectionSite?> selectedInjectionSite = Rx<InjectionSite?>(null);
  final Rx<Medication?> selectedMedication = Rx<Medication?>(null);

  // Observable флаг загрузки
  final RxBool isLoading = false.obs;

  // Observable переменные для отслеживания прогресса
  final RxInt _pillsLeft = 0.obs;
  final Rx<DateTime?> _nextInjectionDate = Rx<DateTime?>(null);
  final RxString _statusMessage = ''.obs;
  final RxDouble _pillsProgress = 0.0.obs;

  // Геттеры для доступа к данным прогресса
  int get pillsLeft => _pillsLeft.value;
  DateTime? get nextInjectionDate => _nextInjectionDate.value;
  String get statusMessage => _statusMessage.value;
  double get pillsProgress => _pillsProgress.value;

  // Геттер для количества уколов
  int get injectionCount => MedicationRecord.getInjectionCount(records);

  // Геттер для прогресса уколов
  String get injectionProgress {
    const totalInjections = 1000; // Предполагаемый курс
    final progress = injectionCount / totalInjections;
    return '$injectionCount/$totalInjections (${(progress * 100).toStringAsFixed(0)}%)';
  }

  // Получить отформатированную дату следующего укола
  String get formattedNextInjectionDate {
    final date = _nextInjectionDate.value;
    if (date == null) return 'Нет данных';
    return DateFormat('dd.MM.yyyy').format(date);
  }

  // Получить оставшееся количество дней до следующего укола
  int get daysUntilNextInjection {
    final date = _nextInjectionDate.value;
    if (date == null) return -1;
    final now = DateTime.now();
    final difference = date.difference(now);
    return difference.inDays;
  }

  // Канал для обновлений в реальном времени
  RealtimeChannel? _channel;

  @override
  void onInit() {
    print('🎬 MedicationController.onInit(): Инициализация контроллера');
    super.onInit();
    _loadData();
  }

  @override
  void onClose() {
    print('🛑 MedicationController.onClose(): Закрытие контроллера');
    _disposeChannel();
    super.onClose();
  }

  Future<void> _loadData() async {
    print('🔄 MedicationController._loadData(): Начинаю загрузку данных');
    try {
      await fetchRecords();
      await fetchMedications();
      await fetchCourses(); // Добавляем загрузку курсов
      _setupRealtimeUpdates();
      _updateProgress(); // Обновляем прогресс после загрузки всех данных
      print('✅ MedicationController._loadData(): Данные успешно загружены');
    } catch (e, stackTrace) {
      print('❌ MedicationController._loadData(): ОШИБКА загрузки данных: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _setupRealtimeUpdates() {
    print(
      '📡 MedicationController._setupRealtimeUpdates(): Настройка realtime обновлений',
    );
    final userId = SupabaseService.userId;
    if (userId == null || userId.isEmpty) {
      print(
        '⚠️ MedicationController._setupRealtimeUpdates(): UserID пустой, пропускаю настройку',
      );
      return;
    }
    print('👤 MedicationController._setupRealtimeUpdates(): UserID: $userId');

    // Очищаем старый канал если есть
    _disposeChannel();

    try {
      _channel = _repository.getRealtimeChannel(userId);
      _channel
          ?.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'medication_records',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              print('🔄 MedicationController: Получено realtime обновление');
              print(
                '📊 MedicationController: Тип события: ${payload.eventType}',
              );
              // Обновляем данные при изменениях
              fetchRecords();
            },
          )
          .subscribe();

      print(
        '✅ MedicationController._setupRealtimeUpdates(): Realtime обновления настроены',
      );
    } catch (e, stackTrace) {
      print(
        '❌ MedicationController._setupRealtimeUpdates(): ОШИБКА настройки realtime: $e',
      );
      print('Stack trace: $stackTrace');
    }
  }

  void _disposeChannel() {
    if (_channel != null) {
      print(
        '🔌 MedicationController._disposeChannel(): Отключаю realtime канал',
      );
      try {
        _channel?.unsubscribe();
        Supabase.instance.client.removeChannel(_channel!);
        print('✅ MedicationController._disposeChannel(): Канал отключен');
      } catch (e) {
        print(
          '⚠️ MedicationController._disposeChannel(): Ошибка при отключении канала: $e',
        );
      }
      _channel = null;
    }
  }

  // Загрузить курсы лечения пользователя
  Future<void> fetchCourses() async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null || userId.isEmpty) {
        courses.clear();
        return;
      }

      // Используем новый метод репозитория
      final fetchedCourses = await _repository.getAllCourses(userId);
      courses.assignAll(fetchedCourses);

      print(
        '✅ MedicationController.fetchCourses(): Загружено ${fetchedCourses.length} курсов',
      );
    } catch (e) {
      print('❌ MedicationController.fetchCourses(): Ошибка: $e');
    }
  }

  // Получить курс для препарата
  Future<MedicationCourse?> getCourseForMedication(String medicationId) async {
    try {
      return await _repository.getMedicationCourse(medicationId);
    } catch (e) {
      print('Error getting course for medication: $e');
      return null;
    }
  }

  // Получить следующую дату укола для препарата
  DateTime? getNextInjectionForMedication(String medicationId) {
    try {
      final course = courses.firstWhereOrNull(
        (c) => c.medicationId == medicationId,
      );

      if (course == null) return null;

      final medicationRecords = records
          .where((r) => r.medicationId == medicationId)
          .toList();

      return course.getNextInjectionDate(medicationRecords);
    } catch (e) {
      print('Error getting next injection: $e');
      return null;
    }
  }

  // Создать курс для препарата
  Future<void> createMedicationCourse({
    required String medicationId,
    required CourseDurationType durationType,
    DateTime? customEndDate,
    int pillsPerDay = 1,
    int totalPills = 0,
    bool hasNotifications = true,
    // Новые параметры для уколов
    InjectionFrequency? injectionFrequency,
    int? injectionIntervalDays,
    bool injectionNotifyDayBefore = true,
  }) async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) {
        Get.snackbar('Ошибка', 'Пользователь не авторизован');
        return;
      }

      final medication = medications.firstWhereOrNull(
        (m) => m.id == medicationId,
      );

      if (medication == null) {
        Get.snackbar('Ошибка', 'Препарат не найден');
        return;
      }

      // Сначала получаем существующий курс
      final existingCourse = await _repository.getMedicationCourse(
        medicationId,
      );

      // Сохраняем оригинальную дату начала или используем текущую
      DateTime startDate = existingCourse?.startDate ?? DateTime.now();

      final course = MedicationCourse(
        id: existingCourse?.id ?? '', // Используем существующий ID или пустой
        userId: userId,
        medicationId: medicationId,
        startDate: startDate,
        durationType: durationType,
        customEndDate: customEndDate,
        pillsPerDay:
            (medication.type == MedicationDbType.pill ||
                medication.type == MedicationDbType.both)
            ? pillsPerDay
            : null,
        totalPills: totalPills,
        hasNotifications: hasNotifications,
        createdAt: existingCourse?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        // Новые параметры
        injectionFrequency: injectionFrequency,
        injectionIntervalDays: injectionIntervalDays,
        injectionNotifyDayBefore: injectionNotifyDayBefore,
      );

      print('💾 MedicationController: Сохраняю курс для ${medication.name}');

      final savedCourse = await _repository.saveMedicationCourse(course);

      // Обновляем локальный список курсов
      courses.removeWhere((c) => c.medicationId == medicationId);
      courses.add(savedCourse);

      // Обновляем прогресс
      _updateProgress();

      // Если включены уведомления, создаем их
      if (hasNotifications) {
        if (medication.type == MedicationDbType.pill ||
            medication.type == MedicationDbType.both) {
          await _setupMedicationNotifications(savedCourse);
        }

        if (medication.type == MedicationDbType.injection ||
            medication.type == MedicationDbType.both) {
          await NotificationService.scheduleInjectionNotifications(
            savedCourse,
            medication.name,
          );
        }
      }

      Get.snackbar(
        '✅ Успешно',
        existingCourse != null
            ? 'Курс лечения обновлен'
            : 'Курс лечения настроен',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e, stackTrace) {
      print('❌ Error creating medication course: $e');
      print('Stack trace: $stackTrace');

      Get.snackbar(
        '❌ Ошибка',
        'Не удалось сохранить курс. Ошибка: ${e.toString().contains('23505') ? 'Курс уже существует' : e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  // Обновить курс после сохранения
  Future<void> updateCourseAfterSave(String medicationId) async {
    try {
      // Обновляем курс из базы
      final course = await _repository.getMedicationCourse(medicationId);
      if (course != null) {
        // Удаляем старый курс если есть
        courses.removeWhere((c) => c.medicationId == medicationId);
        courses.add(course);

        // Обновляем прогресс
        _updateProgress();

        print('✅ MedicationController: Курс для $medicationId обновлен');
      }
    } catch (e) {
      print('Error updating course: $e');
    }
  }

  // Настройка уведомлений для курса
  Future<void> _setupMedicationNotifications(MedicationCourse course) async {
    try {
      final medication = medications.firstWhereOrNull(
        (m) => m.id == course.medicationId,
      );
      if (medication == null) return;

      // Удаляем старые уведомления для этого препарата
      await _cancelMedicationNotifications(course.medicationId);

      // Создаем ежедневные уведомления только если есть pillsPerDay
      if (course.pillsPerDay != null && course.pillsPerDay! > 0) {
        for (int i = 0; i < course.pillsPerDay!; i++) {
          // Например: уведомления в 9:00, 14:00, 20:00
          final hour = i == 0 ? 9 : (i == 1 ? 14 : 20);
          await NotificationService.scheduleDailyNotification(
            id: '${course.medicationId}_$i',
            title: '💊 Время принять лекарство',
            body: 'Не забудьте принять ${medication.name}',
            hour: hour,
            minute: 0,
            startDate: course.startDate,
            endDate: course.endDate,
          );
        }
      }
    } catch (e) {
      print('Error setting up notifications: $e');
    }
  }

  // Отменить уведомления для препарата
  Future<void> _cancelMedicationNotifications(String medicationId) async {
    try {
      await NotificationService.cancelAllNotificationsForMedication(
        medicationId,
      );
    } catch (e) {
      print('Error cancelling notifications: $e');
    }
  }

  // Получить оставшиеся таблетки для препарата
  int getPillsLeftForMedication(String medicationId) {
    try {
      final course = courses.firstWhereOrNull(
        (c) => c.medicationId == medicationId,
      );
      if (course == null) return 0;

      final medicationRecords = records
          .where((r) => r.medicationId == medicationId)
          .toList();

      return course.calculatePillsLeft(medicationRecords);
    } catch (e) {
      print('Error getting pills left: $e');
      return 0;
    }
  }

  // Загрузить препараты пользователя
  Future<void> fetchMedications() async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null || userId.isEmpty) {
        medications.clear();
        courses.clear(); // Очищаем курсы тоже
        return;
      }

      final fetchedMedications = await _repository.getMedications(userId);
      medications.assignAll(fetchedMedications);

      // Загружаем курсы для всех препаратов
      await fetchCourses();

      print(
        '✅ MedicationController.fetchMedications(): Загружено ${fetchedMedications.length} препаратов',
      );
    } catch (e) {
      print('❌ MedicationController.fetchMedications(): Ошибка: $e');
    }
  }

  // Получить препараты по типу
  List<Medication> getMedicationsByType(MedicationType type) {
    return medications.where((med) {
      switch (type) {
        case MedicationType.pill:
          return med.type == MedicationDbType.pill ||
              med.type == MedicationDbType.both;
        case MedicationType.injection:
          return med.type == MedicationDbType.injection ||
              med.type == MedicationDbType.both;
        case MedicationType.both:
          return med.type == MedicationDbType.both;
      }
    }).toList();
  }

  // Проверка: можно ли принимать таблетку сегодня
  Future<bool> _checkIfCanTakePillToday() async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) return true;

      final today = DateFormat('dd.MM.yyyy').format(DateTime.now());

      // Проверяем, принимал ли пользователь таблетки сегодня
      final todayPills = records.where((record) {
        final isPill =
            record.medicationType == MedicationType.pill ||
            record.medicationType == MedicationType.both;
        return isPill && record.dateOnly == today;
      }).toList();

      if (todayPills.isNotEmpty) {
        // Если уже принимал таблетки сегодня, показываем предупреждение
        final confirmed = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('⚠️ Внимание'),
            content: const Text(
              'Вы уже принимали таблетки сегодня. '
              'Вы уверены, что хотите принять еще одну?',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Нет'),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Да'),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      }
      return true;
    } catch (e) {
      print('Error checking pill: $e');
      return true;
    }
  }

  // Проверка: можно ли делать укол сегодня
  Future<bool> _checkIfCanTakeInjectionToday() async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) return true;

      // Получаем последний укол
      final injectionRecords = records.where((record) {
        return record.medicationType == MedicationType.injection ||
            record.medicationType == MedicationType.both;
      }).toList();

      if (injectionRecords.isEmpty) return true;

      // Сортируем по дате (последний первый)
      injectionRecords.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      final lastInjection = injectionRecords.first;
      final today = DateTime.now();
      final daysSinceLastInjection = today
          .difference(lastInjection.dateTime)
          .inDays;

      // Проверяем курс лечения для этого препарата
      final course = courses.firstWhereOrNull(
        (c) => c.medicationId == lastInjection.medicationId,
      );

      int requiredInterval = 14; // По умолчанию 14 дней

      if (course != null && course.injectionFrequency != null) {
        // Определяем интервал на основе курса
        switch (course.injectionFrequency!) {
          case InjectionFrequency.daily:
            requiredInterval = 1;
            break;
          case InjectionFrequency.weekly:
            requiredInterval = 7;
            break;
          case InjectionFrequency.biweekly:
            requiredInterval = 14;
            break;
          case InjectionFrequency.monthly:
            requiredInterval = 30;
            break;
          case InjectionFrequency.custom:
            requiredInterval = course.injectionIntervalDays ?? 14;
            break;
        }
      }

      if (daysSinceLastInjection < requiredInterval) {
        // Показываем предупреждение, если укол был слишком рано
        final confirmed = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('⚠️ Внимание'),
            content: Text(
              'Последний укол был ${lastInjection.formattedDate} '
              '($daysSinceLastInjection дней назад).\n\n'
              'Рекомендуемый интервал между уколами: $requiredInterval дней.\n'
              'Вы уверены, что хотите сделать укол сейчас?',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Нет'),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Да'),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      }
      return true;
    } catch (e) {
      print('Error checking injection: $e');
      return true;
    }
  }

  // Получение всех записей пользователя
  Future<void> fetchRecords() async {
    print('🔄 MedicationController.fetchRecords(): Начинаю загрузку записей');
    try {
      isLoading.value = true;
      final userId = SupabaseService.userId;
      if (userId == null || userId.isEmpty) {
        print(
          '⚠️ MedicationController.fetchRecords(): UserID пустой, очищаю записи',
        );
        records.clear();
        _updateProgress();
        return;
      }

      final fetchedRecords = await _repository.getRecords(userId);
      records.assignAll(fetchedRecords);

      print(
        '✅ MedicationController.fetchRecords(): Загружено ${fetchedRecords.length} записей',
      );
    } catch (e, stackTrace) {
      print(
        '❌ MedicationController.fetchRecords(): ОШИБКА загрузки записей: $e',
      );
      print('Stack trace: $stackTrace');
      Get.snackbar(
        'Ошибка',
        'Не удалось загрузить записи',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Обновление прогресса
  void _updateProgress() {
    // Расчет оставшихся таблеток с учетом курсов лечения
    int totalPillsLeft = 0;

    // Считаем таблетки только для препаратов с типом pill или both
    for (final medication in medications) {
      if (medication.type == MedicationDbType.pill ||
          medication.type == MedicationDbType.both) {
        totalPillsLeft += getPillsLeftForMedication(medication.id);
      }
    }

    _pillsLeft.value = totalPillsLeft;

    // Новый расчет уколов - берем из курса лечения
    final injectionCourses = courses.where((course) {
      final medication = medications.firstWhereOrNull(
        (m) => m.id == course.medicationId,
      );
      return medication != null &&
          (medication.type == MedicationDbType.injection ||
              medication.type == MedicationDbType.both);
    }).toList();

    if (injectionCourses.isNotEmpty) {
      // Находим ближайший следующий укол среди всех препаратов
      DateTime? nearestInjection;

      for (final course in injectionCourses) {
        final nextInjection = getNextInjectionForMedication(
          course.medicationId,
        );
        if (nextInjection != null &&
            (nearestInjection == null ||
                nextInjection.isBefore(nearestInjection))) {
          nearestInjection = nextInjection;
        }
      }

      _nextInjectionDate.value = nearestInjection;
    } else {
      // Если нет курсов для уколов, используем старую логику
      _nextInjectionDate.value = MedicationProgress.getNextInjectionDate(
        records,
      );
    }

    _statusMessage.value = MedicationProgress.getStatusMessage(records);
    _pillsProgress.value = MedicationProgress.getPillsProgress(records);

    print('📈 MedicationController._updateProgress():');
    print('💊 Таблеток осталось: ${_pillsLeft.value}');
    print(
      '💉 Следующий укол: ${_nextInjectionDate.value != null ? DateFormat('dd.MM.yyyy').format(_nextInjectionDate.value!) : "Нет"}',
    );
    print('💉 Уколов выполнено: $injectionCount');
    print('📝 Статус: ${_statusMessage.value}');
    print('📊 Прогресс: ${(_pillsProgress.value * 100).toStringAsFixed(1)}%');
  }

  // Добавление новой записи
  Future<void> addRecord() async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) {
        Get.snackbar('Ошибка', 'Пользователь не авторизован');
        return;
      }

      // Если выбран препарат, проверяем его тип
      if (selectedMedication.value != null) {
        final med = selectedMedication.value!;
        if (!med.isPill && selectedType.value == MedicationType.pill) {
          Get.snackbar(
            'Ошибка',
            'Этот препарат не предназначен для приема в виде таблеток',
          );
          return;
        }
        if (!med.isInjection &&
            selectedType.value == MedicationType.injection) {
          Get.snackbar('Ошибка', 'Этот препарат не предназначен для уколов');
          return;
        }
        if (med.type == MedicationDbType.both &&
            selectedType.value == MedicationType.both) {
          // Для препаратов типа "оба" - можно и таблетку, и укол
        }
      }

      // Проверки в зависимости от типа медикамента
      bool canProceed = true;
      if (selectedType.value == MedicationType.pill) {
        canProceed = await _checkIfCanTakePillToday();
      } else if (selectedType.value == MedicationType.injection) {
        canProceed = await _checkIfCanTakeInjectionToday();
      } else if (selectedType.value == MedicationType.both) {
        // Проверяем и таблетки, и уколы
        final canTakePill = await _checkIfCanTakePillToday();
        final canTakeInjection = await _checkIfCanTakeInjectionToday();
        canProceed = canTakePill && canTakeInjection;
      }

      if (!canProceed) {
        print('❌ Добавление записи отменено пользователем');
        Get.snackbar(
          'Отменено',
          'Запись не добавлена',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      // Валидация
      if ((selectedType.value == MedicationType.injection ||
              selectedType.value == MedicationType.both) &&
          selectedInjectionSite.value == null) {
        Get.snackbar('Внимание', 'Выберите место укола');
        return;
      }

      final record = MedicationRecord(
        id: '',
        userId: userId,
        medicationType: selectedType.value,
        injectionSite: selectedInjectionSite.value,
        dateTime: DateTime.now(),
        createdAt: DateTime.now(),
        medicationId: selectedMedication.value?.id,
      );

      await _repository.addRecord(record);

      // Сброс формы
      selectedType.value = MedicationType.pill;
      selectedInjectionSite.value = null;
      selectedMedication.value = null;

      Get.snackbar(
        '✅ Успешно',
        'Запись добавлена',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Автоматически обновляем данные
      await fetchRecords();
      _updateProgress(); // Обновляем прогресс
    } catch (e) {
      print('❌ Ошибка добавления записи: $e');
      Get.snackbar(
        '❌ Ошибка',
        'Не удалось добавить запись',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Добавление старой записи
  Future<void> addOldRecord({
    required MedicationType type,
    required DateTime dateTime,
    Medication? medication,
    InjectionSite? injectionSite,
  }) async {
    try {
      final userId = SupabaseService.userId;
      if (userId == null) {
        Get.snackbar('Ошибка', 'Пользователь не авторизован');
        return;
      }

      // Для старых записей проверки не делаем
      // Валидация для уколов
      if ((type == MedicationType.injection || type == MedicationType.both) &&
          injectionSite == null) {
        Get.snackbar('Ошибка', 'Для укола необходимо указать место инъекции');
        return;
      }

      final record = MedicationRecord(
        id: '',
        userId: userId,
        medicationType: type,
        injectionSite: injectionSite,
        dateTime: dateTime,
        createdAt: DateTime.now(),
        medicationId: medication?.id,
      );

      await _repository.addRecord(record);

      Get.snackbar(
        '✅ Успешно',
        'Запись за ${DateFormat('dd.MM.yyyy').format(dateTime)} добавлена',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      await fetchRecords();
      _updateProgress(); // Обновляем прогресс
    } catch (e) {
      print('❌ Ошибка добавления старой записи: $e');
      Get.snackbar(
        '❌ Ошибка',
        'Не удалось добавить запись',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> deleteRecord(String recordId) async {
    try {
      await _repository.deleteRecord(recordId);
      Get.snackbar(
        '✅ Успешно',
        'Запись удалена',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      await fetchRecords();
      _updateProgress(); // Обновляем прогресс
    } catch (e) {
      Get.snackbar(
        '❌ Ошибка',
        'Не удалось удалить запись',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Map<String, List<MedicationRecord>> getRecordsByDay() {
    final Map<String, List<MedicationRecord>> recordsByDay = {};
    for (final record in records) {
      final day = record.dateOnly;
      recordsByDay.putIfAbsent(day, () => []).add(record);
    }
    final sortedEntries = recordsByDay.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(sortedEntries);
  }

  int getTodayRecordsCount() {
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
    return records.where((record) => record.dateOnly == today).length;
  }

  // Получить количество таблеток
  int get pillCount {
    return MedicationRecord.getPillCount(records);
  }
}
