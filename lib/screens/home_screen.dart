// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:medication_tracker/models/medication_course.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/medication_controller.dart';
import '../models/medication_record.dart';
import '../models/medication.dart';
import '../widgets/stats_card.dart';
import 'medications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MedicationController _controller = Get.put(MedicationController());
  final ScrollController _historyScrollController = ScrollController();
  bool _isHistoryExpanded = false;
  double _historyHeight = 300; // Начальная высота

  @override
  void initState() {
    super.initState();
    print('HomeScreen: initState called');
  }

  @override
  void dispose() {
    _historyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('HomeScreen: build called');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Tracker'),
        actions: [
          // Кнопка перехода к препаратам
          IconButton(
            icon: const Icon(Icons.medication),
            onPressed: () {
              Get.to(() => const MedicationsScreen());
            },
            tooltip: 'Мои препараты',
          ),
          // Кнопка добавления старой записи
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showAddOldRecordDialog,
            tooltip: 'Добавить старую запись',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: const [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('Обновить'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: const [
                    Icon(Icons.analytics, size: 20),
                    SizedBox(width: 8),
                    Text('Статистика'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'injections',
                child: Row(
                  children: const [
                    Icon(Icons.medical_services, size: 20),
                    SizedBox(width: 8),
                    Text('Уколы'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Выйти'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                await Supabase.instance.client.auth.signOut();
              } else if (value == 'refresh') {
                await _controller.fetchRecords();
                await _controller.fetchMedications();
              } else if (value == 'stats') {
                _showStatisticsDialog();
              } else if (value == 'injections') {
                _showInjectionStatsDialog();
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        // Прогресс
        SliverToBoxAdapter(child: _buildProgressCard()),
        // Форма
        SliverToBoxAdapter(child: _buildAddForm()),
        // Переключатель истории
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: _toggleHistoryExpansion,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isHistoryExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isHistoryExpanded
                        ? 'Свернуть историю'
                        : 'Развернуть историю',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // История (расширяемая)
        SliverToBoxAdapter(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isHistoryExpanded
                ? MediaQuery.of(context).size.height * 0.6
                : 300,
            curve: Curves.easeInOut,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.history, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'История записей',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Obx(() {
                          final count = _controller.getTodayRecordsCount();
                          if (count > 0) {
                            return Chip(
                              label: Text('Сегодня: $count'),
                              backgroundColor: Colors.blue.shade50,
                            );
                          }
                          return Container();
                        }),
                      ],
                    ),
                  ),
                  Expanded(child: _buildRecordsList()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleHistoryExpansion() {
    setState(() {
      _isHistoryExpanded = !_isHistoryExpanded;
    });
  }

  int getPillsLeftForMedication(String medicationId) {
    try {
      final course = _controller.courses.firstWhereOrNull(
        (c) => c.medicationId == medicationId,
      );
      if (course == null) return 0;

      final medicationRecords = _controller.records
          .where((r) => r.medicationId == medicationId)
          .toList();

      return course.calculatePillsLeft(medicationRecords);
    } catch (e) {
      print('Error getting pills left: $e');
      return 0;
    }
  }

  Widget _buildProgressCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '📊 Прогресс лечения',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ТАБЛЕТКИ - ОБЪЕДИНЕННАЯ ИНФОРМАЦИЯ
            Obx(() {
              // Находим все курсы для таблеток
              final pillCourses = _controller.courses.where((course) {
                final medication = _controller.medications.firstWhereOrNull(
                  (m) => m.id == course.medicationId,
                );
                return medication != null &&
                    (medication.type == MedicationDbType.pill ||
                        medication.type == MedicationDbType.both) &&
                    course.isActive;
              }).toList();

              if (pillCourses.isEmpty) {
                return Container(); // Не показываем если нет активных курсов таблеток
              }

              // Считаем общее количество оставшихся таблеток
              int totalPillsLeft = 0;
              for (final course in pillCourses) {
                totalPillsLeft += getPillsLeftForMedication(
                  course.medicationId,
                );
              }

              // Находим ближайшую дату окончания курса
              DateTime? nearestEndDate;
              for (final course in pillCourses) {
                final endDate = course.endDate;
                if (endDate != null) {
                  if (nearestEndDate == null ||
                      endDate.isBefore(nearestEndDate)) {
                    nearestEndDate = endDate;
                  }
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '💊 Таблетки',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Осталось: $totalPillsLeft',
                        style: TextStyle(
                          color: totalPillsLeft < 10
                              ? Colors.red
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _controller.pillsProgress,
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.blue,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  if (nearestEndDate != null)
                    Text(
                      '${(_controller.pillsProgress * 100).toStringAsFixed(1)}% (до ${DateFormat('dd.MM.yyyy').format(nearestEndDate)})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  if (nearestEndDate == null)
                    Text(
                      '${(_controller.pillsProgress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  const SizedBox(height: 16),
                ],
              );
            }),

            // УКОЛЫ - ОБЪЕДИНЕННАЯ ИНФОРМАЦИЯ
            Obx(() {
              // Находим все курсы для уколов
              final injectionCourses = _controller.courses.where((course) {
                final medication = _controller.medications.firstWhereOrNull(
                  (m) => m.id == course.medicationId,
                );
                return medication != null &&
                    (medication.type == MedicationDbType.injection ||
                        medication.type == MedicationDbType.both) &&
                    course.isActive;
              }).toList();

              if (injectionCourses.isEmpty) {
                return Container(); // Не показываем если нет активных курсов уколов
              }

              // Общее количество выполненных уколов
              final totalInjectionCount = _controller.injectionCount;

              // Находим курс с ближайшим уколом
              DateTime? nearestInjectionDate;
              MedicationCourse? nearestCourse;

              for (final course in injectionCourses) {
                final nextInjection = _controller.getNextInjectionForMedication(
                  course.medicationId,
                );
                if (nextInjection != null &&
                    (nearestInjectionDate == null ||
                        nextInjection.isBefore(nearestInjectionDate))) {
                  nearestInjectionDate = nextInjection;
                  nearestCourse = course;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '💉 Уколы',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$totalInjectionCount выполнено',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Информация о курсе уколов
                  if (nearestCourse != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Курс: ${nearestCourse.injectionInfo}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),

                  // Следующий укол
                  if (nearestInjectionDate != null)
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Следующий укол:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    //   color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'dd.MM.yyyy',
                                  ).format(nearestInjectionDate),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _controller.daysUntilNextInjection <= 3
                                    ? Colors.orange.shade100
                                    : _controller.daysUntilNextInjection <= 7
                                    ? Colors.yellow.shade100
                                    : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _controller.daysUntilNextInjection > 0
                                    ? 'Через ${_controller.daysUntilNextInjection} ${_getDayWord(_controller.daysUntilNextInjection)}'
                                    : 'Сегодня!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _controller.daysUntilNextInjection <= 3
                                      ? Colors.orange.shade800
                                      : _controller.daysUntilNextInjection <= 7
                                      ? Colors.yellow.shade800
                                      : Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),
                ],
              );
            }),

            // ОБЩИЙ СТАТУС (если нет активных курсов)
            Obx(() {
              final hasActiveCourses = _controller.courses.any(
                (course) => course.isActive,
              );
              if (hasActiveCourses) return Container();

              return Column(
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Нет активных курсов лечения',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Добавьте препарат и настройте курс лечения',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getDayWord(int days) {
    if (days % 10 == 1 && days % 100 != 11) return 'день';
    if (days % 10 >= 2 &&
        days % 10 <= 4 &&
        (days % 100 < 10 || days % 100 >= 20)) {
      return 'дня';
    }
    return 'дней';
  }

  void _showAddOldRecordDialog() {
    DateTime selectedDate = DateTime.now();
    MedicationType selectedType = MedicationType.pill;
    Medication? selectedMedication;
    InjectionSite? selectedInjectionSite;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('📅 Добавить старую запись'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Выбор даты
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Дата и время'),
                    subtitle: Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(selectedDate),
                    ),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                        );
                        if (pickedTime != null) {
                          setState(() {
                            selectedDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Выбор препарата
                  DropdownButtonFormField<Medication?>(
                    value: selectedMedication,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Без препарата'),
                      ),
                      ..._controller.medications.map((med) {
                        return DropdownMenuItem(
                          value: med,
                          child: Text(med.name),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() => selectedMedication = value);
                      if (value != null) {
                        // Автоматически выбираем тип препарата
                        if (value.type == MedicationDbType.pill) {
                          selectedType = MedicationType.pill;
                        } else if (value.type == MedicationDbType.injection) {
                          selectedType = MedicationType.injection;
                        } else if (value.type == MedicationDbType.both) {
                          selectedType = MedicationType.both;
                        }
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Препарат (опционально)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Выбор типа
                  DropdownButtonFormField<MedicationType>(
                    value: selectedType,
                    items: MedicationType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Text(type.emoji),
                            const SizedBox(width: 8),
                            Text(type.displayName),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedType = value;
                          if (value != MedicationType.injection &&
                              value != MedicationType.both) {
                            selectedInjectionSite = null;
                          }
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Тип медикамента',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Место укола (если нужно)
                  if (selectedType == MedicationType.injection ||
                      selectedType == MedicationType.both)
                    DropdownButtonFormField<InjectionSite>(
                      value: selectedInjectionSite,
                      items: InjectionSite.values.map((site) {
                        return DropdownMenuItem(
                          value: site,
                          child: Row(
                            children: [
                              Text(site.emoji),
                              const SizedBox(width: 8),
                              Text(site.displayName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedInjectionSite = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Место укола',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  if ((selectedType == MedicationType.injection ||
                          selectedType == MedicationType.both) &&
                      selectedInjectionSite == null) {
                    Get.snackbar('Ошибка', 'Выберите место укола');
                    return;
                  }

                  _controller.addOldRecord(
                    type: selectedType,
                    dateTime: selectedDate,
                    medication: selectedMedication,
                    injectionSite: selectedInjectionSite,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Добавить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddForm() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Текущее время
            Text(
              'Время: ${DateFormat('HH:mm').format(DateTime.now())}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),

            // Выбор препарата
            Obx(() {
              final medications = _controller.getMedicationsByType(
                _controller.selectedType.value,
              );

              if (medications.isNotEmpty) {
                return DropdownButtonFormField<Medication?>(
                  value: _controller.selectedMedication.value,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Без препарата'),
                    ),
                    ...medications.map((medication) {
                      return DropdownMenuItem(
                        value: medication,
                        child: Text(medication.name),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    _controller.selectedMedication.value = value;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Препарат (опционально)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                );
              }
              return Container();
            }),
            const SizedBox(height: 12),

            // Тип медикамента
            DropdownButtonFormField<MedicationType>(
              value: _controller.selectedType.value,
              items: MedicationType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Text(type.emoji),
                      const SizedBox(width: 8),
                      Text(type.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _controller.selectedType.value = value;
                  // Сбрасываем выбранный препарат при смене типа
                  _controller.selectedMedication.value = null;
                }
              },
              decoration: const InputDecoration(
                labelText: 'Тип медикамента',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Место укола (только для уколов)
            Obx(() {
              if (_controller.selectedType.value == MedicationType.injection ||
                  _controller.selectedType.value == MedicationType.both) {
                return DropdownButtonFormField<InjectionSite>(
                  value: _controller.selectedInjectionSite.value,
                  items: InjectionSite.values.map((site) {
                    return DropdownMenuItem(
                      value: site,
                      child: Row(
                        children: [
                          Text(site.emoji),
                          const SizedBox(width: 8),
                          Text(site.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    _controller.selectedInjectionSite.value = value;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Место укола',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                );
              }
              return Container();
            }),
            const SizedBox(height: 16),

            // Кнопка добавления
            ElevatedButton(
              onPressed: () {
                _controller.addRecord();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Добавить запись',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsList() {
    return Obx(() {
      if (_controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_controller.records.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.history, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Нет записей',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              Text(
                'Добавьте первую запись',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () => _controller.fetchRecords(),
        child: ListView.builder(
          controller: _historyScrollController,
          physics: const AlwaysScrollableScrollPhysics(), // ← ДОБАВИТЬ
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          itemCount: _controller.records.length,
          itemBuilder: (context, index) {
            final record = _controller.records[index];
            return _buildRecordCard(record);
          },
        ),
      );
    });
  }

  Widget _buildRecordCard(MedicationRecord record) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getColorForType(record.medicationType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getIconForType(record.medicationType),
            color: _getColorForType(record.medicationType),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.medicationNameWithType,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (record.medication != null && record.medication!.dosage != null)
              Text(
                'Дозировка: ${record.medication!.dosage}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFormat.format(record.dateTime)),
            if (record.injectionSite != null)
              Text(
                'Место: ${record.injectionSite!.displayName}',
                style: const TextStyle(color: Colors.green),
              ),
            if (record.medicationType == MedicationType.injection ||
                record.medicationType == MedicationType.both)
              Text(
                'Следующий: ${record.formattedNextInjectionDate}',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () {
            _showDeleteDialog(record);
          },
        ),
      ),
    );
  }

  void _showDeleteDialog(MedicationRecord record) {
    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: const Text('Вы уверены, что хотите удалить эту запись?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              _controller.deleteRecord(record.id);
              Navigator.pop(context);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showStatisticsDialog() {
    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('📊 Статистика'),
        content: SingleChildScrollView(child: StatsCard()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showInjectionStatsDialog() {
    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('💉 Статистика уколов'),
        content: Obx(() {
          final injectionCount = _controller.injectionCount;
          final injectionProgress = _controller.injectionProgress;
          final nextInjection = _controller.nextInjectionDate;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Выполнено уколов: $injectionCount',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Прогресс курса: $injectionProgress',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (nextInjection != null)
                Text(
                  'Следующий укол: ${DateFormat('dd.MM.yyyy').format(nextInjection)}',
                  style: const TextStyle(fontSize: 16),
                ),
              const SizedBox(height: 16),
              const Text(
                'Рекомендации:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Интервал между уколами: 14 дней'),
              const Text('• Меняйте места инъекций'),
              const Text('• Следите за реакцией организма'),
            ],
          );
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Color _getColorForType(MedicationType type) {
    switch (type) {
      case MedicationType.pill:
        return Colors.blue;
      case MedicationType.injection:
        return Colors.green;
      case MedicationType.both:
        return Colors.orange;
    }
  }

  IconData _getIconForType(MedicationType type) {
    switch (type) {
      case MedicationType.pill:
        return Icons.medication;
      case MedicationType.injection:
        return Icons.medical_services;
      case MedicationType.both:
        return Icons.medical_information;
    }
  }
}
