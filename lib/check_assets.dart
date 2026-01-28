// check_assets.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🔍 Проверка assets...');

  final assets = [
    'assets/images/logo.png',
    'assets/icon/icon.png',
    'assets/icons/icon.png',
  ];

  for (final asset in assets) {
    try {
      await rootBundle.load(asset);
      print('✅ $asset - найден');
    } catch (e) {
      print('❌ $asset - не найден ($e)');
    }
  }

  // Проверим физическое существование файлов
  print('\n📁 Проверка физических файлов...');
  for (final asset in assets) {
    final file = File(asset);
    if (await file.exists()) {
      print(
        '✅ $asset - физический файл существует (${await file.length()} байт)',
      );
    } else {
      print('❌ $asset - физический файл не существует');
    }
  }

  exit(0);
}
