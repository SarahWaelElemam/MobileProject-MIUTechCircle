import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'manage_users_page.dart';
import 'manage_posts_page.dart';
import 'manage_projects_page.dart';
import 'manage_events_page.dart';
import 'manage_opportunities_page.dart';
import 'manage_freelancing_page.dart';
import 'admin_reports_page.dart';
import 'manage_applications_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _totalUsers = 0;
  int _totalPosts = 0;
  int _totalProjects = 0;
  int _totalFreelanceProjects = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      int usersCount = 0;
      try {
        final usersData = await Supabase.instance.client
            .from('users')
            .select('id');
        usersCount = (usersData as List).length;
      } catch (e) {
        debugPrint('Error counting users: $e');
      }

      int postsCount = 0;
      try {
        final postsData = await Supabase.instance.client
            .from('posts')
            .select('id');
        postsCount = (postsData as List).length;
      } catch (e) {
        debugPrint('Error counting posts: $e');
      }

      int projectsCount = 0;
      try {
        final projectsData = await Supabase.instance.client
            .from('projects')
            .select('id');
        projectsCount = (projectsData as List).length;
      } catch (e) {
        debugPrint('Error counting projects: $e');
      }

      int freelanceCount = 0;
      try {
        final freelanceData = await Supabase.instance.client
            .from('freelance_projects')
            .select('project_id');
        freelanceCount = (freelanceData as List).length;
      } catch (e) {
        debugPrint('Error counting freelance projects: $e');
      }

      setState(() {
        _totalUsers = usersCount;
        _totalPosts = postsCount;
        _totalProjects = projectsCount;
        _totalFreelanceProjects = freelanceCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
      setState(() {
        _errorMessage = 'Failed to load statistics';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh Statistics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Users',
                            _totalUsers.toString(),
                            Icons.people,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Posts',
                            _totalPosts.toString(),
                            Icons.article,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Projects',
                            _totalProjects.toString(),
                            Icons.school,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Freelance',
                            _totalFreelanceProjects.toString(),
                            Icons.work,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    const Text(
                      'Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildManagementOption(
                      'Manage Users',
                      'View and manage all registered users',
                      Icons.people_outline,
                      Colors.blue,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageUsersPage(),
                          ),
                        );
                        _loadStats();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildManagementOption(
                      'Manage Posts',
                      'Moderate and manage user posts',
                      Icons.article_outlined,
                      Colors.green,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManagePostsPage(),
                          ),
                        );
                        _loadStats();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildManagementOption(
                      'Manage Projects',
                      'Oversee graduation projects',
                      Icons.school_outlined,
                      Colors.orange,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageProjectsPage(),
                          ),
                        );
                        _loadStats();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildManagementOption(
                      'Manage Freelancing Hub',
                      'Post and manage freelance projects',
                      Icons.work_outline,
                      Colors.red,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageFreelancingPage(),
                          ),
                        );
                        _loadStats();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildManagementOption(
                      'View Applications',
                      'View all freelance project applications',
                      Icons.assignment_ind_outlined,
                      Colors.deepPurple,
                      () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageApplicationsPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildManagementOption(
                      'Manage Events',
                      'Create and manage events',
                      Icons.event_outlined,
                      Colors.purple,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageEventsPage(),
                          ),
                        );
                        _loadStats();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildManagementOption(
                      'Manage Opportunities',
                      'Job and internship postings',
                      Icons.business_center_outlined,
                      Colors.teal,
                      () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageOpportunitiesPage(),
                          ),
                        );
                        _loadStats();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildManagementOption(
                      'Admin Reports',
                      'View analytics and reports',
                      Icons.assessment_outlined,
                      Colors.indigo,
                      () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminReportsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Future<void> Function() onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }
}