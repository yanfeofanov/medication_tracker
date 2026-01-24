// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/medication_controller.dart';
import '../models/medication_record.dart';
import '../widgets/stats_card.dart';

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
            const SizedBox(height: 12),

            // Прогресс таблеток
            Obx(() {
              final pillsLeft = _controller.pillsLeft;
              final progress = _controller.pillsProgress;
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
                        'Осталось: $pillsLeft',
                        style: TextStyle(
                          color: pillsLeft < 10 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.blue,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}% (до 20.05.2026)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              );
            }),

            const SizedBox(height: 16),

            // Статистика уколов
            Obx(() {
              final injectionCount = _controller.injectionCount;
              final injectionProgress = _controller.injectionProgress;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '💉 Уколы (всего)',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$injectionCount выполнено',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (injectionCount > 0)
                    LinearProgressIndicator(
                      value: injectionCount / 10, // 10 уколов в курсе
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.green,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  const SizedBox(height: 4),
                  if (injectionCount > 0)
                    Text(
                      injectionProgress,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              );
            }),

            const SizedBox(height: 16),

            // Следующий укол
            Obx(() {
              final nextInjection = _controller.nextInjectionDate;
              final daysUntil = _controller.daysUntilNextInjection;

              if (nextInjection == null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '💉 Следующий укол',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Нет данных об уколах',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💉 Следующий укол',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Следующий укол:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            DateFormat('dd.MM.yyyy').format(nextInjection),
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
                          color: daysUntil <= 3
                              ? Colors.orange.shade100
                              : daysUntil <= 7
                              ? Colors.yellow.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          daysUntil > 0
                              ? 'Через $daysUntil ${_getDayWord(daysUntil)}'
                              : 'Сегодня!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: daysUntil <= 3
                                ? Colors.orange.shade800
                                : daysUntil <= 7
                                ? Colors.yellow.shade800
                                : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
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
                  // Сбрасываем место укола если не нужен
                  if (value != MedicationType.injection &&
                      value != MedicationType.both) {
                    _controller.selectedInjectionSite.value = null;
                  }
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
        title: Text(
          record.medicationType.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
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
