// ============================================================
// FILE 1: supabase_service.dart (FULLY UPDATED + SECURITY FIXED)
// ============================================================

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart';

class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;

  // ------------------------------------------------------------
  // UPLOAD PROFILE IMAGE (SAFE)
  // ------------------------------------------------------------
  Future<String?> uploadProfileImage(File? image) async {
    if (image == null) return null;

    try {
      final fileName =
          "profile_${DateTime.now().millisecondsSinceEpoch}_${basename(image.path)}";

      final storage = client.storage.from('profile_images');

      await storage.upload(
        fileName,
        image,
        fileOptions: const FileOptions(upsert: false),
      );

      return storage.getPublicUrl(fileName);
    } catch (e) {
      print("Image upload error: $e");
      return null;
    }
  }

  // ------------------------------------------------------------
  // CREATE USER PROFILE (SECURE + LINKS TO AUTH.user.id)
  // ------------------------------------------------------------
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
    final authUser = client.auth.currentUser;

    if (authUser == null) {
      throw "No authenticated user found when creating profile.";
    }

    await client.from('users').insert({
      'user_id': authUser.id, // Link to Supabase Auth
      'name': name,
      'email': email,
      'role': role,
      'profile_image': profileImage,
      'department': department,
      'bio': bio,
      'academic_year': academicYear,
      'location': location,
    });
  }

  // ------------------------------------------------------------
  // GET USER BY EMAIL
  // ------------------------------------------------------------
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    return await client
        .from('users')
        .select()
        .eq('email', email)
        .maybeSingle();
  }
}
