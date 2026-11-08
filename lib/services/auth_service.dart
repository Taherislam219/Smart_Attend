import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Register a student.
  // The PostgreSQL trigger automatically creates
  // their profile with role = 'student'.
  Future<AuthResponse> registerStudent({
    required String fullName,
    required String universityStudentId,
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'university_student_id': universityStudentId.trim(),
      },
    );
  }

  // 2. Login and verify the user's database role.
  Future<String> login({
    required String email,
    required String password,
  }) async {
    debugPrint('STEP 1: Starting Supabase login');

    final response = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    debugPrint('STEP 2: Supabase Auth login succeeded');

    final user = response.user;

    if (user == null) {
      throw const AuthException('Login failed.');
    }

    try {
      debugPrint('STEP 3: Checking PostgreSQL profile');

      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      debugPrint('STEP 4: PostgreSQL profile loaded');

      final role = profile['role'];

      if (role != 'student' && role != 'teacher') {
        throw const AuthException('Account role is invalid.');
      }

      debugPrint('STEP 5: Account role verified');

      return role as String;
    } on PostgrestException catch (error) {
      debugPrint('DATABASE ERROR: ${error.message}');
      debugPrint('DATABASE CODE: ${error.code}');
      debugPrint('DATABASE DETAILS: ${error.details}');

      await _supabase.auth.signOut();
      rethrow;
    } catch (error) {
      debugPrint('OTHER ERROR: $error');

      await _supabase.auth.signOut();
      rethrow;
    }
  }

  // 3. Logout.
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}
