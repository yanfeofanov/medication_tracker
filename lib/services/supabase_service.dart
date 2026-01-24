// lib/services/supabase_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static bool get isAuthenticated {
    final hasSession = client.auth.currentSession != null;
    print('🔐 SupabaseService.isAuthenticated: $hasSession');
    return hasSession;
  }

  static String? get userId {
    final id = client.auth.currentUser?.id;
    print('👤 SupabaseService.userId: ${id ?? "null"}');
    return id;
  }

  static String? get userEmail {
    return client.auth.currentUser?.email;
  }

  // Получение профиля пользователя
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return response;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Выход из системы
  static Future<void> signOut() async {
    print('🚪 SupabaseService.signOut(): Выход из системы');
    await client.auth.signOut();
  }

  // Регистрация
  static Future<void> signUp(String email, String password) async {
    print('📝 SupabaseService.signUp(): Регистрация для $email');
    await client.auth.signUp(email: email, password: password);
  }

  // Вход
  static Future<void> signIn(String email, String password) async {
    print('🔑 SupabaseService.signIn(): Вход для $email');
    await client.auth.signInWithPassword(email: email, password: password);
  }

  // Проверка текущей сессии
  static Future<bool> hasValidSession() async {
    try {
      final session = client.auth.currentSession;
      return session != null;
    } catch (e) {
      return false;
    }
  }

  // Получение состояния авторизации в реальном времени
  static Stream<AuthState> get authStateChanges {
    return client.auth.onAuthStateChange;
  }
}
