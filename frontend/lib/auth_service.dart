import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign in with email
  Future<AuthResponse> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign up with email
  Future<UserResponse> signUpWithEmailPassword(
    String email,
    String password,
    String username,
  ) async {
    await _supabase.auth.signUp(email: email, password: password);
    return await _supabase.auth.updateUser(
      UserAttributes(data: {'display_name': username}),
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  String? getCurrentEmail() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }
}
