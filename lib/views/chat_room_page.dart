import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

final supabase = Supabase.instance.client;

class ChatRoomPage extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserId;
  final String currentUserId; // ✅ Add current user ID

  const ChatRoomPage({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
    required this.currentUserId, // ✅ Required parameter
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  List<Map<String, dynamic>> messages = [];
  bool loading = true;
  bool uploading = false;

  // ⚠️ IMPORTANT: Change this to match your Supabase storage bucket name
  final String storageBucket = 'chat_attachments';

  @override
  void initState() {
    super.initState();
    fetchMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchMessages() async {
    try {
      print('💬 Fetching messages for conversation: ${widget.conversationId}');
      
      final response = await supabase
          .from('messages')
          .select('id, content, sender_id, created_at, file_url, file_type, users(username)')
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);

      print('✅ Messages fetched: ${(response as List).length}');

      setState(() {
        messages = (response as List).map((msg) {
          return {
            'id': msg['id'],
            'content': msg['content'],
            'sender_id': msg['sender_id'],
            'created_at': msg['created_at'],
            'file_url': msg['file_url'],
            'file_type': msg['file_type'],
            'sender_name': msg['users']['username'] ?? 'Unknown',
            'isMe': msg['sender_id'] == widget.currentUserId,
          };
        }).toList();
        loading = false;
      });

      // Scroll to bottom after loading
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });

    } catch (e) {
      print('❌ Error fetching messages: $e');
      setState(() {
        messages = [];
        loading = false;
      });
    }
  }

  Future<void> _sendMessage({String? fileUrl, String? fileType}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && fileUrl == null) return;

    try {
      print('📤 Sending message...');
      
      await supabase.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': widget.currentUserId,
        'content': text.isEmpty ? null : text,
        'file_url': fileUrl,
        'file_type': fileType,
      });

      print('✅ Message sent');

      _messageController.clear();
      
      // Refresh messages
      await fetchMessages();

    } catch (e) {
      print('❌ Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _uploadAndSendFile(File file, String fileType) async {
    setState(() => uploading = true);

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final filePath = '${widget.conversationId}/$fileName';

      print('📤 Uploading file to: $filePath');

      // Upload file to Supabase Storage
      await supabase.storage.from(storageBucket).upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      // Get public URL
      final fileUrl = supabase.storage.from(storageBucket).getPublicUrl(filePath);

      print('✅ File uploaded: $fileUrl');

      // Send message with file URL
      await _sendMessage(fileUrl: fileUrl, fileType: fileType);

    } catch (e) {
      print('❌ Error uploading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading file: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() => uploading = false);
    }
  }

  Future<void> _pickImage() async {
    Navigator.pop(context); // Close bottom sheet
    
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadAndSendFile(File(image.path), 'image');
      }
    } catch (e) {
      print('❌ Error picking image: $e');
    }
  }

  Future<void> _pickDocument() async {
    Navigator.pop(context); // Close bottom sheet
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        await _uploadAndSendFile(File(result.files.single.path!), 'document');
      }
    } catch (e) {
      print('❌ Error picking document: $e');
    }
  }

  Future<void> _takePhoto() async {
    Navigator.pop(context); // Close bottom sheet
    
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        await _uploadAndSendFile(File(photo.path), 'image');
      }
    } catch (e) {
      print('❌ Error taking photo: $e');
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = msg['isMe'] ?? false;
    final hasFile = msg['file_url'] != null;
    final fileType = msg['file_type'];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  colors: [Colors.red[700]!, Colors.red[600]!],
                )
              : null,
          color: isMe ? null : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasFile) ...[
              if (fileType == 'image')
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    msg['file_url'],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 150,
                        color: Colors.grey[300],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      color: isMe ? Colors.white : Colors.grey[700],
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Document',
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              if (msg['content'] != null && msg['content'].toString().isNotEmpty)
                const SizedBox(height: 8),
            ],
            if (msg['content'] != null && msg['content'].toString().isNotEmpty)
              Text(
                msg['content'] ?? '',
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.4,
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
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.red[700],
              child: Text(
                widget.otherUserName
                    .split(' ')
                    .map((e) => e.isNotEmpty ? e[0] : '')
                    .take(2)
                    .join()
                    .toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.otherUserName,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        elevation: 2,
      ),
      body: Column(
        children: [
          if (uploading)
            LinearProgressIndicator(
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red[700]!),
            ),
          Expanded(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Colors.red[700],
                    ),
                  )
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(messages[index]);
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    onPressed: uploading ? null : () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) {
                          return Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: Icon(Icons.image, color: Colors.red[700]),
                                  title: const Text('Image'),
                                  onTap: _pickImage,
                                ),
                                ListTile(
                                  leading: Icon(Icons.attach_file, color: Colors.red[700]),
                                  title: const Text('Document'),
                                  onTap: _pickDocument,
                                ),
                                ListTile(
                                  leading: Icon(Icons.camera_alt, color: Colors.red[700]),
                                  title: const Text('Camera'),
                                  onTap: _takePhoto,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    icon: Icon(Icons.add_circle, color: Colors.red[700]),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _messageController,
                        enabled: !uploading,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red[700]!, Colors.red[600]!],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: uploading ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}