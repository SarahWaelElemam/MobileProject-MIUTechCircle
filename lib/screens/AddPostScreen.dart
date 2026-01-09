import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'widgets/top_navbar.dart';
import 'widgets/bottom_navbar.dart';
import 'widgets/user_drawer_header.dart';

final supabase = Supabase.instance.client;

class AddPostScreen extends StatefulWidget {
  final int? currentUserId;

  const AddPostScreen({Key? key, this.currentUserId = 6}) : super(key: key);

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCreatePostModal();
    });
  }

  void _showCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) =>
          CreatePostModal(userId: widget.currentUserId ?? 6),
    ).then((result) {
      if (result == null) {
        Navigator.pop(context);
      } else {
        // Post created successfully
        Navigator.pop(context, result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: TopNavbar(userId: widget.currentUserId ?? 6),
      ),
      endDrawer: UserDrawerContent(userId: widget.currentUserId ?? 6),
      body: const Center(
        child: CircularProgressIndicator(color: Color(0xFFE63946)),
      ),
      bottomNavigationBar: BottomNavbar(
        currentUserId: widget.currentUserId ?? 6,
        currentIndex: -1, // No tab selected for AddPost screen
      ),
    );
  }
}

// ==========================================
// CREATE POST MODAL (EXACT MATCH FROM MYPROFILE)
// ==========================================

class CreatePostModal extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? editPostData; // Data passed when in edit mode

  const CreatePostModal({Key? key, required this.userId, this.editPostData})
    : super(key: key);

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  // --- STATE VARIABLES ---
  bool _showCreatePost = false;
  bool _isLoadingCategories = true;
  bool _isUploading = false;

  // --- POST DATA ---
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic>? _selectedCategory;
  final TextEditingController _postController = TextEditingController();

  String _postType = 'Post';
  DateTime? _selectedDateTime;
  List<XFile> _selectedImages = [];
  List<PlatformFile> _selectedFiles = [];

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _heightAnimation = Tween<double>(begin: 0.6, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadCategories();

    // Check if we are in EDIT mode
    if (widget.editPostData != null) {
      _postController.text = widget.editPostData!['content'] ?? '';
      _showCreatePost = true;
      _animationController.value = 1.0;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _postController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select('category_id, name')
          .order('name');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedFiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please add some content')));
      return;
    }

    // Validate announcement requirements
    if (_postType == 'Announcement' && _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date and time for announcement'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userId = widget.userId;

      if (_postType == 'Announcement') {
        // ========================================
        // INSERT INTO ANNOUNCEMENTS TABLE
        // ========================================
        final announcementData = {
          'auth_id': userId,
          'date': _selectedDateTime!.toIso8601String().split('T')[0],
          'time': '${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}:00',
          'title': _selectedCategory!['name'],
          'description': _postController.text.trim(),
          'category_id': _selectedCategory!['category_id'],
          'created_at': DateTime.now().toIso8601String(),
        };

        await supabase.from('announcement').insert(announcementData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Announcement scheduled successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, {'success': true, 'type': 'announcement'});
        }
      } else {
        // ========================================
        // INSERT INTO POSTS TABLE (Regular Post)
        // ========================================
        String imageMediaUrl = '';
        String attachedFileUrl = '';

        // Upload images
        if (_selectedImages.isNotEmpty) {
          final image = _selectedImages.first;
          final bytes = await image.readAsBytes();
          final fileExt = image.name.split('.').last;
          final fileName =
              'img_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

          await supabase.storage
              .from('Posts')
              .uploadBinary(
                'post_images/$fileName',
                bytes,
                fileOptions: FileOptions(contentType: 'image/$fileExt'),
              );
          imageMediaUrl = supabase.storage
              .from('Posts')
              .getPublicUrl('post_images/$fileName');
        }

        // Upload files
        if (_selectedFiles.isNotEmpty) {
          final file = _selectedFiles.first;
          final Uint8List fileData = kIsWeb
              ? file.bytes!
              : await File(file.path!).readAsBytes();
          final fileExt = file.extension ?? 'dat';
          final fileName =
              'doc_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

          await supabase.storage
              .from('Posts')
              .uploadBinary(
                'post_files/$fileName',
                fileData,
                fileOptions: FileOptions(contentType: 'application/$fileExt'),
              );
          attachedFileUrl = supabase.storage
              .from('Posts')
              .getPublicUrl('post_files/$fileName');
        }

        final postData = {
          'author_id': userId,
          'content': _postController.text.trim(),
          'media_url': imageMediaUrl,
          'file_url': attachedFileUrl,
          'category_id': _selectedCategory!['category_id'],
          'title': _selectedCategory!['name'],
          'created_at': DateTime.now().toIso8601String(),
        };

        await supabase.from('posts').insert(postData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, {'success': true, 'type': 'post'});
        }
      }
    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  bool _canShowPostTypeDropdown() {
    return _selectedCategory != null &&
        !['Internships', 'Jobs', 'News'].contains(_selectedCategory!['name']);
  }

  void _onCategorySelected(Map<String, dynamic> category) {
    setState(() {
      _selectedCategory = category;
      _showCreatePost = true;
      _postType = 'Post';
      _selectedDateTime = null;
      _selectedImages.clear();
      _selectedFiles.clear();
    });
    _animationController.forward();
  }

  void _goBackToCategories() {
    _animationController.reverse().then((_) {
      setState(() {
        _showCreatePost = false;
        _selectedCategory = null;
        _postController.clear();
        _postType = 'Post';
        _selectedDateTime = null;
        _selectedImages.clear();
        _selectedFiles.clear();
      });
    });
  }

  Future<String?> _uploadFile(XFile file, String folder) async {
    try {
      final bytes = await file.readAsBytes();
      final fileExt = file.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$folder/$fileName';

      await supabase.storage
          .from('Posts')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: false,
            ),
          );

      final publicUrl = supabase.storage.from('Posts').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      print('Error uploading file: $e');
      if (e.toString().contains('Bucket not found') && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Storage bucket not configured. Post will be created without images.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _handlePost() async {
    if (_postController.text.trim().isEmpty) return;
    setState(() => _isUploading = true);

    try {
      String mediaUrl = widget.editPostData?['media_url'] ?? '';

      // ATTACHMENT FIX: Only upload new media if creating, lock if editing
      if (widget.editPostData == null && _selectedImages.isNotEmpty) {
        final image = _selectedImages.first;
        final bytes = await image.readAsBytes();
        final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = 'post_images/$fileName'; // Consistent path

        await supabase.storage.from('Posts').uploadBinary(filePath, bytes);
        mediaUrl = supabase.storage.from('Posts').getPublicUrl(filePath);
      }

      if (widget.editPostData != null) {
        // EDIT MODE: Only update text
        await supabase
            .from('posts')
            .update({
              'content': _postController.text.trim(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('post_id', widget.editPostData!['post_id']);
      } else {
        // CREATE MODE: Insert full record
        await supabase.from('posts').insert({
          'author_id': widget.userId,
          'content': _postController.text.trim(),
          'media_url': mediaUrl,
          'category_id': _selectedCategory!['category_id'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      Navigator.pop(context, {'success': true});
    } catch (e) {
      print("Post error: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // --- File/Image Selection Helpers ---

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'ppt', 'pptx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024)
      return '$bytes B';
    else if (bytes < 1024 * 1024)
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    else
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE63946),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFE63946),
                onPrimary: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        final selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (selectedDateTime.isBefore(DateTime.now())) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a future date and time'),
              backgroundColor: Color(0xFFE63946),
            ),
          );
          return;
        }

        setState(() => _selectedDateTime = selectedDateTime);
      }
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _heightAnimation,
      builder: (context, child) {
        return Container(
          height:
              MediaQuery.of(context).size.height *
              (_showCreatePost ? _heightAnimation.value : 0.6),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: _showCreatePost
              ? _buildCreatePostView()
              : _buildCategorySelectionView(),
        );
      },
    );
  }

  Widget _buildCategorySelectionView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            children: [
              const Text(
                'Select Category',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the type of post you want to create',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingCategories
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE63946)),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          children: [
                            _buildCategoryGrid(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    List<Widget> rows = [];
    for (int i = 0; i < _categories.length; i += 3) {
      List<Widget> rowChildren = [];
      for (int j = i; j < i + 3 && j < _categories.length; j++) {
        final category = _categories[j];
        rowChildren.add(
          Expanded(
            child: _CategoryCard(
              icon: _getCategoryIcon(category['name']),
              title: category['name'],
              gradient: _getCategoryGradient(j),
              onTap: () => _onCategorySelected(category),
            ),
          ),
        );
        if (j < i + 2 && j < _categories.length - 1) {
          rowChildren.add(const SizedBox(width: 16));
        }
      }
      rows.add(Row(children: rowChildren));
      if (i + 3 < _categories.length) {
        rows.add(const SizedBox(height: 16));
      }
    }
    return Column(children: rows);
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'internships':
        return Icons.work_outline;
      case 'competitions':
        return Icons.emoji_events_outlined;
      case 'courses':
        return Icons.school_outlined;
      case 'news':
        return Icons.article_outlined;
      case 'events':
        return Icons.calendar_today_outlined;
      case 'jobs':
        return Icons.business_center_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  LinearGradient _getCategoryGradient(int index) {
    if (index % 2 == 0) {
      return LinearGradient(
        colors: [
          const Color(0xFFE63946).withOpacity(0.85),
          const Color(0xFFDC2F41).withOpacity(0.85),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return LinearGradient(
        colors: [
          Colors.grey[600]!.withOpacity(0.85),
          Colors.grey[700]!.withOpacity(0.85),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  Widget _buildCreatePostView() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _goBackToCategories,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.black87,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Create Post',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _createPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE63946),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Upload',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey[300],
                          child: Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _postController,
                            maxLines: null,
                            minLines: 4,
                            decoration: InputDecoration(
                              hintText: "What's new?",
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 17,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(top: 8),
                            ),
                            style: const TextStyle(
                              fontSize: 17,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Image Previews
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedImages.asMap().entries.map((entry) {
                          return FutureBuilder<Uint8List>(
                            future: entry.value.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFDC143C),
                                    ),
                                  ),
                                );
                              }

                              if (snapshot.hasError || !snapshot.hasData) {
                                return Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.error),
                                );
                              }

                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      snapshot.data!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(entry.key),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    // File Previews
                    if (_selectedFiles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Column(
                        children: _selectedFiles.asMap().entries.map((entry) {
                          final file = entry.value;
                          final fileName = file.name;
                          final fileSize = file.bytes?.length ?? file.size ?? 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _getFileIcon(fileName),
                                  color: const Color(0xFFE63946),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (fileSize > 0)
                                        Text(
                                          _formatFileSize(fileSize),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeFile(entry.key),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Selected Category Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          _selectedCategory?['name'] ?? 'Category',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Post Type Pill (Dropdown or Static)
                      if (_canShowPostTypeDropdown())
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (context) => Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      title: const Text(
                                        'Post',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      trailing: _postType == 'Post'
                                          ? const Icon(
                                              Icons.check,
                                              color: Color(0xFFE63946),
                                            )
                                          : null,
                                      onTap: () {
                                        setState(() {
                                          _postType = 'Post';
                                          _selectedDateTime = null;
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                    ListTile(
                                      title: const Text(
                                        'Announcement',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      trailing: _postType == 'Announcement'
                                          ? const Icon(
                                              Icons.check,
                                              color: Color(0xFFE63946),
                                            )
                                          : null,
                                      onTap: () {
                                        setState(() {
                                          _postType = 'Announcement';
                                          _selectedImages.clear();
                                          _selectedFiles.clear();
                                        });
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Attachments cleared. Announcements don\'t support media.',
                                            ),
                                            backgroundColor: Color(0xFFE63946),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE63946),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _postType,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE63946),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Post',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      const Spacer(),

                      // Attachment Icons
                      if (_postType == 'Announcement') ...[
                        GestureDetector(
                          onTap: _selectDateTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedDateTime != null
                                  ? const Color(0xFFE63946).withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: _selectedDateTime != null
                                      ? const Color(0xFFE63946)
                                      : Colors.grey[600],
                                  size: 22,
                                ),
                                if (_selectedDateTime != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_selectedDateTime!.day}/${_selectedDateTime!.month} ${_selectedDateTime!.hour}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Color(0xFFE63946),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        IconButton(
                          onPressed: _pickImages,
                          icon: Icon(
                            Icons.image_outlined,
                            color: Colors.grey[600],
                            size: 24,
                          ),
                          tooltip: 'Add images',
                        ),
                        IconButton(
                          onPressed: _pickFiles,
                          icon: Icon(
                            Icons.attach_file,
                            color: Colors.grey[600],
                            size: 24,
                          ),
                          tooltip: 'Attach files',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        if (_isUploading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFE63946)),
                      SizedBox(height: 16),
                      Text(
                        'Uploading post...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ));
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Gradient gradient;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
