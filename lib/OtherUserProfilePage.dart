import 'package:flutter/material.dart';
import 'comment_page.dart';
import 'main.dart';
import 'send_post_dialog.dart';
import 'chat_room_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class OtherUserProfilePage extends StatefulWidget {
  final String userId;

  const OtherUserProfilePage({
    super.key,
    required this.userId,
  });

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> with SingleTickerProviderStateMixin {
  int _visiblePostCount = 1;
  
  // Professional LinkedIn-inspired color palette
  static const Color primaryRed = Color(0xFFD00000);
  static const Color darkRed = Color(0xFFB00000);
  static const Color backgroundColor = Color(0xFFF3F2EF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF888888);
  static const Color dividerColor = Color(0xFFE8E8E8);
  
  bool isFollowing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final String mockCurrentUserId = "11111111-1111-1111-1111-111111111111";

  Map<String, dynamic>? user;
  List<Map<String, dynamic>> _allPosts = [];
  bool loading = true;
  int followerCount = 0;
  int followingCount = 0;
  
  // ✅ Track endorsed skills
  Map<String, bool> endorsedSkills = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    fetchUserAndPosts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> checkIfFollowing() async {
    try {
      final response = await supabase
          .from('follows')
          .select()
          .eq('follower_id', mockCurrentUserId)
          .eq('following_id', widget.userId)
          .maybeSingle();

      setState(() {
        isFollowing = response != null;
      });
    } catch (e) {
      print("⚠️ Error checking follow status: $e");
      setState(() => isFollowing = false);
    }
  }

  Future<void> fetchFollowerCounts() async {
    try {
      final followersData = await supabase
          .from('follows')
          .select()
          .eq('following_id', widget.userId);
      
      final followingData = await supabase
          .from('follows')
          .select()
          .eq('follower_id', widget.userId);
      
      setState(() {
        followerCount = (followersData as List).length;
        followingCount = (followingData as List).length;
      });
      
      print('👥 Followers: $followerCount, Following: $followingCount');
    } catch (e) {
      print('⚠️ Error fetching follower counts: $e');
      setState(() {
        followerCount = 0;
        followingCount = 0;
      });
    }
  }

  Future<void> toggleFollow() async {
    try {
      if (isFollowing) {
        await supabase.from('follows').delete().match({
          'follower_id': mockCurrentUserId,
          'following_id': widget.userId,
        });
        print('✅ Unfollowed');
      } else {
        await supabase.from('follows').insert({
          'follower_id': mockCurrentUserId,
          'following_id': widget.userId,
        });
        print('✅ Followed');
      }

      setState(() {
        isFollowing = !isFollowing;
      });
      
      await fetchFollowerCounts();
    } catch (e) {
      print("❌ Error toggling follow: $e");
      setState(() => isFollowing = !isFollowing);
    }
  }

  Future<void> fetchUserAndPosts() async {
    try {
      print('🔍 Fetching user: ${widget.userId}');
      
      final fetchedUser = await supabase
          .from('users')
          .select('id, username, role, bio, experience, education, skills')
          .eq('id', widget.userId)
          .single();

      print('✅ User: ${fetchedUser['username']}');
      print('📝 Bio: ${fetchedUser['bio'] ?? "No bio"}');

      final postsResponse = await supabase
          .from('posts')
          .select('id, content, created_at, user_id')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      print('📊 Posts found: ${(postsResponse as List).length}');

      final List<Map<String, dynamic>> transformedPosts = [];
      
      for (var post in postsResponse) {
        final postId = post['id'];
        
        final likesData = await supabase
            .from('likes')
            .select()
            .eq('post_id', postId);
        
        final likeCount = (likesData as List).length;
        
        final userLike = await supabase
            .from('likes')
            .select()
            .eq('post_id', postId)
            .eq('user_id', mockCurrentUserId)
            .maybeSingle();
        
        final commentsData = await supabase
            .from('comments')
            .select()
            .eq('post_id', postId);
        
        final commentCount = (commentsData as List).length;
        
        final repostsData = await supabase
            .from('reposts')
            .select()
            .eq('post_id', postId);
        
        final repostCount = (repostsData as List).length;
        
        final userRepost = await supabase
            .from('reposts')
            .select()
            .eq('post_id', postId)
            .eq('user_id', mockCurrentUserId)
            .maybeSingle();
        
        transformedPosts.add({
          "id": postId,
          "text": post['content'] ?? 'No content',
          "image": false,
          "reposter": "",
          "comments": commentCount,
          "likes": likeCount,
          "reposts": repostCount,
          "isLiked": userLike != null,
          "isReposted": userRepost != null,
          "postComments": [],
          "created_at": post['created_at'],
        });
      }

      print('✅ Posts with stats loaded');

      setState(() {
        user = fetchedUser;
        _allPosts = transformedPosts;
        loading = false;
        _visiblePostCount = _allPosts.isNotEmpty ? 1 : 0;
      });

      await checkIfFollowing();
      await fetchFollowerCounts();
      
      // ✅ CHANGE 2: Fetch endorsement status for all skills
      if (fetchedUser['skills'] != null && (fetchedUser['skills'] as List).isNotEmpty) {
        final skills = fetchedUser['skills'] as List;
        final Map<String, bool> endorsementStatus = {};
        
        for (var skill in skills) {
          final skillName = skill['name'];
          if (skillName != null) {
            try {
              final endorsement = await supabase
                  .from('skill_endorsements')
                  .select()
                  .eq('skill_name', skillName)
                  .eq('endorsed_user_id', widget.userId)
                  .eq('endorser_user_id', mockCurrentUserId)
                  .maybeSingle();
              
              endorsementStatus[skillName] = endorsement != null;
            } catch (e) {
              print('⚠️ Error checking endorsement for $skillName: $e');
              endorsementStatus[skillName] = false;
            }
          }
        }
        
        setState(() {
          endorsedSkills = endorsementStatus;
        });
        
        print('✅ Loaded endorsement status: $endorsedSkills');
      }
      
      _animationController.forward();

    } catch (e, stackTrace) {
      print('❌ Error: $e');
      print('Stack: $stackTrace');
      
      setState(() {
        user = {
          "username": "Unknown", 
          "role": "Unknown", 
          "id": widget.userId,
          "bio": null
        };
        _allPosts = [];
        loading = false;
      });
    }
  }

  Future<void> _handleLike(int postIndex) async {
    final post = _allPosts[postIndex];
    final postId = post['id'];
    final isCurrentlyLiked = post['isLiked'];

    try {
      if (isCurrentlyLiked) {
        await supabase
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', mockCurrentUserId);
        
        print('👎 Unliked post $postId');
        
        setState(() {
          _allPosts[postIndex]['isLiked'] = false;
          _allPosts[postIndex]['likes'] = (_allPosts[postIndex]['likes'] as int) - 1;
        });
      } else {
        await supabase.from('likes').insert({
          'post_id': postId,
          'user_id': mockCurrentUserId,
        });
        
        print('👍 Liked post $postId');
        
        setState(() {
          _allPosts[postIndex]['isLiked'] = true;
          _allPosts[postIndex]['likes'] = (_allPosts[postIndex]['likes'] as int) + 1;
        });
      }
    } catch (e) {
      print('❌ Error toggling like: $e');
    }
  }

  Future<void> _handleRepost(int postIndex) async {
    final post = _allPosts[postIndex];
    final postId = post['id'];
    final isCurrentlyReposted = post['isReposted'];

    try {
      if (isCurrentlyReposted) {
        await supabase
            .from('reposts')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', mockCurrentUserId);
        
        print('🔄 Un-reposted post $postId');
        
        setState(() {
          _allPosts[postIndex]['isReposted'] = false;
          _allPosts[postIndex]['reposts'] = (_allPosts[postIndex]['reposts'] as int) - 1;
        });
      } else {
        await supabase.from('reposts').insert({
          'post_id': postId,
          'user_id': mockCurrentUserId,
        });
        
        print('🔄 Reposted post $postId');
        
        setState(() {
          _allPosts[postIndex]['isReposted'] = true;
          _allPosts[postIndex]['reposts'] = (_allPosts[postIndex]['reposts'] as int) + 1;
        });
      }
    } catch (e) {
      print('❌ Error toggling repost: $e');
    }
  }

  Future<void> _handleSendPost(Map<String, dynamic> postData) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SendPostDialog(
        postId: postData['id'],
        postContent: postData['text'],
      ),
    );

    if (result == true) {
      print('✅ Post sent successfully');
    }
  }

  void _onBackTapped(BuildContext context) => Navigator.of(context).pop();
  
  Future<void> _onMessageTapped() async {
    try {
      print('💬 Starting chat with user: ${widget.userId}');
      
      final existingConversations = await supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', mockCurrentUserId);
      
      String? conversationId;
      
      for (var conv in existingConversations) {
        final otherParticipants = await supabase
            .from('conversation_participants')
            .select()
            .eq('conversation_id', conv['conversation_id'])
            .eq('user_id', widget.userId)
            .maybeSingle();
        
        if (otherParticipants != null) {
          conversationId = conv['conversation_id'];
          print('✅ Found existing conversation: $conversationId');
          break;
        }
      }
      
      if (conversationId == null) {
        print('📝 Creating new conversation...');
        
        final newConversation = await supabase
            .from('conversations')
            .insert({})
            .select()
            .single();
        
        conversationId = newConversation['id'];
        
        await supabase.from('conversation_participants').insert([
          {
            'conversation_id': conversationId,
            'user_id': mockCurrentUserId,
          },
          {
            'conversation_id': conversationId,
            'user_id': widget.userId,
          },
        ]);
        
        print('✅ New conversation created: $conversationId');
      }
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              conversationId: conversationId!,
              otherUserName: user!['username'] ?? 'Unknown',
              otherUserId: widget.userId,
            ),
          ),
        );
      }
      
    } catch (e) {
      print('❌ Error starting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: darkRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }
  
  void _onTabTapped(String tabName) => print("$tabName tapped!");
  void _onPostCardTapped() => print("Post card tapped!");
  
  void _onShowAllPostsTapped() {
    setState(() {
      _visiblePostCount = _allPosts.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: primaryRed,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // LinkedIn-style app bar
            SliverAppBar(
              pinned: false,
              backgroundColor: cardBackground,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: textPrimary, size: 24),
                onPressed: () => _onBackTapped(context),
              ),
            ),
            
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Profile header card (LinkedIn style)
                  Container(
                    color: cardBackground,
                    child: Column(
                      children: [
                        // Cover area with avatar
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Cover image
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    primaryRed.withOpacity(0.85),
                                    darkRed,
                                  ],
                                ),
                              ),
                            ),
                            // Avatar positioned at bottom of cover
                            Positioned(
                              left: 16,
                              bottom: -50,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cardBackground,
                                    width: 4,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: primaryRed,
                                  child: Text(
                                    (user!['username'] ?? 'U')
                                        .split(' ')
                                        .map((e) => e.isNotEmpty ? e[0] : '')
                                        .take(2)
                                        .join()
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 56),
                        
                        // User info section
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name and headline
                              Text(
                                user!['username'] ?? 'Unknown User',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user!['role'] ?? 'No Role',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: textPrimary,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Connections count
                              InkWell(
                                onTap: () {
                                  print('👥 Followers: $followerCount, Following: $followingCount');
                                },
                                child: Text(
                                  followerCount == 0 
                                      ? "No connections"
                                      : "$followerCount connection${followerCount != 1 ? 's' : ''}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Action buttons - LinkedIn style
                              Row(
                                children: [
                                  Expanded(
                                    child: _LinkedInButton(
                                      label: isFollowing ? "Following" : "Connect",
                                      icon: isFollowing ? Icons.check : Icons.person_add_outlined,
                                      isPrimary: !isFollowing,
                                      onTap: toggleFollow,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _LinkedInButton(
                                      label: "Message",
                                      icon: Icons.mail_outline,
                                      isPrimary: false,
                                      onTap: _onMessageTapped,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // About section card
                  if (user!['bio'] != null && (user!['bio'] as String).isNotEmpty)
                    _buildAboutCard(),
                  
                  const SizedBox(height: 8),
                  
                  // Activity section
                  _buildActivityCard(),
                  
                  const SizedBox(height: 8),
                  
                  // Experience section
                  if (user!['experience'] != null && (user!['experience'] as List).isNotEmpty)
                    _buildExperienceCard(),
                  
                  const SizedBox(height: 8),
                  
                  // Education section
                  if (user!['education'] != null && (user!['education'] as List).isNotEmpty)
                    _buildEducationCard(),
                  
                  const SizedBox(height: 8),
                  
                  // Skills section
                  if (user!['skills'] != null && (user!['skills'] as List).isNotEmpty)
                    _buildSkillsCard(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      width: double.infinity,
      color: cardBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildBioContent(user!['bio']),
        ],
      ),
    );
  }

  Widget _buildBioContent(String bio) {
    final lines = bio.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.asMap().entries.map((entry) {
        final index = entry.key;
        final line = entry.value.trim();
        
        // Detect if line has special formatting
        IconData? icon;
        Color iconColor = textSecondary;
        
        // Check for role/title indicators
        if (line.toLowerCase().contains('developer') || 
            line.toLowerCase().contains('engineer') ||
            line.toLowerCase().contains('designer')) {
          icon = Icons.work_outline;
          iconColor = textSecondary;
        }
        // Check for education indicators
        else if (line.toLowerCase().contains('university') || 
                 line.toLowerCase().contains('college') ||
                 line.toLowerCase().contains('student') ||
                 line.toLowerCase().contains('year')) {
          icon = Icons.school_outlined;
          iconColor = textSecondary;
        }
        // Check for location indicators
        else if (line.toLowerCase().contains('cairo') || 
                 line.toLowerCase().contains('egypt') ||
                 RegExp(r'\b[A-Z][a-z]+,\s*[A-Z][a-z]+\b').hasMatch(line)) {
          icon = Icons.location_on_outlined;
          iconColor = textSecondary;
        }
        // Check for specialization/skills
        else if (line.toLowerCase().contains('specializ') || 
                 line.toLowerCase().contains('focus') ||
                 line.toLowerCase().contains('expert')) {
          icon = Icons.emoji_objects_outlined;
          iconColor = textSecondary;
        }
        
        return Padding(
          padding: EdgeInsets.only(bottom: index < lines.length - 1 ? 12 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  line,
                  style: const TextStyle(
                    fontSize: 14,
                    color: textPrimary,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivityCard() {
    return Container(
      width: double.infinity,
      color: cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
          
          if (_allPosts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 48,
                      color: textTertiary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "No posts to show",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                ...List.generate(_visiblePostCount, (index) {
                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 1, color: borderColor),
                      _buildLinkedInPostCard(_allPosts[index], index),
                    ],
                  );
                }),
                if (_visiblePostCount < _allPosts.length)
                  Column(
                    children: [
                      const Divider(height: 1, color: borderColor),
                      InkWell(
                        onTap: _onShowAllPostsTapped,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: const Center(
                            child: Text(
                              'Show all posts',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLinkedInPostCard(Map<String, dynamic> postData, int postIndex) {
    final String postText = postData['text'] ?? 'No content';
    final int displayedLikeCount = postData['likes'] ?? 0;
    final int displayedRepostCount = postData['reposts'] ?? 0;
    final int displayedCommentCount = postData['comments'] ?? 0;
    final bool isPostLiked = postData['isLiked'] ?? false;
    final bool isPostReposted = postData['isReposted'] ?? false;

    return InkWell(
      onTap: _onPostCardTapped,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info row
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primaryRed,
                  child: Text(
                    (user!['username'] ?? 'U')
                        .split(' ')
                        .map((e) => e.isNotEmpty ? e[0] : '')
                        .take(2)
                        .join()
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user!['username'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        user!['role'] ?? 'Member',
                        style: const TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  color: textSecondary,
                  onPressed: () {},
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Post content
            Text(
              postText,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Engagement stats
            if (displayedLikeCount > 0 || displayedCommentCount > 0 || displayedRepostCount > 0) ...[
              Row(
                children: [
                  if (displayedLikeCount > 0) ...[
                    Icon(Icons.thumb_up, size: 14, color: primaryRed),
                    const SizedBox(width: 4),
                    Text(
                      displayedLikeCount.toString(),
                      style: const TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                  const Spacer(),
                  if (displayedCommentCount > 0)
                    Text(
                      '$displayedCommentCount comment${displayedCommentCount != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  if (displayedCommentCount > 0 && displayedRepostCount > 0)
                    const Text(' • ', style: TextStyle(color: textSecondary)),
                  if (displayedRepostCount > 0)
                    Text(
                      '$displayedRepostCount repost${displayedRepostCount != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 12, color: textSecondary),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: borderColor),
              const SizedBox(height: 4),
            ],
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LinkedInPostAction(
                  icon: isPostLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: "Like",
                  onTap: () => _handleLike(postIndex),
                  isActive: isPostLiked,
                ),
                _LinkedInPostAction(
                  icon: Icons.comment_outlined,
                  label: "Comment",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommentPage(
                          userName: user!['username'] ?? 'Unknown',
                          postId: postData['id'],
                          initialComments: [],
                          onCommentAdded: (newComment) {
                            fetchUserAndPosts();
                          },
                        ),
                      ),
                    );
                  },
                ),
                _LinkedInPostAction(
                  icon: Icons.repeat,
                  label: "Repost",
                  onTap: () => _handleRepost(postIndex),
                  isActive: isPostReposted,
                ),
                _LinkedInPostAction(
                  icon: Icons.send,
                  label: "Send",
                  onTap: () => _handleSendPost(postData),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceCard() {
    final experiences = user!['experience'] as List;
    
    return Container(
      width: double.infinity,
      color: cardBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Experience',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...experiences.asMap().entries.map((entry) {
            final index = entry.key;
            final exp = entry.value;
            
            return Column(
              children: [
                if (index > 0) const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company logo placeholder
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          (exp['company'] ?? 'C')[0].toUpperCase(),
                          style: TextStyle(
                            color: primaryRed,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exp['title'] ?? 'Position',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            exp['company'] ?? 'Company',
                            style: const TextStyle(
                              fontSize: 14,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${exp['startDate'] ?? ''} - ${exp['endDate'] ?? 'Present'}${exp['duration'] != null ? ' · ${exp['duration']}' : ''}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: textSecondary,
                            ),
                          ),
                          if (exp['location'] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              exp['location'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                            ),
                          ],
                          if (exp['description'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              exp['description'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEducationCard() {
    final education = user!['education'] as List;
    
    return Container(
      width: double.infinity,
      color: cardBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Education',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...education.asMap().entries.map((entry) {
            final index = entry.key;
            final edu = entry.value;
            
            return Column(
              children: [
                if (index > 0) const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // School logo placeholder
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.school,
                        color: Color(0xFF2196F3),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            edu['school'] ?? 'University',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            edu['degree'] ?? 'Degree',
                            style: const TextStyle(
                              fontSize: 14,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${edu['startYear'] ?? ''} - ${edu['endYear'] ?? 'Present'}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: textSecondary,
                            ),
                          ),
                          if (edu['description'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              edu['description'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSkillsCard() {
    final skills = user!['skills'] as List;
    final displayedSkills = skills.take(3).toList();
    final hasMore = skills.length > 3;
    
    return Container(
      width: double.infinity,
      color: cardBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skills',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...displayedSkills.asMap().entries.map((entry) {
            final index = entry.key;
            final skill = entry.value;
            final endorsements = skill['endorsements'] ?? 0;
            
            return Column(
              children: [
                if (index > 0) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: dividerColor),
                  const SizedBox(height: 12),
                ],
                _buildSkillItem(skill['name'] ?? 'Skill', 
                               skill['description'], 
                               endorsements),
              ],
            );
          }).toList(),
          if (hasMore) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: dividerColor),
            InkWell(
              onTap: () {
                _showAllSkills();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Show all ${skills.length} skills',
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ CHANGE 3: Updated _buildSkillItem with endorsement state
  Widget _buildSkillItem(String skillName, String? description, int endorsements) {
    // Check if current user has endorsed this skill
    final isEndorsed = endorsedSkills[skillName] ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Skill name
        Text(
          skillName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            height: 1.3,
          ),
        ),
        
        // Description (if available)
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: textSecondary,
              height: 1.4,
            ),
          ),
        ],
        
        // Endorse/Endorsed button
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                await _toggleSkillEndorsement(skillName);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isEndorsed ? primaryRed : Colors.transparent,
                  border: Border.all(
                    color: isEndorsed ? primaryRed : textSecondary.withOpacity(0.6),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isEndorsed ? Icons.check : Icons.add,
                      size: 16,
                      color: isEndorsed ? Colors.white : textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isEndorsed ? 'Endorsed' : 'Endorse',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isEndorsed ? Colors.white : textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ CHANGE 4: Updated _toggleSkillEndorsement with optimistic UI updates
  Future<void> _toggleSkillEndorsement(String skillName) async {
    // Update UI immediately for better UX
    setState(() {
      endorsedSkills[skillName] = !(endorsedSkills[skillName] ?? false);
    });
    
    try {
      final isCurrentlyEndorsed = endorsedSkills[skillName] ?? false;
      
      if (!isCurrentlyEndorsed) {
        // Remove endorsement
        await supabase
            .from('skill_endorsements')
            .delete()
            .eq('skill_name', skillName)
            .eq('endorsed_user_id', widget.userId)
            .eq('endorser_user_id', mockCurrentUserId);
        
        print('✅ Removed endorsement for: $skillName');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed endorsement for $skillName'),
              backgroundColor: textSecondary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } else {
        // Add endorsement
        await supabase.from('skill_endorsements').insert({
          'skill_name': skillName,
          'endorsed_user_id': widget.userId,
          'endorser_user_id': mockCurrentUserId,
        });
        
        print('✅ Endorsed: $skillName');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Endorsed $skillName'),
                ],
              ),
              backgroundColor: primaryRed,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
      
    } catch (e) {
      print('❌ Error toggling endorsement: $e');
      
      // Revert the UI change on error
      setState(() {
        endorsedSkills[skillName] = !(endorsedSkills[skillName] ?? false);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: darkRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showAllSkills() {
    final skills = user!['skills'] as List;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: dividerColor, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Skills (${skills.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Skills list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: skills.length,
                  separatorBuilder: (context, index) => Column(
                    children: [
                      const SizedBox(height: 16),
                      Divider(height: 1, color: dividerColor),
                      const SizedBox(height: 16),
                    ],
                  ),
                  itemBuilder: (context, index) {
                    final skill = skills[index];
                    return _buildSkillItem(
                      skill['name'] ?? 'Skill',
                      skill['description'],
                      skill['endorsements'] ?? 0,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// LinkedIn-style button
class _LinkedInButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;
  final bool isCompact;

  const _LinkedInButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16),
          decoration: BoxDecoration(
            color: isPrimary ? _OtherUserProfilePageState.primaryRed : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isPrimary 
                  ? _OtherUserProfilePageState.primaryRed 
                  : _OtherUserProfilePageState.textSecondary.withOpacity(0.6),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary 
                    ? Colors.white 
                    : _OtherUserProfilePageState.textSecondary,
              ),
              if (!isCompact) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isPrimary 
                        ? Colors.white 
                        : _OtherUserProfilePageState.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// LinkedIn-style post action
class _LinkedInPostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _LinkedInPostAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive 
        ? _OtherUserProfilePageState.primaryRed 
        : _OtherUserProfilePageState.textSecondary;
        
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}