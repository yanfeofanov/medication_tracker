// lib/main.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:medication_tracker/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'utils/keys.dart';

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
    } catch (e, stackTrace) {
      print('❌ ОШИБКА проверки авторизации: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        _isAuthenticated = false;
        _isInitializing = false;
      });
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
            Icon(Icons.medical_services, size: 80, color: Colors.blue.shade700),
            const SizedBox(height: 20),
            const Text(
              'Medication\nTracker',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
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

  @override
  void dispose() {
    print('🗑️ _AuthWrapperState.dispose(): Очистка состояния');
    _authStateSubscription.cancel();
    super.dispose();
  }
}
