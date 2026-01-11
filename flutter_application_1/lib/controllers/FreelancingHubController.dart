import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/FreelanceProjectModel.dart';
import '../models/FreelanceApplicationModel.dart';
import '../services/ai_service.dart';

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

      if (projectData['company_logo'] != null &&
          projectData['company_logo'].toString().isNotEmpty) {
        insertData['company_logo'] = projectData['company_logo'];
      }

      if (projectData['budget_range'] != null &&
          projectData['budget_range'].toString().isNotEmpty) {
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
          .map(
            (json) =>
                FreelanceProjectModel.fromMap(json as Map<String, dynamic>),
          )
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
          .map(
            (json) =>
                FreelanceProjectModel.fromMap(json as Map<String, dynamic>),
          )
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
            return projectSkills.any(
              (projectSkill) => projectSkill.toLowerCase().contains(
                searchSkill.toLowerCase(),
              ),
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
      await _supabase
          .from('freelance_projects')
          .delete()
          .eq('project_id', projectId);
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting: $e');
      return false;
    }
  }

  static Future<bool> updateProjectStatus(
    String projectId,
    bool isActive,
  ) async {
    try {
      await _supabase
          .from('freelance_projects')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('project_id', projectId);
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
            projects.add(
              FreelanceProjectModel.fromMap(
                projectData as Map<String, dynamic>,
              ),
            );
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

  static Future<List<FreelanceApplicationModel>> fetchUserApplications() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return [];

      // Use applicant_uuid instead of applicant_id
      final data = await _supabase
          .from('freelance_applications')
          .select('*')
          .eq('applicant_uuid', currentUser.id)
          .order('applied_at', ascending: false);

      if (data == null || (data as List).isEmpty) return [];

      return (data as List)
          .map(
            (json) =>
                FreelanceApplicationModel.fromMap(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ Error: $e');
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

      // Fetch the REAL user ID from 'users' table using auth UUID
      int? numericUserId;
      String? userName;
      String? userRole;
      String? userDepartment;
      String? userAcademicYear;
      String? userBio;
      String? userLocation;
      final userEmail = currentUser.email;

      try {
        final userData = await _supabase
            .from('users')
            .select(
              'user_id, name, role, department, academic_year, bio, location',
            )
            .eq('auth_user_id', currentUser.id)
            .maybeSingle();

        if (userData != null) {
          numericUserId = userData['user_id'] as int?;
          userName = userData['name'] as String?;
          userRole = userData['role']?.toString();
          userDepartment = userData['department']?.toString();
          userAcademicYear = userData['academic_year']?.toString();
          userBio = userData['bio']?.toString();
          userLocation = userData['location']?.toString();
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching user profile: $e');
      }

      // Fallback if users table entry doesn't exist (should not happen in normal flow)
      numericUserId ??= currentUser.id.hashCode.abs();

      debugPrint('📊 Project ID (uuid): $projectId');
      debugPrint('📊 User ID (int): $numericUserId');
      debugPrint('📊 User UUID: ${currentUser.id}');

      // Check if already applied using UUID (more reliable) or int ID
      try {
        var query = _supabase
            .from('freelance_applications')
            .select('application_id')
            .eq('project_id', projectId);

        // Check both UUID and int ID if columns exist
        final existing = await query
            .or(
              'applicant_id.eq.$numericUserId,applicant_uuid.eq.${currentUser.id}',
            )
            .maybeSingle();

        if (existing != null) {
          debugPrint('⚠️ User already applied to this project');
          return null;
        }
      } catch (checkError) {
        debugPrint(
          '⚠️ Could not check existing (might be first apply): $checkError',
        );
      }

      debugPrint('✅ No existing application, proceeding with insert...');

      // ---------------------------------------------------------
      // AI Analysis: Calculate Score on Apply
      // ---------------------------------------------------------
      final aiResult = await _calculateApplicationScore(
        projectId: projectId,
        numericUserId: numericUserId,
        introduction: introduction,
        userRole: userRole,
        userDepartment: userDepartment,
        userAcademicYear: userAcademicYear,
        userBio: userBio,
        userLocation: userLocation,
      );

      final double aiScore = aiResult['score'];
      final String aiReason = aiResult['reason'];

      // Insert application
      final insertData = {
        'project_id': projectId,
        'applicant_id': numericUserId,
        'applicant_uuid': currentUser.id, // Store key link!
        'applicant_email': userEmail,
        'applicant_name': userName,
        'introduction': introduction,
        'status': 'pending',
        'applied_at': DateTime.now().toIso8601String(),
        'match_score': aiScore,
        'ai_feedback': aiReason,
      };

      debugPrint('📤 Inserting: $insertData');

      try {
        final result = await _supabase
            .from('freelance_applications')
            .insert(insertData)
            .select()
            .single();

        debugPrint('✅ Application submitted successfully!');

        return FreelanceApplicationModel.fromMap(result);
      } catch (insertError) {
        debugPrint('❌ Insert error: $insertError');

        // Check if the error is just a parsing issue but insert succeeded
        if (insertError.toString().contains('successfully') ||
            insertError.toString().contains('Application submitted')) {
          return FreelanceApplicationModel(
            applicationId: DateTime.now().millisecondsSinceEpoch.toString(),
            projectId: projectId,
            applicantId: numericUserId.toString(),
            applicantUuid: currentUser.id,
            applicantEmail: userEmail,
            applicantName: userName,
            introduction: introduction,
            status: 'pending',
            appliedAt: DateTime.now(),
            matchScore: aiScore,
            aiFeedback: aiReason,
          );
        }

        throw insertError;
      }
    } catch (e) {
      debugPrint('❌ Error submitting application: $e');
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

  // basic Feature without ai : Calculate skill match percentage without ai
  static Future<double> calculateSkillMatchScoreWithoutAI(
    String applicantIdStr,
    List<String> requiredSkills,
  ) async {
    try {
      if (requiredSkills.isEmpty) return 100.0;

      // Support both integer ID and UUID string for flexibility
      dynamic userIdQuery = applicantIdStr;

      // Try to parse to int if it looks like one, otherwise keep as string (UUID)
      final applicantIdInt = int.tryParse(applicantIdStr);
      if (applicantIdInt != null) {
        userIdQuery = applicantIdInt;
      }

      final data = await _supabase
          .from('skills')
          .select('name')
          .eq('user_id', userIdQuery);

      if (data == null || (data as List).isEmpty) {
        debugPrint('⚠️ No skills found for user: $applicantIdStr');
        return 0.0;
      }

      final userSkills = (data as List)
          .map((e) => e['name'].toString().toLowerCase())
          .toList();

      debugPrint('🔍 Comparing Skills for $applicantIdStr:');
      debugPrint('   User Skills: $userSkills');
      debugPrint('   Required: $requiredSkills');

      int matchCount = 0;

      for (var reqSkill in requiredSkills) {
        final reqLower = reqSkill.toLowerCase();
        // Check for fuzzy match
        if (userSkills.any(
          (uSkill) =>
              uSkill == reqLower ||
              uSkill.contains(reqLower) ||
              reqLower.contains(uSkill),
        )) {
          matchCount++;
        }
      }

      // Convert ratio to 5-star scale
      double score = (matchCount / requiredSkills.length) * 5.0;
      debugPrint('✅ Calculated Score: $score/5.0');
      return score;
    } catch (e) {
      debugPrint('❌ Error calculating skill score: \$e');
      return 0.0;
    }
  }

  static Future<Map<String, dynamic>?> recalculateApplicationScore(
    String applicationId,
    String projectId,
    String applicantUuid,
    String introduction,
  ) async {
    try {
      debugPrint('🔄 Recalculating score for App: $applicationId');

      // 1. Fetch User Details to prepare for AI Analysis
      // We need to resolve UUID to Int ID if skills table uses Int ID.
      int? numericUserId;
      String? userRole;
      String? userDepartment;
      String? userAcademicYear;
      String? userBio;
      String? userLocation;

      try {
        final userData = await _supabase
            .from('users')
            .select('user_id, role, department, academic_year, bio, location')
            .eq('auth_user_id', applicantUuid)
            .maybeSingle();

        if (userData != null) {
          numericUserId = userData['user_id'] as int?;
          userRole = userData['role']?.toString();
          userDepartment = userData['department']?.toString();
          userAcademicYear = userData['academic_year']?.toString();
          userBio = userData['bio']?.toString();
          userLocation = userData['location']?.toString();
        }
      } catch (e) {
        // Fallback or ignore
      }

      // 2. Call AI Helper
      final aiResult = await _calculateApplicationScore(
        projectId: projectId,
        numericUserId: numericUserId,
        introduction: introduction,
        userRole: userRole,
        userDepartment: userDepartment,
        userAcademicYear: userAcademicYear,
        userBio: userBio,
        userLocation: userLocation,
      );

      final newScore = aiResult['score'];
      final newFeedback = aiResult['reason'];

      // 4. Update Database
      await _supabase
          .from('freelance_applications')
          .update({'match_score': newScore, 'ai_feedback': newFeedback})
          .eq('application_id', applicationId);

      debugPrint('✅ Score updated to $newScore');
      return {'score': newScore, 'feedback': newFeedback};
    } catch (e) {
      debugPrint('❌ Error recalculating score: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> _calculateApplicationScore({
    required String projectId,
    required int? numericUserId,
    required String introduction,
    required String? userRole,
    required String? userDepartment,
    required String? userAcademicYear,
    required String? userBio,
    required String? userLocation,
  }) async {
    double aiScore = 0.0;
    String aiReason = '';

    try {
      // 1. Fetch Project Details
      final projectData = await _supabase
          .from('freelance_projects')
          .select('skills_needed, description')
          .eq('project_id', projectId)
          .single();

      final projectSkills = List<String>.from(
        projectData['skills_needed'] ?? [],
      );
      final projectDesc = projectData['description']?.toString() ?? '';

      // 2. Fetch User Qualifications
      List<String> userSkills = [];
      List<String> userExperiences = [];
      List<String> userLicenses = [];

      if (numericUserId != null) {
        final qual = await _fetchUserQualifications(numericUserId);
        userSkills = qual['skills']!;
        userExperiences = qual['experiences']!;
        userLicenses = qual['licenses']!;
      }

      // 3. Call AI Service
      debugPrint('🤖 Calling AI Service for analysis...');
      final analysis = await AIService.analyzeApplication(
        userSkills: userSkills,
        userExperiences: userExperiences,
        userLicenses: userLicenses,
        introduction: introduction,
        projectSkills: projectSkills,
        projectDescription: projectDesc,
        userRole: userRole,
        userDepartment: userDepartment,
        userAcademicYear: userAcademicYear,
        userBio: userBio,
        userLocation: userLocation,
      );

      aiScore = analysis['score'] ?? 0.0;
      aiReason = analysis['reason'] ?? '';
      debugPrint('🤖 AI Result: Score=$aiScore, Reason=$aiReason');
    } catch (aiError) {
      debugPrint('⚠️ AI Analysis failed (skipping): $aiError');
    }
    return {'score': aiScore, 'reason': aiReason};
  }

  static Future<Map<String, List<String>>> _fetchUserQualifications(
    int userId,
  ) async {
    List<String> skills = [];
    List<String> experiences = [];
    List<String> licenses = [];

    try {
      // Fetch Skills
      final skillsData = await _supabase
          .from('skills')
          .select('name, proficiency_level, endorsement_info')
          .eq('user_id', userId);

      if (skillsData != null) {
        skills = (skillsData as List).map((e) {
          final name = e['name'].toString();
          final level = e['proficiency_level']?.toString();
          final endorsement = e['endorsement_info']?.toString();
          String str = name;
          if (level != null && level.isNotEmpty) str += ' ($level)';
          if (endorsement != null && endorsement.isNotEmpty) {
            str += ' [Endorsed: $endorsement]';
          }
          return str;
        }).toList();
      }

      // Fetch Experiences
      final expData = await _supabase
          .from('experiences')
          .select('title, company, start_date, end_date, description')
          .eq('user_id', userId)
          .order('start_date', ascending: false);

      if (expData != null) {
        experiences = (expData as List).map((e) {
          final title = e['title'] ?? e['job_title'] ?? 'Role';
          final company = e['company'] ?? e['company_name'] ?? 'Company';
          final start = e['start_date'] ?? 'Unknown';
          final end = e['end_date'] ?? 'Present';
          final desc = e['description'] ?? '';
          return "$title at $company ($start - $end): $desc";
        }).toList();
      }

      // Fetch Licenses
      final licData = await _supabase
          .from('licenses')
          .select('name, issuing_organization, issue_date')
          .eq('user_id', userId)
          .order('issue_date', ascending: false);

      if (licData != null) {
        licenses = (licData as List).map((e) {
          final name = e['name'] ?? 'License';
          final org = e['issuing_organization'] ?? 'Org';
          final date = e['issue_date'] ?? '';
          return "$name from $org ($date)";
        }).toList();
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching user qualifications: $e');
    }

    return {'skills': skills, 'experiences': experiences, 'licenses': licenses};
  }
}
