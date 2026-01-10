import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManageAnnouncementsPage extends StatefulWidget {
  const ManageAnnouncementsPage({super.key});

  @override
  State<ManageAnnouncementsPage> createState() => _ManageAnnouncementsPageState();
}

class _ManageAnnouncementsPageState extends State<ManageAnnouncementsPage> {
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _categories = [];
  Map<int, Map<String, dynamic>> _userCache = {};
  Map<int, String> _categoryCache = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select()
          .order('name');

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
      });

      for (var cat in _categories) {
        _categoryCache[cat['category_id'] as int] = cat['name'] as String;
      }

      _loadAnnouncements();
    } catch (e) {
      debugPrint('❌ Error loading categories: $e');
      _loadAnnouncements();
    }
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✅ Select all announcements (no category filtering)
      final response = await Supabase.instance.client
          .from('announcement')
          .select('*')
          .order('date', ascending: false)
          .order('time', ascending: false);

      List<Map<String, dynamic>> announcements = List<Map<String, dynamic>>.from(response);

      // Fetch user details
      Set<int> authorIds = announcements
          .where((e) => e['auth_id'] != null)
          .map((e) => e['auth_id'] as int)
          .toSet();
      
      for (int authorId in authorIds) {
        if (!_userCache.containsKey(authorId)) {
          try {
            final userResponse = await Supabase.instance.client
                .from('users')
                .select()
                .eq('user_id', authorId)
                .maybeSingle();

            if (userResponse != null) {
              _userCache[authorId] = userResponse;
            }
          } catch (e) {
            debugPrint('⚠️ Could not load user $authorId: $e');
            _userCache[authorId] = {
              'user_id': authorId,
              'full_name': 'User $authorId',
              'email': '',
            };
          }
        }
      }

      // Filter by time
      if (_filterType == 'upcoming') {
        announcements = announcements.where((announcement) {
          if (announcement['date'] == null) return false;
          final eventDate = DateTime.parse(announcement['date']);
          return eventDate.isAfter(DateTime.now()) ||
              eventDate.isAtSameMomentAs(DateTime.now());
        }).toList();
      } else if (_filterType == 'past') {
        announcements = announcements.where((announcement) {
          if (announcement['date'] == null) return false;
          final eventDate = DateTime.parse(announcement['date']);
          return eventDate.isBefore(DateTime.now());
        }).toList();
      }

      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });

      debugPrint('✅ Loaded ${_announcements.length} announcements');
    } catch (e) {
      debugPrint('❌ Error loading announcements: $e');
      setState(() {
        _errorMessage = 'Failed to load announcements: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAnnouncement(int announcementId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Announcement'),
        content: const Text(
          'Are you sure you want to delete this announcement? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('announcement')
            .delete()
            .eq('announcement_id', announcementId);

        setState(() {
          _announcements.removeAt(index);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Announcement deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ✅ NEW: Show dialog to create or edit announcement
  Future<void> _showAnnouncementDialog([Map<String, dynamic>? announcement]) async {
    final isEditing = announcement != null;
    final titleController = TextEditingController(text: announcement?['title'] ?? '');
    final descriptionController = TextEditingController(text: announcement?['description'] ?? '');
    final dateController = TextEditingController(
      text: announcement?['date'] ?? DateTime.now().toIso8601String().split('T')[0],
    );
    final timeController = TextEditingController(text: announcement?['time'] ?? '09:00:00');
    int? selectedCategoryId = announcement?['category_id'] as int?;
    DateTime selectedDate = announcement?['date'] != null 
        ? DateTime.parse(announcement!['date'])
        : DateTime.now();
    TimeOfDay selectedTime = announcement?['time'] != null
        ? TimeOfDay.fromDateTime(DateFormat('HH:mm:ss').parse(announcement!['time']))
        : TimeOfDay.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEditing ? 'Edit Announcement' : 'New Announcement'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Category Dropdown
                  DropdownButtonFormField<int>(
                    value: selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem<int>(
                        value: cat['category_id'] as int,
                        child: Text(cat['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategoryId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Date Picker
                  TextFormField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() {
                          selectedDate = date;
                          dateController.text = date.toIso8601String().split('T')[0];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Time Picker
                  TextFormField(
                    controller: timeController,
                    decoration: const InputDecoration(
                      labelText: 'Time *',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedTime = time;
                          timeController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a title'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a category'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  // Get current user ID
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user == null) {
                    throw Exception('No user logged in');
                  }

                  // Get user_id from users table
                  final userResponse = await Supabase.instance.client
                      .from('users')
                      .select('user_id')
                      .eq('auth_uuid', user.id)
                      .maybeSingle();

                  if (userResponse == null) {
                    throw Exception('User not found in database');
                  }

                  final userId = userResponse['user_id'] as int;

                  final announcementData = {
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'date': dateController.text,
                    'time': timeController.text,
                    'category_id': selectedCategoryId,
                    'auth_id': userId,
                  };

                  if (isEditing) {
                    // Update existing announcement
                    await Supabase.instance.client
                        .from('announcement')
                        .update(announcementData)
                        .eq('announcement_id', announcement['announcement_id']);
                  } else {
                    // Create new announcement
                    await Supabase.instance.client
                        .from('announcement')
                        .insert(announcementData);
                  }

                  Navigator.pop(ctx);
                  _loadAnnouncements();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEditing
                              ? '✅ Announcement updated successfully'
                              : '✅ Announcement created successfully',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: Text(
                isEditing ? 'Update' : 'Create',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Manage Announcements'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnnouncements,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAnnouncementDialog(),
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.add),
        label: const Text('New Announcement'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 12),
                    _buildFilterChip('Upcoming', 'upcoming'),
                    const SizedBox(width: 12),
                    _buildFilterChip('Past', 'past'),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_announcements.length} announcements',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Error',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[500]),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadAnnouncements,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _announcements.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.campaign_outlined,
                                    size: 80, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No announcements found',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAnnouncements,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _announcements.length,
                              itemBuilder: (context, index) {
                                final announcement = _announcements[index];
                                return _buildAnnouncementCard(announcement, index);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = value;
        });
        _loadAnnouncements();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement, int index) {
    final title = announcement['title'] as String? ?? 'Untitled';
    final description = announcement['description'] as String? ?? '';
    final dateStr = announcement['date'] as String?;
    final timeStr = announcement['time'] as String?;
    final authorId = announcement['auth_id'] as int?;
    final categoryId = announcement['category_id'] as int?;
    final author = authorId != null ? _userCache[authorId] : null;
    final categoryName = categoryId != null ? _categoryCache[categoryId] : null;

    DateTime? eventDate;
    if (dateStr != null) {
      eventDate = DateTime.parse(dateStr);
    }

    final isUpcoming = eventDate != null && eventDate.isAfter(DateTime.now());
    final isPast = eventDate != null && eventDate.isBefore(DateTime.now());

    // Get announcement_id - check different possible field names
    final announcementId = announcement['announcement_id'] as int? ??
        announcement['id'] as int? ??
        0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUpcoming
              ? Colors.green
              : isPast
                  ? Colors.grey.shade300
                  : Colors.transparent,
          width: 2,
        ),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUpcoming
                  ? Colors.green.withOpacity(0.1)
                  : isPast
                      ? Colors.grey.withOpacity(0.1)
                      : Colors.purple.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUpcoming
                        ? Colors.green.withOpacity(0.2)
                        : isPast
                            ? Colors.grey.withOpacity(0.2)
                            : Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.campaign,
                    color: isUpcoming
                        ? Colors.green
                        : isPast
                            ? Colors.grey
                            : Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          if (author != null)
                            Text(
                              'By ${author['full_name'] ?? 'Unknown'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          if (categoryName != null) ...[
                            Text(
                              ' • ',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                categoryName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isUpcoming
                        ? Colors.green
                        : isPast
                            ? Colors.grey
                            : Colors.purple,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isUpcoming
                        ? 'UPCOMING'
                        : isPast
                            ? 'PAST'
                            : 'SCHEDULED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eventDate != null)
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMMM d, y').format(eventDate),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (timeStr != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),

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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (announcementId > 0) ...[
                  // ✅ Edit Button
                  ElevatedButton.icon(
                    onPressed: () => _showAnnouncementDialog(announcement),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete Button
                  ElevatedButton.icon(
                    onPressed: () => _deleteAnnouncement(announcementId, index),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}