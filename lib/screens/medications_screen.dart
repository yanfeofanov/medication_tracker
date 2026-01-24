// lib/screens/medications_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medication_tracker/controllers/medication_controller.dart';
import 'package:medication_tracker/models/medication.dart';
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
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            _showDeleteDialog(medication);
                          },
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
}
