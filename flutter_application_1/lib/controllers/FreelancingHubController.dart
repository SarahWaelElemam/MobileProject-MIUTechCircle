import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/FreelanceProjectModel.dart';
import '../models/FreelanceApplicationModel.dart';

class FreelancingHubController {
  static final _supabase = Supabase.instance.client;

  static Future<bool> createProject(Map<String, dynamic> projectData) async {
    try {
      debugPrint('🔍 Creating project...');
      
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ Not authenticated');
        return false;
      }

      final insertData = {
        'title': projectData['title'],
        'company_name': projectData['company_name'],
        'description': projectData['description'],
        'skills_needed': projectData['skills_needed'],
        'duration': projectData['duration'],
        'deadline': projectData['deadline'],
        'key_responsibilities': projectData['key_responsibilities'],
        'is_active': true,
        'posted_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      if (projectData['company_logo'] != null && projectData['company_logo'].toString().isNotEmpty) {
        insertData['company_logo'] = projectData['company_logo'];
      }

      if (projectData['budget_range'] != null && projectData['budget_range'].toString().isNotEmpty) {
        insertData['budget_range'] = projectData['budget_range'];
      }

      debugPrint('📤 Inserting: $insertData');

      await _supabase.from('freelance_projects').insert(insertData);

      debugPrint('✅ Success!');
      return true;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }

  static Future<List<FreelanceProjectModel>> fetchAllProjects({
    String sortBy = 'posted_at',
    bool ascending = false,
    bool? isActive,
  }) async {
    try {
      dynamic data;
      
      if (isActive != null) {
        data = await _supabase
            .from('freelance_projects')
            .select('*')
            .eq('is_active', isActive)
            .order(sortBy, ascending: ascending);
      } else {
        data = await _supabase
            .from('freelance_projects')
            .select('*')
            .order(sortBy, ascending: ascending);
      }

      if (data == null || (data as List).isEmpty) {
        return [];
      }

      return (data as List)
          .map((json) => FreelanceProjectModel.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching: $e');
      return [];
    }
  }

  static Future<List<FreelanceProjectModel>> searchProjects({
    String? keyword,
    List<String>? skills,
  }) async {
    try {
      final data = await _supabase
          .from('freelance_projects')
          .select('*')
          .eq('is_active', true)
          .order('posted_at', ascending: false);

      if (data == null || (data as List).isEmpty) {
        return [];
      }

      List<FreelanceProjectModel> projects = (data as List)
          .map((json) => FreelanceProjectModel.fromMap(json as Map<String, dynamic>))
          .toList();

      if (keyword != null && keyword.isNotEmpty) {
        final lowerKeyword = keyword.toLowerCase();
        projects = projects.where((project) {
          final title = project.title.toLowerCase();
          final description = project.description.toLowerCase();
          final companyName = project.companyName.toLowerCase();
          return title.contains(lowerKeyword) || 
                 description.contains(lowerKeyword) || 
                 companyName.contains(lowerKeyword);
        }).toList();
      }

      if (skills != null && skills.isNotEmpty) {
        projects = projects.where((project) {
          final projectSkills = project.skillsNeeded;
          if (projectSkills.isEmpty) return false;
          
          return skills.any((searchSkill) {
            return projectSkills.any((projectSkill) => 
              projectSkill.toLowerCase().contains(searchSkill.toLowerCase())
            );
          });
        }).toList();
      }

      return projects;
    } catch (e) {
      debugPrint('❌ Error searching: $e');
      return [];
    }
  }

  static Future<bool> deleteProject(String projectId) async {
    try {
      await _supabase.from('freelance_projects').delete().eq('project_id', projectId);
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting: $e');
      return false;
    }
  }

  static Future<bool> updateProjectStatus(String projectId, bool isActive) async {
    try {
      await _supabase.from('freelance_projects').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('project_id', projectId);
      return true;
    } catch (e) {
      debugPrint('❌ Error updating: $e');
      return false;
    }
  }

  static Future<List<FreelanceProjectModel>> fetchSavedProjects() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      final savedData = await _supabase
          .from('saved_freelance_projects')
          .select('project_id')
          .eq('user_id', currentUser.id);

      if (savedData == null || (savedData as List).isEmpty) {
        return [];
      }

      final projectIds = (savedData as List)
          .map((item) => item['project_id'] as String)
          .toList();

      if (projectIds.isEmpty) return [];

      List<FreelanceProjectModel> projects = [];
      for (String projectId in projectIds) {
        try {
          final projectData = await _supabase
              .from('freelance_projects')
              .select('*')
              .eq('project_id', projectId)
              .single();

          if (projectData != null) {
            projects.add(FreelanceProjectModel.fromMap(projectData as Map<String, dynamic>));
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching project $projectId: $e');
        }
      }
      return projects;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return [];
    }
  }

  static Future<bool> toggleSaveProject({required String projectId}) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return false;

      final existing = await _supabase
          .from('saved_freelance_projects')
          .select()
          .eq('user_id', currentUser.id)
          .eq('project_id', projectId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('saved_freelance_projects').insert({
          'user_id': currentUser.id,
          'project_id': projectId,
          'saved_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _supabase
            .from('saved_freelance_projects')
            .delete()
            .eq('user_id', currentUser.id)
            .eq('project_id', projectId);
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }

  // ============================================
  // ✅ CRITICAL FIX: FETCH USER APPLICATIONS
  // ============================================
  static Future<List<FreelanceApplicationModel>> fetchUserApplications() async {
    try {
      debugPrint('📥 Fetching user applications...');
      
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ No user logged in');
        return [];
      }

      debugPrint('🔍 User ID: ${currentUser.id}');

      // ✅ FIX: Use consistent column name - check your actual database schema
      // Try both possible column names to be safe
      try {
        // First try with applicant_id (numeric)
        final numericUserId = currentUser.id.hashCode.abs();
        
        final data = await _supabase
            .from('freelance_applications')
            .select('*')
            .eq('applicant_id', numericUserId)
            .order('applied_at', ascending: false);

        if (data != null && (data as List).isNotEmpty) {
          debugPrint('✅ Found ${(data as List).length} applications using applicant_id');
          return (data as List)
              .map((json) => FreelanceApplicationModel.fromMap(json as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('⚠️ Failed with applicant_id: $e');
      }

      // If that fails, try with applicant_uuid
      try {
        final data = await _supabase
            .from('freelance_applications')
            .select('*')
            .eq('applicant_uuid', currentUser.id)
            .order('applied_at', ascending: false);

        if (data != null && (data as List).isNotEmpty) {
          debugPrint('✅ Found ${(data as List).length} applications using applicant_uuid');
          return (data as List)
              .map((json) => FreelanceApplicationModel.fromMap(json as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('⚠️ Failed with applicant_uuid: $e');
      }

      debugPrint('📊 No applications found for user');
      return [];
      
    } catch (e) {
      debugPrint('❌ Error fetching applications: $e');
      return [];
    }
  }

  static Future<int> getApplicationCount(String projectId) async {
    try {
      final data = await _supabase
          .from('freelance_applications')
          .select('application_id')
          .eq('project_id', projectId);

      if (data == null) return 0;
      return (data as List).length;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return 0;
    }
  }

  // ============================================
  // ✅ CRITICAL FIX: SUBMIT APPLICATION
  // ============================================
  static Future<FreelanceApplicationModel?> submitApplication({
    required String projectId,
    required String introduction,
  }) async {
    try {
      debugPrint('🔍 Starting application submission...');
      
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ User not authenticated');
        return null;
      }

      debugPrint('✅ User authenticated: ${currentUser.id}');

      // Convert user ID to numeric
      final numericUserId = currentUser.id.hashCode.abs();

      debugPrint('📊 Project ID: $projectId');
      debugPrint('📊 Numeric User ID: $numericUserId');

      // Check if already applied
      try {
        final existing = await _supabase
            .from('freelance_applications')
            .select('application_id')
            .eq('project_id', projectId)
            .eq('applicant_id', numericUserId)
            .maybeSingle();

        if (existing != null) {
          debugPrint('⚠️ User already applied to this project');
          return null;
        }
      } catch (checkError) {
        debugPrint('⚠️ Could not check existing: $checkError');
      }

      debugPrint('✅ No existing application, proceeding with insert...');

      // ✅ FIX: Use consistent column name - applicant_id (numeric)
      final insertData = {
        'project_id': projectId,
        'applicant_id': numericUserId,  // Using numeric ID
        'introduction': introduction,
        'status': 'pending',
        'applied_at': DateTime.now().toIso8601String(),
      };

      debugPrint('📤 Inserting: $insertData');

      final result = await _supabase
          .from('freelance_applications')
          .insert(insertData)
          .select()
          .single();

      debugPrint('✅ Application submitted successfully!');
      debugPrint('📊 Result: $result');
      
      return FreelanceApplicationModel.fromMap(result);
      
    } catch (e) {
      debugPrint('❌ Error submitting application: $e');
      
      // If it's a duplicate key error, return null
      if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
        debugPrint('⚠️ Duplicate application detected');
        return null;
      }
      
      return null;
    }
  }

  static Future<bool> withdrawApplication(String applicationId) async {
    try {
      await _supabase
          .from('freelance_applications')
          .update({'status': 'withdrawn'})
          .eq('application_id', applicationId);
      return true;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }
}