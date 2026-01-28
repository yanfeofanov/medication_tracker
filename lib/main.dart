// lib/main.dart

import 'dart:async';
import 'dart:developer' as developer;

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medication_tracker/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'utils/keys.dart';
import 'services/notification_service.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  print('🚀 main(): Начало инициализации приложения');
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Загружаем конфигурацию из .env файла
    print('🔄 main(): Загрузка конфигурации...');
    await Config.load();

    print('🔄 main(): Начинаю инициализацию Supabase...');
    await Supabase.initialize(
      url: SupabaseKeys.url,
      anonKey: SupabaseKeys.anonKey,
    );
    print('✅ main(): Supabase успешно инициализирован');

    // Инициализация уведомлений с расширенной настройкой
    print('🔄 main(): Инициализация уведомлений...');

    await AwesomeNotifications().initialize(null, [
      NotificationChannel(
        channelKey: 'medication_reminders',
        channelName: 'Напоминания о лекарствах',
        channelDescription: 'Уведомления о приеме лекарств и уколах',
        defaultColor: const Color(0xFF2196F3),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        locked: true,
        defaultPrivacy: NotificationPrivacy.Public,
      ),
    ]);

    // Двойная проверка разрешений уведомлений
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    print('✅ main(): Уведомления успешно настроены');
  } catch (e, stackTrace) {
    print('❌ main(): ОШИБКА инициализации: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('📱 MyApp.build(): Создание главного виджета');
    return GetMaterialApp(
      title: 'Medication Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitializing = true;
  bool _isAuthenticated = false;
  String _userEmail = '';
  late StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    print('🔄 _AuthWrapperState.initState(): Начало');
    super.initState();
    _setupAuthListener();
    _checkInitialAuthStatus();
  }

  void _setupAuthListener() {
    // Подписываемся на изменения состояния авторизации
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) {
          print('📢 _AuthWrapperState: Получено событие auth state change');
          print('🔍 Событие: ${data.event}, Сессия: ${data.session}');
          _updateAuthStatus();
        });
  }

  Future<void> _checkInitialAuthStatus() async {
    print(
      '🔍 _AuthWrapperState._checkInitialAuthStatus(): Проверяю авторизацию',
    );
    await _updateAuthStatus();
  }

  Future<void> _updateAuthStatus() async {
    try {
      // Даем небольшую задержку для стабильности
      await Future.delayed(const Duration(milliseconds: 100));

      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      final user = supabase.auth.currentUser;

      print('👤 Текущий пользователь: ${user?.email ?? "null"}');
      print('🔑 Текущая сессия: ${session != null ? "active" : "none"}');

      setState(() {
        _isAuthenticated = session != null;
        _userEmail = user?.email ?? '';
        _isInitializing = false;
      });

      print(
        '✅ Статус обновлен: авторизован: $_isAuthenticated, email: $_userEmail',
      );

      // Если пользователь авторизован, синхронизируем дату укола
      if (_isAuthenticated) {
        await _syncInjectionDate();
      }
    } catch (e, stackTrace) {
      print('❌ ОШИБКА проверки авторизации: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isAuthenticated = false;
        _isInitializing = false;
      });
    }
  }

  // Метод синхронизации даты следующего укола
  Future<void> _syncInjectionDate() async {
    try {
      final storedDate = await LocalStorageService.getNextInjectionDate();
      // Если дата есть в хранилище и она в прошлом
      if (storedDate != null && storedDate.isBefore(DateTime.now())) {
        // Обновляем дату на сегодня + интервал
        await LocalStorageService.updateNextInjectionDate();
        // Показываем уведомление
        await NotificationService.showInstantNotification(
          title: '💉 Время для укола',
          body: 'Пора сделать укол согласно вашему графику',
        );
      }
    } catch (e) {
      print('Error syncing injection date: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ _AuthWrapperState.build(): Строю виджет');
    print('⏳ isInitializing: $_isInitializing');
    print('🔐 isAuthenticated: $_isAuthenticated');
    print('📧 userEmail: $_userEmail');

    // Показываем сплэш-скрин во время инициализации
    if (_isInitializing) {
      print('⏳ Показываю сплэш-скрин');
      return _buildSplashScreen();
    }

    // Если пользователь авторизован - показываем главный экран
    if (_isAuthenticated) {
      print('🏠 Пользователь авторизован, показываю HomeScreen');
      return const HomeScreen();
    }

    // Иначе показываем экран авторизации
    print('🔐 Пользователь не авторизован, показываю AuthScreen');
    return const AuthScreen();
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Логотип с отладкой
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(75),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Фоновый контур
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(75),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  // Изображение
                  Center(child: _buildLogo()),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Medication\nTracker',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.blue.shade700),
            const SizedBox(height: 20),
            const Text(
              'Проверка авторизации...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    try {
      return Image.asset(
        'assets/images/logo.png',
        width: 120,
        height: 120,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Ошибка загрузки логотипа: $error');
          print('Stack trace: $stackTrace');
          return _buildFallbackLogo();
        },
      );
    } catch (e) {
      print('❌ Исключение при загрузке логотипа: $e');
      return _buildFallbackLogo();
    }
  }

  Widget _buildFallbackLogo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.medical_services, size: 80, color: Colors.blue.shade700),
        const SizedBox(height: 8),
        const Text(
          'Логотип',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  void dispose() {
    print('🗑️ _AuthWrapperState.dispose(): Очистка состояния');
    _authStateSubscription.cancel();
    super.dispose();
  }
}
