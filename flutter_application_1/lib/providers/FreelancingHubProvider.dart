import 'package:flutter/foundation.dart';
import '../models/FreelanceProjectModel.dart';
import '../models/FreelanceApplicationModel.dart';
import '../controllers/FreelancingHubController.dart';

class FreelancingHubProvider with ChangeNotifier {
  // Projects
  List<FreelanceProjectModel> _projects = [];
  bool _isLoadingProjects = false;
  String? _projectsError;

  // Saved projects
  final Set<String> _savedProjectIds = {};  // UUID as String

  // Applications
  final Map<String, FreelanceApplicationModel> _userApplications = {}; // projectId -> application
  final Map<String, int> _applicationCounts = {}; // projectId -> count

  // Initialization state
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Getters
  List<FreelanceProjectModel> get projects => _projects;
  bool get isLoadingProjects => _isLoadingProjects;
  String? get projectsError => _projectsError;
  
  bool isProjectSaved(String projectId) => _savedProjectIds.contains(projectId);
  
  bool hasApplied(String projectId) {
    final result = _userApplications.containsKey(projectId);
    debugPrint('🔍 hasApplied($projectId): $result');
    return result;
  }
  
  FreelanceApplicationModel? getApplication(String projectId) => _userApplications[projectId];
  int getApplicationCount(String projectId) => _applicationCounts[projectId] ?? 0;

  // ============================================
  // 🚀 INITIALIZE - CALL THIS WHEN USER LOGS IN OR SCREEN LOADS
  // ============================================
  
  Future<void> initialize() async {
    debugPrint('🚀 Initializing FreelancingHubProvider...');
    
    try {
      // Load everything in parallel
      await Future.wait([
        loadProjects(),
        loadSavedProjects(),
        loadUserApplications(),  // ✅ CRITICAL: Load user's applications
      ]);
      
      _isInitialized = true;
      debugPrint('✅ FreelancingHubProvider initialized successfully');
      debugPrint('📊 Projects: ${_projects.length}');
      debugPrint('📊 Saved: ${_savedProjectIds.length}');
      debugPrint('📊 Applications: ${_userApplications.length}');
      
    } catch (e) {
      debugPrint('❌ Error initializing: $e');
      _isInitialized = false;
    }
    
    notifyListeners();
  }

  // ============================================
  // LOAD PROJECTS
  // ============================================

  Future<void> loadProjects({String sortBy = 'posted_at', bool ascending = false}) async {
    _isLoadingProjects = true;
    _projectsError = null;
    notifyListeners();

    try {
      _projects = await FreelancingHubController.fetchAllProjects(
        sortBy: sortBy,
        ascending: ascending,
      );
      
      debugPrint('✅ Loaded ${_projects.length} projects');
      
      // Load application counts for all projects
      if (_projects.isNotEmpty) {
        await loadApplicationCounts(_projects.map((p) => p.projectId).toList());
      }
      
      _projectsError = null;
    } catch (e) {
      _projectsError = e.toString();
      debugPrint('❌ Error loading projects in provider: $e');
    } finally {
      _isLoadingProjects = false;
      notifyListeners();
    }
  }

  Future<void> searchProjects({String? keyword, List<String>? skills}) async {
    _isLoadingProjects = true;
    _projectsError = null;
    notifyListeners();

    try {
      _projects = await FreelancingHubController.searchProjects(
        keyword: keyword,
        skills: skills,
      );
      
      // Load application counts for search results
      if (_projects.isNotEmpty) {
        await loadApplicationCounts(_projects.map((p) => p.projectId).toList());
      }
      
      _projectsError = null;
    } catch (e) {
      _projectsError = e.toString();
      debugPrint('❌ Error searching projects: $e');
    } finally {
      _isLoadingProjects = false;
      notifyListeners();
    }
  }

  // ============================================
  // ADMIN: CREATE PROJECT
  // ============================================

  Future<bool> createProject(Map<String, dynamic> projectData) async {
    try {
      final success = await FreelancingHubController.createProject(projectData);
      
      if (success) {
        // Reload projects to get the new one
        await loadProjects();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error creating project: $e');
      return false;
    }
  }

  // ============================================
  // ADMIN: DELETE PROJECT
  // ============================================

  Future<bool> deleteProject(String projectId) async {
    try {
      final success = await FreelancingHubController.deleteProject(projectId);
      
      if (success) {
        // Remove from local list
        _projects.removeWhere((p) => p.projectId == projectId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting project: $e');
      return false;
    }
  }

  // ============================================
  // ADMIN: TOGGLE PROJECT STATUS
  // ============================================

  Future<bool> toggleProjectStatus(String projectId) async {
    try {
      final project = _projects.firstWhere((p) => p.projectId == projectId);
      final newStatus = !project.isActive;
      
      final success = await FreelancingHubController.updateProjectStatus(
        projectId,
        newStatus,
      );
      
      if (success) {
        // Update local list
        final index = _projects.indexWhere((p) => p.projectId == projectId);
        if (index != -1) {
          _projects[index] = project.copyWith(isActive: newStatus);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error toggling project status: $e');
      return false;
    }
  }

  // ============================================
  // SAVED PROJECTS
  // ============================================

  Future<void> loadSavedProjects() async {
    try {
      final savedProjects = await FreelancingHubController.fetchSavedProjects();
      _savedProjectIds.clear();
      _savedProjectIds.addAll(savedProjects.map((p) => p.projectId));
      debugPrint('✅ Loaded ${_savedProjectIds.length} saved projects');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading saved projects: $e');
    }
  }

  Future<void> toggleSaveProject({
    required String projectId,
  }) async {
    try {
      final success = await FreelancingHubController.toggleSaveProject(
        projectId: projectId,
      );

      if (success) {
        if (_savedProjectIds.contains(projectId)) {
          _savedProjectIds.remove(projectId);
        } else {
          _savedProjectIds.add(projectId);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error toggling save: $e');
    }
  }

  // ============================================
  // APPLICATIONS - CRITICAL FOR PERSISTENCE
  // ============================================

  /// ✅ CRITICAL METHOD: Loads all applications for the current user
  /// This is what makes applications persist across login sessions
  Future<void> loadUserApplications() async {
    try {
      debugPrint('📥 Loading user applications from database...');
      
      final applications = await FreelancingHubController.fetchUserApplications();
      
      _userApplications.clear();
      for (final app in applications) {
        _userApplications[app.projectId] = app;
        debugPrint('  ✓ Application: Project ${app.projectId} - Status: ${app.status}');
      }
      
      debugPrint('✅ Loaded ${applications.length} user applications');
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Error loading user applications: $e');
    }
  }

  Future<void> loadApplicationCounts(List<String> projectIds) async {
    try {
      for (final projectId in projectIds) {
        final count = await FreelancingHubController.getApplicationCount(projectId);
        _applicationCounts[projectId] = count;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading application counts: $e');
    }
  }

  Future<bool> submitApplication({
    required String projectId,
    required String introduction,
  }) async {
    try {
      debugPrint('📤 Submitting application for project: $projectId');
      
      final application = await FreelancingHubController.submitApplication(
        projectId: projectId,
        introduction: introduction,
      );

      if (application != null) {
        _userApplications[projectId] = application;
        
        // Update application count
        _applicationCounts[projectId] = (_applicationCounts[projectId] ?? 0) + 1;
        
        debugPrint('✅ Application submitted and saved to state');
        notifyListeners();
        return true;
      }
      
      debugPrint('❌ Failed to submit application');
      return false;
      
    } catch (e) {
      debugPrint('❌ Error submitting application: $e');
      return false;
    }
  }

  Future<bool> withdrawApplication(String projectId) async {
    try {
      final application = _userApplications[projectId];
      if (application == null) return false;

      final success = await FreelancingHubController.withdrawApplication(
        application.applicationId,
      );

      if (success) {
        _userApplications[projectId] = application.copyWith(status: 'withdrawn');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error withdrawing application: $e');
      return false;
    }
  }

  // ============================================
  // REFRESH
  // ============================================

  Future<void> refreshAll() async {
    debugPrint('🔄 Refreshing all data...');
    await Future.wait([
      loadProjects(),
      loadSavedProjects(),
      loadUserApplications(),  // ✅ Always reload applications on refresh
    ]);
  }

  // ============================================
  // RESET - Call this on logout
  // ============================================
  
  void reset() {
    debugPrint('🧹 Resetting FreelancingHubProvider state');
    _projects.clear();
    _savedProjectIds.clear();
    _userApplications.clear();
    _applicationCounts.clear();
    _isInitialized = false;
    _isLoadingProjects = false;
    _projectsError = null;
    notifyListeners();
  }
}