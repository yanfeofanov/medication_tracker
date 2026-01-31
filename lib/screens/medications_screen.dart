// lib/screens/medications_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:medication_tracker/controllers/medication_controller.dart';
import 'package:medication_tracker/models/medication.dart';
import 'package:medication_tracker/models/medication_course.dart';
import 'package:medication_tracker/repositories/medication_repository.dart';
import 'package:medication_tracker/services/supabase_service.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final MedicationController _controller = Get.find<MedicationController>();
  final MedicationRepository _repository = MedicationRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _descriptionController = TextEditingController();

  MedicationDbType _selectedType = MedicationDbType.pill;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller.fetchMedications();
  }

  Future<void> _addMedication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.userId;
      if (userId == null) {
        Get.snackbar('Ошибка', 'Пользователь не авторизован');
        return;
      }

      final medication = Medication(
        id: '',
        userId: userId,
        name: _nameController.text.trim(),
        type: _selectedType,
        dosage: _dosageController.text.trim().isEmpty
            ? null
            : _dosageController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repository.addMedication(medication);

      // Обновляем список
      await _controller.fetchMedications();

      // Очищаем форму
      _nameController.clear();
      _dosageController.clear();
      _descriptionController.clear();
      _selectedType = MedicationDbType.pill;

      Get.snackbar(
        '✅ Успешно',
        'Препарат добавлен',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        '❌ Ошибка',
        'Не удалось добавить препарат',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои препараты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.fetchMedications(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        // ← ИЗМЕНЕНИЕ: Обернули в SingleChildScrollView
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Форма добавления
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Добавить препарат',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Название
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Название препарата',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.medication),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Введите название';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Тип
                      DropdownButtonFormField<MedicationDbType>(
                        value: _selectedType,
                        items: MedicationDbType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Text(
                                  type == MedicationDbType.pill
                                      ? '💊'
                                      : type == MedicationDbType.injection
                                      ? '💉'
                                      : '💊💉',
                                ),
                                const SizedBox(width: 8),
                                Text(type.displayName),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedType = value);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Тип препарата',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Дозировка
                      TextFormField(
                        controller: _dosageController,
                        decoration: const InputDecoration(
                          labelText: 'Дозировка (опционально)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.format_size),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Описание
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Описание (опционально)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      // Кнопка
                      ElevatedButton(
                        onPressed: _isLoading ? null : _addMedication,
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(),
                              )
                            : const Text('Добавить препарат'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Список препаратов
            Obx(() {
              if (_controller.medications.isEmpty) {
                return Container(
                  height: 200, // ← ИЗМЕНЕНИЕ: Фиксированная высота
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.medication, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Нет добавленных препаратов',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      Text(
                        'Добавьте первый препарат',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Ваши препараты',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ..._controller.medications.map((medication) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: medication.type == MedicationDbType.pill
                                ? Colors.blue.withOpacity(0.1)
                                : medication.type == MedicationDbType.injection
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            medication.type == MedicationDbType.pill
                                ? Icons.medication
                                : Icons.medical_services,
                            color: medication.type == MedicationDbType.pill
                                ? Colors.blue
                                : medication.type == MedicationDbType.injection
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        title: Text(medication.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(medication.displayType),
                            if (medication.dosage != null)
                              Text('Дозировка: ${medication.dosage}'),
                            if (medication.description != null)
                              Text(
                                medication.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.settings,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                _showCourseSetupDialog(medication);
                              },
                              tooltip: 'Настроить курс лечения',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                _showDeleteDialog(medication);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Medication medication) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить препарат?'),
        content: Text(
          'Вы уверены, что хотите удалить препарат "${medication.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Реализовать удаление препарата
              Navigator.pop(context);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCourseSetupDialog(Medication medication) {
    CourseDurationType _selectedDuration =
        medication.defaultDurationType ?? CourseDurationType.month;
    DateTime? _selectedCustomDate;
    int _pillsPerDay = medication.defaultPillsPerDay ?? 1;
    int _totalPills = medication.defaultTotalPills ?? 0;
    bool _enableNotifications = medication.defaultHasNotifications ?? true;

    // Новые переменные для уколов
    InjectionFrequency _selectedInjectionFrequency =
        InjectionFrequency.biweekly;
    int _customInjectionInterval = 14;
    bool _notifyDayBefore = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('⚙️ Настройка курса лечения'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Продолжительность курса
                  DropdownButtonFormField<CourseDurationType>(
                    value: _selectedDuration,
                    items: CourseDurationType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedDuration = value);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Продолжительность курса',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Выбор даты окончания (если выбран custom)
                  if (_selectedDuration == CourseDurationType.custom)
                    Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: const Text('Дата окончания'),
                          subtitle: Text(
                            _selectedCustomDate != null
                                ? DateFormat(
                                    'dd.MM.yyyy',
                                  ).format(_selectedCustomDate!)
                                : 'Выберите дату',
                          ),
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(
                                const Duration(days: 30),
                              ),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365 * 5),
                              ),
                            );
                            if (pickedDate != null) {
                              setState(() => _selectedCustomDate = pickedDate);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),

                  // НАСТРОЙКИ ДЛЯ УКОЛОВ
                  if (medication.type == MedicationDbType.injection ||
                      medication.type == MedicationDbType.both)
                    Column(
                      children: [
                        const Divider(),
                        const Text(
                          'Настройки уколов:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Частота уколов
                        DropdownButtonFormField<InjectionFrequency>(
                          value: _selectedInjectionFrequency,
                          items: InjectionFrequency.values.map((freq) {
                            return DropdownMenuItem(
                              value: freq,
                              child: Text(freq.displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(
                                () => _selectedInjectionFrequency = value,
                              );
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Частота уколов',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Кастомный интервал
                        if (_selectedInjectionFrequency ==
                            InjectionFrequency.custom)
                          TextFormField(
                            initialValue: _customInjectionInterval.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Интервал (дней)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final intValue = int.tryParse(value);
                              if (intValue != null && intValue > 0) {
                                setState(
                                  () => _customInjectionInterval = intValue,
                                );
                              }
                            },
                          ),

                        // Уведомление за день до
                        SwitchListTile(
                          title: const Text('Уведомлять за день до укола'),
                          subtitle: const Text('Получить напоминание за день'),
                          value: _notifyDayBefore,
                          onChanged: (value) {
                            setState(() => _notifyDayBefore = value);
                          },
                        ),
                      ],
                    ),

                  // НАСТРОЙКИ ДЛЯ ТАБЛЕТОК
                  if (medication.type == MedicationDbType.pill ||
                      medication.type == MedicationDbType.both)
                    Column(
                      children: [
                        const Divider(),
                        const Text(
                          'Настройки таблеток:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Количество таблеток в день
                        TextFormField(
                          initialValue: _pillsPerDay.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Таблеток в день',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.medication),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final intValue = int.tryParse(value);
                            if (intValue != null && intValue > 0) {
                              setState(() => _pillsPerDay = intValue);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Общее количество таблеток (для пожизненного приема)
                        if (_selectedDuration == CourseDurationType.lifetime)
                          TextFormField(
                            initialValue: _totalPills.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Общее количество таблеток',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final intValue = int.tryParse(value);
                              if (intValue != null) {
                                setState(() => _totalPills = intValue);
                              }
                            },
                          ),
                      ],
                    ),

                  // Общие уведомления
                  SwitchListTile(
                    title: const Text('Включить уведомления'),
                    subtitle: const Text('Напоминания о приеме лекарства'),
                    value: _enableNotifications,
                    onChanged: (value) {
                      setState(() => _enableNotifications = value);
                    },
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
                onPressed: () async {
                  if (_selectedDuration == CourseDurationType.custom &&
                      _selectedCustomDate == null) {
                    Get.snackbar('Ошибка', 'Выберите дату окончания');
                    return;
                  }

                  await _controller.createMedicationCourse(
                    medicationId: medication.id,
                    durationType: _selectedDuration,
                    customEndDate: _selectedCustomDate,
                    pillsPerDay: _pillsPerDay,
                    totalPills: _totalPills,
                    hasNotifications: _enableNotifications,
                    // Новые параметры для уколов
                    injectionFrequency:
                        (medication.type == MedicationDbType.injection ||
                            medication.type == MedicationDbType.both)
                        ? _selectedInjectionFrequency
                        : null,
                    injectionIntervalDays: _customInjectionInterval,
                    injectionNotifyDayBefore: _notifyDayBefore,
                  );

                  // ДОБАВЛЕНО: Показать сообщение об успешной настройке уведомлений
                  if (_enableNotifications) {
                    Get.snackbar(
                      '✅ Уведомления настроены',
                      'Вы будете получать напоминания о приеме лекарства',
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  } else {
                    Get.snackbar(
                      'ℹ️ Уведомления отключены',
                      'Вы не будете получать напоминания',
                      backgroundColor: Colors.blue,
                      colorText: Colors.white,
                    );
                  }

                  Navigator.pop(context);
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }
}
