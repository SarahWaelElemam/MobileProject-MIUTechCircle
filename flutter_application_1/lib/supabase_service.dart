// ============================================================
// FILE: supabase_service.dart
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;

  // ============================================================
  // CREATE USER PROFILE IN public.users
  // ============================================================
  Future<void> createUserProfile({
    required String name,
    required String email,
    required String role,
    String? profileImage,
    required String department,
    required String bio,
    required int academicYear,
    String? location,
  }) async {
    // Get current auth user ID
    final authUserId = client.auth.currentUser?.id;

    // Check if user already exists
    final existing = await client
        .from('users')
        .select('email')
        .eq('email', email)
        .maybeSingle();

    if (existing != null) {
      print("⚠️ User profile already exists for $email");
      return;
    }

    // Insert new user profile
    await client.from('users').insert({
      'name': name,
      'email': email,
      'role': role,
      'profile_image': profileImage,
      'department': department,
      'bio': bio,
      'academic_year': academicYear,
      'location': location,
      'auth_user_id': authUserId,
      'created_at': DateTime.now().toIso8601String(),
    });

    print("✅ User profile created for $email");
  }

  // ============================================================
  // FETCH USER BY EMAIL
  // ============================================================
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final data = await client
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();
      return data;
    } catch (e) {
      print("❌ Error fetching user: $e");
      return null;
    }
  }

  // ============================================================
  // CHECK IF USER EMAIL IS VERIFIED
  // ============================================================
  Future<bool> isEmailVerified() async {
    final user = client.auth.currentUser;
    if (user == null) return false;

    // Refresh session to get latest email_confirmed_at
    await client.auth.refreshSession();
    final refreshedUser = client.auth.currentUser;

    return refreshedUser?.emailConfirmedAt != null;
  }
}