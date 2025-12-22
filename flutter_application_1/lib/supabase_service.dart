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
    String? coverImage,
    required String department,
    required String bio,
    required int academicYear,
    String? location,
  }) async {
    final authUserId = client.auth.currentUser?.id;

    final existing = await client
        .from('users')
        .select('email')
        .eq('email', email)
        .maybeSingle();

    if (existing != null) {
      print("⚠️ User profile already exists for $email");
      return;
    }

    await client.from('users').insert({
      'name': name,
      'email': email,
      'role': role,
      'profile_image': profileImage,
      'cover_image': coverImage,
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

    await client.auth.refreshSession();
    final refreshedUser = client.auth.currentUser;

    return refreshedUser?.emailConfirmedAt != null;
  }

  // ============================================================
  // GET TOTAL USERS COUNT (SIMPLIFIED - NO ERRORS)
  // ============================================================
  Future<int> getTotalUsersCount() async {
    try {
      final data = await client.from('users').select('user_id');
      return (data as List).length;
    } catch (e) {
      print("❌ Error getting users count: $e");
      return 0;
    }
  }

  // ============================================================
  // GET ALL USERS
  // ============================================================
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final data = await client
          .from('users')
          .select()
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("❌ Error fetching users: $e");
      return [];
    }
  }

  // ============================================================
  // DELETE USER
  // ============================================================
  Future<void> deleteUser(int userId) async {
    try {
      await client.from('users').delete().eq('user_id', userId);
      print("✅ User deleted successfully");
    } catch (e) {
      print("❌ Error deleting user: $e");
      throw e;
    }
  }

  // ============================================================
  // UPDATE USER PROFILE
  // ============================================================
  Future<void> updateUserProfile({
    required String email,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await client.from('users').update(updates).eq('email', email);
      print("✅ User profile updated for $email");
    } catch (e) {
      print("❌ Error updating user: $e");
      throw e;
    }
  }
}