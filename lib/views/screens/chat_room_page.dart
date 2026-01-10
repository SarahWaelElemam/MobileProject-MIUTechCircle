import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// CURRENT USER CONFIGURATION
// Set this to YOUR user ID from the users table (integer)
// Based on your users: 2 (Sarah), 4 (Mostafa), 6 (Hana), 8 (Ismail), 25 (ahmed)
const int CURRENT_USER_ID = 4; // Change this to your actual user ID

class ChatRoomPage extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserId;

  const ChatRoomPage({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> messages = [];
  bool loading = true;
  bool isBlocked = false;
  bool isMuted = false;
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    print('');
    print('🚀🚀🚀 CHAT ROOM PAGE INITIALIZED 🚀🚀🚀');
    print('   Conversation: ${widget.conversationId}');
    print('   Other user: ${widget.otherUserName} (ID: ${widget.otherUserId})');
    print('');
    _loadSettings();
    fetchMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    supabase.removeAllChannels();
    super.dispose();
  }

  // Load conversation settings (mute/block status)
  Future<void> _loadSettings() async {
    try {
      print('');
      print('==========================================');
      print('⚙️ LOADING CONVERSATION SETTINGS');
      print('==========================================');
      print('   Conversation ID: ${widget.conversationId}');
      print('   Conversation ID type: ${widget.conversationId.runtimeType}');
      print('   Current User ID: $CURRENT_USER_ID');
      print('   Current User ID type: ${CURRENT_USER_ID.runtimeType}');
      print('   Other User ID: ${widget.otherUserId}');
      print('   Other User ID type: ${widget.otherUserId.runtimeType}');
      print('');
      
      final response = await supabase
          .from('conversation_settings')
          .select('*')
          .eq('conversation_id', widget.conversationId)
          .eq('user_id', CURRENT_USER_ID)
          .maybeSingle();

      print('📊 Database Response:');
      print('   Response: $response');
      
      if (response != null) {
        print('   Response keys: ${response.keys.toList()}');
        print('   is_muted value: ${response['is_muted']} (type: ${response['is_muted'].runtimeType})');
        print('   is_blocked value: ${response['is_blocked']} (type: ${response['is_blocked'].runtimeType})');
        
        setState(() {
          isMuted = response['is_muted'] ?? false;
          isBlocked = response['is_blocked'] ?? false;
        });
        
        print('');
        print('✅ SETTINGS LOADED SUCCESSFULLY');
        print('   isMuted: $isMuted');
        print('   isBlocked: $isBlocked');
        print('==========================================');
        print('');
      } else {
        print('');
        print('⚠️ NO SETTINGS FOUND IN DATABASE');
        print('   Creating default settings...');
        
        // Create default settings
        await supabase.from('conversation_settings').insert({
          'conversation_id': widget.conversationId,
          'user_id': CURRENT_USER_ID,
          'is_muted': false,
          'is_blocked': false,
        });
        
        print('✓ Default settings created');
        print('==========================================');
        print('');
      }
    } catch (e, stackTrace) {
      print('');
      print('❌❌❌ ERROR LOADING SETTINGS ❌❌❌');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      print('==========================================');
      print('');
    }
  }

  // Subscribe to real-time message updates
  void _subscribeToMessages() {
    print('👂 Subscribing to real-time messages...');
    
    supabase
        .channel('messages:${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) {
            print('📩 New message received');
            fetchMessages(); // Refresh messages
          },
        )
        .subscribe();
  }

  Future<void> fetchMessages() async {
    try {
      print('💬 Fetching messages for conversation: ${widget.conversationId}');
      
      final response = await supabase
          .from('messages')
          .select('id, content, sender_id, created_at, users(username)')
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
            'sender_name': msg['users']['username'] ?? 'Unknown',
            'isMe': msg['sender_id'].toString() == CURRENT_USER_ID.toString(),
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

  Future<void> _sendMessage() async {
    // Check if user is blocked
    if (isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Cannot send messages to blocked users'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      isSending = true;
    });

    try {
      print('📤 Sending message...');
      
      await supabase.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': CURRENT_USER_ID,
        'content': text,
      });

      print('✅ Message sent');

      _messageController.clear();

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
    } finally {
      setState(() {
        isSending = false;
      });
    }
  }

  // Toggle block status
  Future<void> _toggleBlock() async {
    try {
      final newBlockedState = !isBlocked;
      
      print('');
      print('==========================================');
      print('🔄 TOGGLING BLOCK STATUS');
      print('==========================================');
      print('   Current blocked state: $isBlocked');
      print('   New blocked state: $newBlockedState');
      print('   Conversation ID: ${widget.conversationId}');
      print('   User ID: $CURRENT_USER_ID');
      print('');
      
      final result = await supabase.from('conversation_settings').upsert({
        'conversation_id': widget.conversationId,
        'user_id': CURRENT_USER_ID,
        'is_blocked': newBlockedState,
        'is_muted': isMuted,
      }).select();

      print('📊 Database Update Result:');
      print('   Result: $result');
      print('');

      setState(() {
        isBlocked = newBlockedState;
      });

      print('✅ BLOCK STATUS UPDATED');
      print('   New isBlocked value: $isBlocked');
      print('==========================================');
      print('');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newBlockedState ? 'User blocked ✓' : 'User unblocked ✓'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('');
      print('❌❌❌ ERROR TOGGLING BLOCK ❌❌❌');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('==========================================');
      print('');
    }
  }

  // Toggle mute status
  Future<void> _toggleMute() async {
    try {
      final newMutedState = !isMuted;
      
      await supabase.from('conversation_settings').upsert({
        'conversation_id': widget.conversationId,
        'user_id': CURRENT_USER_ID,
        'is_blocked': isBlocked,
        'is_muted': newMutedState,
      });

      setState(() {
        isMuted = newMutedState;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newMutedState ? 'Chat muted' : 'Chat unmuted'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Error toggling mute: $e');
    }
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Chat Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    value: isMuted,
                    onChanged: (value) async {
                      await _toggleMute();
                      setModalState(() {});
                    },
                    title: const Text('Mute Notifications'),
                    subtitle: const Text('Turn off notifications for this chat'),
                    secondary: Icon(Icons.notifications_off, color: Colors.red[700]),
                    activeColor: Colors.red[700],
                  ),
                  const Divider(),
                  SwitchListTile(
                    value: isBlocked,
                    onChanged: (value) async {
                      await _toggleBlock();
                      setModalState(() {});
                    },
                    title: const Text('Block User'),
                    subtitle: const Text('Block messages from this user'),
                    secondary: Icon(Icons.block, color: Colors.red[700]),
                    activeColor: Colors.red[700],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
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
            Expanded(
              child: Text(
                widget.otherUserName,
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsBottomSheet,
            tooltip: 'Chat Settings',
          ),
        ],
        backgroundColor: Colors.red[700],
        elevation: 2,
      ),
      body: Column(
        children: [
          // Blocked user warning banner
          if (isBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.orange[50],
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You blocked ${widget.otherUserName}',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleBlock,
                    child: Text(
                      'Unblock',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
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
                              isBlocked ? 'Messaging is not available' : 'Start the conversation!',
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
                          final msg = messages[index];
                          final isMe = msg['isMe'] ?? false;

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
                              child: Text(
                                msg['content'] ?? '',
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Show warning message if blocked
          if (isBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, color: Colors.grey[600], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'You cannot send messages to a blocked user',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          // Message input (only show if not blocked)
          if (!isBlocked)
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
                      onPressed: () {
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
                                    onTap: () {
                                      print('Image clicked');
                                      Navigator.pop(context);
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.attach_file, color: Colors.red[700]),
                                    title: const Text('Document'),
                                    onTap: () {
                                      print('Document clicked');
                                      Navigator.pop(context);
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.camera_alt, color: Colors.red[700]),
                                    title: const Text('Camera'),
                                    onTap: () {
                                      print('Camera clicked');
                                      Navigator.pop(context);
                                    },
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
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          enabled: !isSending,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: isSending
                            ? null
                            : LinearGradient(
                                colors: [Colors.red[700]!, Colors.red[600]!],
                              ),
                        color: isSending ? Colors.grey : null,
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
                        icon: isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white),
                        onPressed: isSending ? null : _sendMessage,
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