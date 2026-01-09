import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth state provider
final authProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((event) {
    return event.session?.user;
  });
});

/// Auth notifier for login/signup/logout actions
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  final _supabase = Supabase.instance.client;

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Sign up the user - profile is auto-created by database trigger
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username}, // Passed to trigger via raw_user_meta_data
      );

      if (response.user == null) {
        state = AsyncValue.error('Sign up failed', StackTrace.current);
        return false;
      }

      state = const AsyncValue.data(null);
      return true;
    } on AuthException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        state = AsyncValue.error('Sign in failed', StackTrace.current);
        return false;
      }

      state = const AsyncValue.data(null);
      return true;
    } on AuthException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _supabase.auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }
}
