import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/FreelanceProjectModel.dart';
import '../../models/FreelanceApplicationModel.dart';

class ProjectApplicationsPage extends StatefulWidget {
  final FreelanceProjectModel project;
  
  const ProjectApplicationsPage({
    super.key,
    required this.project,
  });

  @override
  State<ProjectApplicationsPage> createState() => _ProjectApplicationsPageState();
}

class _ProjectApplicationsPageState extends State<ProjectApplicationsPage> {
  List<FreelanceApplicationModel> _applications = [];
  Map<String, Map<String, dynamic>> _applicantDetails = {};  // applicant_id -> user details
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('📥 Loading applications for project: ${widget.project.projectId}');

      // Fetch applications for THIS project only
      final data = await Supabase.instance.client
          .from('freelance_applications')
          .select('*')
          .eq('project_id', widget.project.projectId)
          .order('applied_at', ascending: false);

      if (data == null || (data as List).isEmpty) {
        setState(() {
          _applications = [];
          _isLoading = false;
        });
        return;
      }

      // Parse applications
      final applications = (data as List)
          .map((json) => FreelanceApplicationModel.fromMap(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Found ${applications.length} applications');

      // Load user details for each applicant
      for (final app in applications) {
        try {
          // ✅ FIX: Use applicant_uuid to get actual user details
          // applicant_uuid should contain the user's UUID
          String userUuid = app.applicantId;
          
          // If applicant_id is numeric, try to get from applicant_uuid field
          final appData = (data as List).firstWhere(
            (item) => item['application_id']?.toString() == app.applicationId,
            orElse: () => null,
          );
          
          if (appData != null && appData['applicant_uuid'] != null) {
            userUuid = appData['applicant_uuid'].toString();
          }
          
          debugPrint('🔍 Fetching user details for UUID: $userUuid');
          
          final userData = await Supabase.instance.client
              .from('users')
              .select('user_id, full_name, email, profile_picture, bio, skills')
              .eq('user_id', userUuid)
              .maybeSingle();

          if (userData != null) {
            debugPrint('✅ Loaded user: ${userData['full_name']}');
            _applicantDetails[app.applicantId] = {
              'full_name': userData['full_name'] ?? 'Unknown User',
              'email': userData['email'] ?? '',
              'profile_picture': userData['profile_picture'],
              'bio': userData['bio'],
              'skills': userData['skills'] ?? [],
            };
          } else {
            debugPrint('⚠️ User not found for UUID: $userUuid');
            _applicantDetails[app.applicantId] = {
              'full_name': 'User Not Found',
              'email': '',
              'profile_picture': null,
              'bio': null,
              'skills': [],
            };
          }
        } catch (e) {
          debugPrint('⚠️ Could not load details for applicant ${app.applicantId}: $e');
          _applicantDetails[app.applicantId] = {
            'full_name': 'User ${app.applicantId}',
            'email': '',
            'profile_picture': null,
            'bio': null,
            'skills': [],
          };
        }
      }

      setState(() {
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading applications: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateApplicationStatus(
    FreelanceApplicationModel application,
    String newStatus,
  ) async {
    try {
      await Supabase.instance.client
          .from('freelance_applications')
          .update({
            'status': newStatus,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('application_id', application.applicationId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Application ${newStatus == 'accepted' ? 'accepted' : 'rejected'}'),
          backgroundColor: newStatus == 'accepted' ? Colors.green : Colors.red,
        ),
      );

      // Reload applications
      _loadApplications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Applications',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              widget.project.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading applications',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadApplications,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : _applications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No applications yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Applications will appear here when users apply',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadApplications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _applications.length,
                        itemBuilder: (context, index) {
                          final application = _applications[index];
                          final userDetails = _applicantDetails[application.applicantId] ?? {
                            'full_name': 'Unknown User',
                            'email': '',
                            'profile_picture': null,
                            'bio': null,
                            'skills': [],
                          };
                          
                          return _buildApplicationCard(application, userDetails);
                        },
                      ),
                    ),
    );
  }

  Widget _buildApplicationCard(
    FreelanceApplicationModel application,
    Map<String, dynamic> userDetails,
  ) {
    Color statusColor;
    IconData statusIcon;
    
    switch (application.status) {
      case 'accepted':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'withdrawn':
        statusColor = Colors.grey;
        statusIcon = Icons.remove_circle;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Profile Picture
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.deepPurple[100],
                  backgroundImage: userDetails['profile_picture'] != null
                      ? NetworkImage(userDetails['profile_picture'])
                      : null,
                  child: userDetails['profile_picture'] == null
                      ? Text(
                          (userDetails['full_name'] as String).isNotEmpty
                              ? (userDetails['full_name'] as String)[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userDetails['full_name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (userDetails['email'] != null && userDetails['email'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            userDetails['email'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Applied ${_timeAgo(application.appliedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        application.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Introduction
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Introduction',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  application.introduction,
                  style: const TextStyle(fontSize: 14),
                ),
                
                // Bio (if available)
                if (userDetails['bio'] != null && userDetails['bio'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Bio',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userDetails['bio'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],

                // Skills (if available)
                if (userDetails['skills'] != null && (userDetails['skills'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Skills',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (userDetails['skills'] as List).map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          skill.toString(),
                          style: const TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // Action Buttons (only for pending applications)
          if (application.status == 'pending')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateApplicationStatus(application, 'rejected'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text(
                        'Reject',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateApplicationStatus(application, 'accepted'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text(
                        'Accept',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}