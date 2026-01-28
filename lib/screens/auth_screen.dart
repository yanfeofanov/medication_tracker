// lib/screens/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart'; // ← ДОБАВИТЬ ЭТОТ ИМПОРТ
import '../services/supabase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    print(
      '🔄 AuthScreen._submit(): Начало ${_isSignUp ? 'регистрации' : 'входа'}',
    );

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isSignUp) {
        print('📝 Регистрация пользователя: $email');
        await SupabaseService.signUp(email, password);

        Get.snackbar(
          'Успешно',
          'Регистрация завершена. Проверьте почту для подтверждения.',
          colorText: Colors.white,
          backgroundColor: Colors.green,
          snackPosition: SnackPosition.BOTTOM,
        );

        // После успешной регистрации переключаем на вход
        setState(() {
          _isSignUp = false;
          _passwordController.clear();
        });

        print('✅ Регистрация успешна, переключение на форму входа');
      } else {
        print('🔑 Вход пользователя: $email');
        await SupabaseService.signIn(email, password);

        print('✅ Вход успешен, пользователь будет перенаправлен автоматически');
      }
    } catch (e) {
      print('❌ Ошибка ${_isSignUp ? 'регистрации' : 'входа'}: $e');

      String errorMessage = 'Произошла ошибка';
      if (e.toString().contains('Invalid login credentials')) {
        errorMessage = 'Неверный email или пароль';
      } else if (e.toString().contains('already registered')) {
        errorMessage = 'Пользователь уже зарегистрирован';
      } else if (e.toString().contains('weak password')) {
        errorMessage = 'Пароль слишком слабый. Используйте минимум 6 символов';
      }

      Get.snackbar(
        'Ошибка',
        errorMessage,
        colorText: Colors.white,
        backgroundColor: Colors.red,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        print(
          '🔄 AuthScreen._submit(): Завершение ${_isSignUp ? 'регистрации' : 'входа'}',
        );
      }
    }
  }

  // Метод для проверки существования asset
  Future<bool> _checkAssetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Можно проверить assets при инициализации
    _checkAssets();
  }

  Future<void> _checkAssets() async {
    print('🔍 Проверка assets...');
    final assets = ['assets/images/logo.png', 'assets/icon/icon.png'];

    for (final asset in assets) {
      final exists = await _checkAssetExists(asset);
      print('${exists ? '✅' : '❌'} $asset');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ AuthScreen.build(): Построение экрана авторизации');

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Логотип
                _buildAuthLogo(),
                const SizedBox(height: 20),

                // Заголовок
                Text(
                  _isSignUp ? 'Регистрация' : 'Вход',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  _isSignUp
                      ? 'Создайте аккаунт для отслеживания медикаментов'
                      : 'Войдите в свой аккаунт',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 40),

                // Поле email
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Введите корректный email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Поле пароля
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите пароль';
                    }
                    if (value.length < 6) {
                      return 'Пароль должен быть не менее 6 символов';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Кнопка отправки
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isSignUp ? 'Зарегистрироваться' : 'Войти',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 20),

                // Переключение между входом и регистрацией
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp ? 'Уже есть аккаунт?' : 'Нет аккаунта?',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isSignUp = !_isSignUp;
                                _passwordController.clear();
                              });
                            },
                      child: Text(
                        _isSignUp ? 'Войти' : 'Зарегистрироваться',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthLogo() {
    return Column(
      children: [
        // Контейнер для логотипа
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Center(child: _loadLogoImage()),
        ),
        // Текст отладки под логотипом
        FutureBuilder<bool>(
          future: _checkAssetExists('assets/images/logo.png'),
          builder: (context, snapshot) {
            if (snapshot.hasData && !snapshot.data!) {
              return const Text(
                'Файл не найден, используется fallback',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.red),
              );
            }
            return Container();
          },
        ),
      ],
    );
  }

  Widget _loadLogoImage() {
    try {
      return Image.asset(
        'assets/images/logo.png',
        width: 70,
        height: 70,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          print('❌ AuthScreen: Ошибка загрузки логотипа: $error');
          print('Stack trace: $stackTrace');
          return _buildFallbackLogo();
        },
      );
    } catch (e) {
      print('❌ AuthScreen: Исключение при загрузке логотипа: $e');
      return _buildFallbackLogo();
    }
  }

  Widget _buildFallbackLogo() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(35),
      ),
      child: Icon(
        Icons.medical_services,
        size: 40,
        color: Theme.of(context).primaryColor,
      ),
    );
  }
}
