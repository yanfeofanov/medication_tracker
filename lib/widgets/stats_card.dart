// lib/widgets/stats_card.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/medication_controller.dart';

class StatsCard extends StatelessWidget {
  const StatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MedicationController>();
    final todayCount = controller.getTodayRecordsCount();
    final totalCount = controller.records.length;
    final recordsByDay = controller.getRecordsByDay();
    final pillsLeft = controller.pillsLeft;
    final nextInjection = controller.nextInjectionDate;
    final injectionCount = controller.injectionCount;
    final pillCount = controller.pillCount;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Статистика',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Основная статистика
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  title: 'Сегодня',
                  value: todayCount.toString(),
                  icon: Icons.today,
                  color: Colors.blue,
                ),
                _StatItem(
                  title: 'Всего',
                  value: totalCount.toString(),
                  icon: Icons.history,
                  color: Colors.green,
                ),
                _StatItem(
                  title: 'Дней',
                  value: recordsByDay.length.toString(),
                  icon: Icons.calendar_today,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Детальная статистика
            const Text(
              'Детальная статистика:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  title: 'Таблетки',
                  value: pillCount.toString(),
                  icon: Icons.medication,
                  color: Colors.blue,
                ),
                _StatItem(
                  title: 'Уколы',
                  value: injectionCount.toString(),
                  icon: Icons.medical_services,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Отслеживание лечения
            const Text(
              'Отслеживание лечения:',
              style: TextStyle(fontWeight: FontWeight.w100),
            ),
            const SizedBox(height: 10),

            // Таблетки
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication, color: Colors.blue),
                  const SizedBox(width: 12),
                  Chip(
                    label: Text('$pillsLeft осталось'),
                    backgroundColor: Colors.blue,
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // Уколы
            if (nextInjection != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medical_services, color: Colors.green),
                    const SizedBox(width: 12),
                    Chip(
                      label: Text(
                        'Через ${controller.daysUntilNextInjection} дн.',
                      ),
                      backgroundColor: Colors.green,
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

            // Прогресс уколов
            if (injectionCount > 0)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timeline, color: Colors.purple),
                    const SizedBox(width: 12),
                    Chip(
                      label: Text(controller.injectionProgress),
                      backgroundColor: Colors.purple,
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
