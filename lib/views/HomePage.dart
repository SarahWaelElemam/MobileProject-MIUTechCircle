import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project/models/posts_model.dart';
import 'package:project/models/tag_model.dart';
import 'widgets/top_navbar.dart';
import 'widgets/bottom_navbar.dart';
import 'widgets/user_drawer_header.dart';
import 'widgets/category_chip.dart';
import 'widgets/story_section.dart';
import 'package:provider/provider.dart';
import 'package:project/providers/post_provider.dart';
import 'package:project/providers/repost_provider.dart';
import 'package:project/controllers/user_controller.dart';
import 'package:project/views/comments_page.dart';
import 'package:project/controllers/story_controller.dart';
import 'package:confetti/confetti.dart';
import 'package:project/providers/StoryProvider.dart';
import 'package:project/providers/SavedPostProvider.dart';
import 'package:project/models/announcement_model.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

final supabase = Supabase.instance.client;

class FeedItem {
  final PostModel? post;
  final AnnouncementModel? announcement;
  final DateTime createdAt;
  final bool isAnnouncement;

  FeedItem.fromPost(this.post)
      : announcement = null,
        createdAt = post!.createdAt,
        isAnnouncement = false;

  FeedItem.fromAnnouncement(this.announcement)
      : post = null,
        createdAt = announcement!.date,
        isAnnouncement = true;
}
class HomePage extends StatefulWidget {
  final int currentUserId;

  const HomePage({super.key, required this.currentUserId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Cache comment counts
  final Map<int, int> _commentCounts = {};

  late final ScrollController _scrollController;
  
  // Category selection
  String _selectedCategory = "ALL";

  // For You toggle (false = Discover, true = For You)
  bool _showForYou = false;

  // Cached posts future
late Future<List<FeedItem>> _feedFuture;

  // Cache friend IDs for repost indicator
  List<int> _cachedFriendIds = [];

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _feedFuture = _fetchFeed();
    _confettiController =
      ConfettiController(duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addPostFrameCallback((_) {
  context.read<StoryProvider>().loadStories(
    currentUserId: widget.currentUserId,
    forYou: _showForYou,
  );

  context.read<SavedPostProvider>()
      .loadSavedPosts(widget.currentUserId);
});

  }
Future<List<AnnouncementModel>> _fetchAnnouncements() async {
  try {
    var query = supabase.from('announcement').select();

    if (_selectedCategory != "ALL" && _selectedCategory != "Announcements") {
  final categoryId = _categoryNameToId(_selectedCategory);
  query = query.eq('category_id', categoryId);
}

    final data = await query.order('date', ascending: false);
    
    debugPrint("📢 Raw announcement data: $data");
    debugPrint("📢 Number of announcements fetched: ${(data as List).length}");
    
    final announcements = (data as List)
        .map((e) => AnnouncementModel.fromMap(e as Map<String, dynamic>))
        .toList();
    
    debugPrint("✅ Parsed announcements: ${announcements.length}");
    
    return announcements;
  } catch (e) {
    debugPrint("❌ Error fetching announcements: $e");
    return [];
  }
}

Future<List<FeedItem>> _fetchFeed() async {
  try {
    List<FeedItem> feedItems = [];

    // Fetch posts
    final posts = await _fetchPosts();
    debugPrint("📝 Posts fetched: ${posts.length}");
    feedItems.addAll(posts.map((p) => FeedItem.fromPost(p)));

    // Fetch announcements
    final announcements = await _fetchAnnouncements();
    debugPrint("📢 Announcements fetched: ${announcements.length}");
    feedItems.addAll(announcements.map((a) => FeedItem.fromAnnouncement(a)));

    // Sort by date (newest first)
    feedItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    debugPrint("🎯 Total feed items: ${feedItems.length}");
    debugPrint("   - Posts: ${feedItems.where((f) => !f.isAnnouncement).length}");
    debugPrint("   - Announcements: ${feedItems.where((f) => f.isAnnouncement).length}");

    return feedItems;
  } catch (e) {
    debugPrint("❌ Error loading feed: $e");
    return [];
  }
}
Future<void> _loadLikesAndRepostsForPosts(List<FeedItem> items) async {
  try {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final repostProvider = Provider.of<RepostProvider>(context, listen: false);
    
    final postIds = items
        .where((item) => !item.isAnnouncement)
        .map((item) => item.post!.postId)
        .toList();
    
    for (final id in postIds) {
      postProvider.loadPostLikes(id);
    }
    
    if (postIds.isNotEmpty) {
      await repostProvider.loadRepostsForPosts(postIds);
    }
  } catch (e) {
    debugPrint('Error loading likes and reposts: $e');
  }
}

Future<bool> _isFollowing(int targetUserId) async {
  final res = await supabase
      .from('friendships')
      .select()
      .eq('user_id', widget.currentUserId)
      .eq('friend_id', targetUserId)
      .eq('status', 'accepted')
      .maybeSingle();

  return res != null;
}

Future<void> _toggleFollow(int targetUserId, String userName) async {
  final existing = await supabase
      .from('friendships')
      .select('friendship_id')
      .eq('user_id', widget.currentUserId)
      .eq('friend_id', targetUserId)
      .maybeSingle();

  if (existing == null) {
    // FOLLOW
    await supabase.from('friendships').insert({
      'user_id': widget.currentUserId,
      'friend_id': targetUserId,
      'status': 'accepted',
    });

    // 🎉 SHOW CELEBRATION
    _confettiController.play();

    // 💬 POPUP MESSAGE
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("You are now friends with $userName 🎉"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  } else {
    // UNFOLLOW
    await supabase
        .from('friendships')
        .delete()
        .eq('friendship_id', existing['friendship_id']);
  }

  setState(() {});
}
Widget _announcementCard(AnnouncementModel announcement) {
  return FutureBuilder<Map<String, dynamic>?>(
    future: UserController.fetchUserData(announcement.authorId),
    builder: (context, snapshot) {
      // ✅ FIX 1: Proper loading state with fixed height to prevent layout shifts
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Container(
          height: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade300, width: 2),
          ),
          child: const Center(child: CircularProgressIndicator()),
        );
      }

      // ✅ FIX 2: Handle error state separately
      if (snapshot.hasError) {
        debugPrint("❌ Error loading user data for announcement: ${snapshot.error}");
        return Container(
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade300, width: 2),
          ),
          child: const Center(
            child: Text(
              "Error loading announcement author",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        );
      }

      // ✅ FIX 3: Handle null/no data case
      if (!snapshot.hasData || snapshot.data == null) {
        debugPrint("⚠️ No user data found for author_id: ${announcement.authorId}");
        return Container(
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade300, width: 2),
          ),
          child: const Center(
            child: Text(
              "User data not found",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        );
      }

      final user = snapshot.data!;
      final userName = user["name"] ?? "Admin";
      final avatar = user["profile_image"];

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade300, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.campaign, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    "ANNOUNCEMENT",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Author info
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${announcement.time} • ${timeAgo(announcement.date)}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              announcement.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              announcement.description,
              style: const TextStyle(fontSize: 14),
            ),
            
            const SizedBox(height: 12),

            // Add to Calendar Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addToCalendar(announcement),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text("Add to Calendar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// Add this method to handle calendar event creation:
void _addToCalendar(AnnouncementModel announcement) {
  final Event event = Event(
    title: announcement.title,
    description: announcement.description,
    location: '',
    startDate: announcement.fullDateTime,
    endDate: announcement.fullDateTime.add(const Duration(hours: 1)),
    iosParams: const IOSParams(
      reminder: Duration(minutes: 30),
    ),
    androidParams: const AndroidParams(
      emailInvites: [],
    ),
  );

  Add2Calendar.addEvent2Cal(event).then((success) {
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event added to calendar successfully! 📅'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add event to calendar'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } 
  });
}

// Add this method to handle calendar event creation:
  // CATEGORY MAPPING (updated per your DB)
  // ================================================================
  int _categoryNameToId(String name) {
    switch (name) {
      case "Internships":
        return 11;
      case "Events":
        return 12;
      case "Competitions":
        return 13;
      case "Announcements":
        return 14;
      case "Jobs":
        return 15;
      case "Courses":
        return 16;
      case "News":
        return 17;
      default:
        return 0; // ALL
    }
  }

  // ===========================================================
  // FRIENDSHIP CHECK
  // ===========================================================
  Future<bool> _areFriends(int user1, int user2) async {
    try {
      final result = await supabase
          .from('friendships')
          .select()
          .or(
            'and(user_id.eq.$user1,friend_id.eq.$user2),and(user_id.eq.$user2,friend_id.eq.$user1)',
          )
          .maybeSingle();
      if (result == null) return false;
      return result['status'] == 'accepted';
    } catch (e) {
      debugPrint("Error checking friendship: $e");
      return false;
    }
  }

  // ========================= BUILD =========================
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xffF5F7FA),

    endDrawer: UserDrawerContent(userId: widget.currentUserId),

    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: TopNavbar(userId: widget.currentUserId),
    ),

    body: Stack(
      children: [
        // ================= MAIN CONTENT =================
        SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= DISCOVER HEADER =================
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showForYou = false;
                          _feedFuture = _fetchFeed();
                        });
                      },
                      child: Text(
                        "Discover ",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _showForYou ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showForYou = true;
                          _feedFuture = _fetchFeed();
                        });
                      },
                      child: Text(
                        "For You",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: _showForYou ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ================= CREATE POST BAR =================
              FutureBuilder<Map<String, dynamic>?>(
                future: UserController.fetchUserData(widget.currentUserId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _loadingCreatePostBar();
                  }

                  final data = snapshot.data;
                  final name = (data != null &&
                          (data['name'] ?? "").toString().trim().isNotEmpty)
                      ? data['name']
                      : "User";
                  final imageUrl = data != null ? data['profile_image'] : null;

                  return _createPostBar(name, imageUrl);
                },
              ),

              const SizedBox(height: 8),

              // ================= CATEGORIES =================
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  children: [
                    CategoryChip(
                      text: "ALL",
                      selectedCategory: _selectedCategory,
                      onTap: () {
                        setState(() {
                          _selectedCategory = "ALL";
                          _feedFuture = _fetchFeed();
                        });
                      },
                    ),
                    CategoryChip(
                      text: "Internships",
                      icon: Icons.school,
                      selectedCategory: _selectedCategory,
                      onTap: () {
                        setState(() {
                          _selectedCategory = "Internships";
                          _feedFuture = _fetchFeed();
                        });
                      },
                    ),
                    CategoryChip(
                      text: "Competitions",
                      icon: Icons.emoji_events,
                      selectedCategory: _selectedCategory,
                      onTap: () {
                        setState(() {
                          _selectedCategory = "Competitions";
                          _feedFuture = _fetchFeed();
                        });
                      },
                    ),
                    CategoryChip(
                      text: "Courses",
                      icon: Icons.menu_book,
                      selectedCategory: _selectedCategory,
                      onTap: () {
                        setState(() {
                          _selectedCategory = "Courses";
                          _feedFuture = _fetchFeed();
                        });
                      },
                    ),
                    CategoryChip(
                      text: "News",
                      icon: Icons.article,
                      selectedCategory: _selectedCategory,
                      onTap: () {
                        setState(() {
                          _selectedCategory = "News";
                          _feedFuture = _fetchFeed();
                        });
                      },
                    ),
                    CategoryChip(
  text: "Events",
  icon: Icons.event,
  selectedCategory: _selectedCategory,
  onTap: () {
    setState(() {
      _selectedCategory = "Events";
      _feedFuture = _fetchFeed();
    });
  },
),

CategoryChip(
  text: "Jobs",
  icon: Icons.work,
  selectedCategory: _selectedCategory,
  onTap: () {
    setState(() {
      _selectedCategory = "Jobs";
      _feedFuture = _fetchFeed();
    });
  },
),
CategoryChip(
  text: "Announcements",
  icon: Icons.campaign,
  selectedCategory: _selectedCategory,
  onTap: () {
    setState(() {
      _selectedCategory = "Announcements";
      _feedFuture = _fetchFeed();
    });
  },
)
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ================= STORIES =================
              FutureBuilder<Map<String, dynamic>?>(
                future: UserController.fetchUserData(widget.currentUserId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final profileImage = userSnapshot.data?['profile_image'];
return Consumer<StoryProvider>(
  builder: (context, storyProvider, _) {
    return StorySection(
      myAvatarUrl: profileImage,
      stories: storyProvider.stories,
      hasMyStory: storyProvider.stories.any(
        (s) => s['user_id'] == widget.currentUserId,
      ),
      currentUserId: widget.currentUserId,
    );
  },
);

},
              ),

              const SizedBox(height: 10),
              Divider(color: Colors.grey.shade300),

              // ================= POSTS =================
FutureBuilder<List<FeedItem>>(
  future: _feedFuture,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(child: Text("No content available")),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLikesAndRepostsForPosts(snapshot.data!);
    });

    return Column(
      children: snapshot.data!.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: item.isAnnouncement
              ? _announcementCard(item.announcement!)
              : _feedCard(item.post!),
        );
      }).toList(),
    );
  },
)
            ],
          ),
        ),

        // ================= CONFETTI =================
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.orange,
              Colors.pink,
            ],
          ),
        ),
      ],
    ),

    bottomNavigationBar: const BottomNavbar(),
  );
}

  // ===========================================================================
  // FETCH TAGS FOR A POST
  // ===========================================================================
  Future<List<TagModel>> _fetchTags(int postId) async {
    try {
      final data = await supabase
          .from('tags')
          .select('tag_id, tag_name, post_id')
          .eq('post_id', postId);

      final list = data as List<dynamic>;
      return list.map((t) => TagModel.fromMap(t as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint("Error fetching tags for post $postId: $e");
      return [];
    }
  }

  // ===========================================================================
  // FETCH POSTS (NEWEST FIRST) with category and For You filtering
  // ===========================================================================
  Future<List<PostModel>> _fetchPosts() async {
    try {
      // If For You: gather friend ids (exclude current user)
      List<int> friendIds = [];
      if (_showForYou) {
        // 1️⃣ friends ids
        final friendsResult = await supabase
            .from('friendships')
            .select('user_id, friend_id, status')
            .or(
              'and(user_id.eq.${widget.currentUserId},status.eq.accepted),'
              'and(friend_id.eq.${widget.currentUserId},status.eq.accepted)',
            );

        for (final f in friendsResult as List) {
          if (f['user_id'] != widget.currentUserId) friendIds.add(f['user_id']);
          if (f['friend_id'] != widget.currentUserId) friendIds.add(f['friend_id']);
        }

        // Cache the friend IDs for repost indicator
        _cachedFriendIds = friendIds;

        if (friendIds.isEmpty) return [];

        // 2️⃣ reposted posts by friends
        final reposts = await supabase
            .from('reposts')
            .select('post_id, user_id')
            .filter('user_id', 'in', '(${friendIds.join(',')})');

        final repostedPostIds = reposts.map<int>((r) => r['post_id'] as int).toList();

        // 3️⃣ fetch posts (friends posts OR reposted posts)
        if (_selectedCategory != "ALL") {
          final categoryId = _categoryNameToId(_selectedCategory);
          
          if (repostedPostIds.isEmpty) {
            final data = await supabase
                .from('posts')
                .select('*')
                .filter('author_id', 'in', '(${friendIds.join(',')})')
                .eq('category_id', categoryId)
                .order('created_at', ascending: false);

            return (data as List)
                .map((p) => PostModel.fromMap(p as Map<String, dynamic>))
                .toList();
          } else {
            final data = await supabase
                .from('posts')
                .select('*')
                .or(
                  'author_id.in.(${friendIds.join(',')}),'
                  'post_id.in.(${repostedPostIds.join(',')})',
                )
                .eq('category_id', categoryId)
                .order('created_at', ascending: false);

            return (data as List)
                .map((p) => PostModel.fromMap(p as Map<String, dynamic>))
                .toList();
          }
        } else {
          // ALL categories
          if (repostedPostIds.isEmpty) {
            final data = await supabase
                .from('posts')
                .select('*')
                .filter('author_id', 'in', '(${friendIds.join(',')})')
                .order('created_at', ascending: false);

            return (data as List)
                .map((p) => PostModel.fromMap(p as Map<String, dynamic>))
                .toList();
          } else {
            final data = await supabase
                .from('posts')
                .select('*')
                .or(
                  'author_id.in.(${friendIds.join(',')}),'
                  'post_id.in.(${repostedPostIds.join(',')})',
                )
                .order('created_at', ascending: false);

            return (data as List)
                .map((p) => PostModel.fromMap(p as Map<String, dynamic>))
                .toList();
          }
        }
      } else {
        // Discover mode
        _cachedFriendIds = []; // Clear cached friend IDs
        
       if (_selectedCategory != "ALL") {
  // ✅ Return empty list if "Announcements" is selected (show only announcements, no posts)
  if (_selectedCategory == "Announcements") {
    return [];
  }
  
  final categoryId = _categoryNameToId(_selectedCategory);
  final data = await supabase
      .from('posts')
      .select('*')
      .eq('category_id', categoryId)
      .order('created_at', ascending: false);

          final listData = data as List<dynamic>;
          return listData.map<PostModel>((p) => PostModel.fromMap(p as Map<String, dynamic>)).toList();
        } else {
          // Discover + ALL
          final data = await supabase.from('posts').select('*').order('created_at', ascending: false);

          final listData = data as List<dynamic>;
          return listData.map<PostModel>((p) => PostModel.fromMap(p as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading posts: $e");
      return [];
    }
  }

  Future<void> _ensureCommentCount(int postId) async {
    if (_commentCounts.containsKey(postId)) return;

    try {
      final comments = await supabase.from('comments').select().eq('post_id', postId);
      final count = (comments as List).length;

      setStateIfMounted(() {
        _commentCounts[postId] = count;
      });
    } catch (e) {
      debugPrint("Error fetching comment count for post $postId: $e");
      setStateIfMounted(() {
        _commentCounts.putIfAbsent(postId, () => 0);
      });
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Widget _feedCard(PostModel post) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserController.fetchUserData(post.authorId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data!;
        final userName = user["name"] ?? "User";
        final avatar = user["profile_image"];

        return FutureBuilder<bool>(
          future: _areFriends(widget.currentUserId, post.authorId),
          builder: (context, friendSnapshot) {
            final isFriend = friendSnapshot.data ?? false;

            if (!_commentCounts.containsKey(post.postId)) {
              _ensureCommentCount(post.postId);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ REPOST INDICATOR (only in For You mode)
                if (_showForYou && _cachedFriendIds.isNotEmpty)
                  Consumer<RepostProvider>(
                    builder: (context, repostProvider, _) {
                      return FutureBuilder<List<Map<String, dynamic>>>(
                        future: repostProvider.getRepostedByFriends(
                          post.postId,
                          _cachedFriendIds,
                        ),
                        builder: (context, repostSnapshot) {
                          if (!repostSnapshot.hasData || repostSnapshot.data!.isEmpty) {
                            return const SizedBox();
                          }

                          final friends = repostSnapshot.data!;

                          final names = friends
                              .take(3)
                              .map((f) => f['name'])
                              .where((n) => n != null)
                              .join(', ');

                          final othersCount =
                              friends.length > 3 ? friends.length - 3 : 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6, left: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.repeat, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  othersCount > 0
                                      ? "$names and $othersCount others reposted this"
                                      : "$names reposted this",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),

                // POST CARD
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
  children: [
    CircleAvatar(
      backgroundImage: avatar != null ? NetworkImage(avatar) : null,
      child: avatar == null ? const Icon(Icons.person) : null,
    ),
    const SizedBox(width: 10),

    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(userName,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          Text(
            timeAgo(post.createdAt),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    ),

    // 🔖 SAVE ICON
    Consumer<SavedPostProvider>(
      builder: (context, savedProvider, _) {
        final isSaved = savedProvider.isSaved(post.postId);

        return IconButton(
          icon: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
            color: isSaved ? Colors.red : Colors.grey,
          ),
          onPressed: () {
            savedProvider.toggleSave(
              userId: widget.currentUserId,
              postId: post.postId,
            );
          },
        );
      },
    ),
  ],
),
 const SizedBox(height: 10),
                      Text(
                        post.content,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<TagModel>>(
                        future: _fetchTags(post.postId),
                        builder: (context, tagSnapshot) {
                          if (!tagSnapshot.hasData || tagSnapshot.data!.isEmpty) {
                            return const SizedBox();
                          }

                          final tags = tagSnapshot.data!;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final tag in tags)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "#${tag.tagName}",
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            post.mediaUrl!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // LIKE (uses PostProvider)
                          Consumer<PostProvider>(
                            builder: (context, provider, _) {
                              final likeCount = provider.postLikeCounts[post.postId] ?? 0;
                              final liked = provider.likedByMe.contains(post.postId);

                              return GestureDetector(
                                onTap: () => provider.togglePostLike(post.postId),
                                child: Row(
                                  children: [
                                    Icon(
                                      liked
                                          ? Icons.thumb_up_alt
                                          : Icons.thumb_up_alt_outlined,
                                      size: 20,
                                      color: liked ? Colors.red : Colors.grey[700],
                                    ),
                                    const SizedBox(width: 6),
                                    Text("$likeCount",
                                        style: TextStyle(
                                            color: liked ? Colors.red : Colors.grey[700],
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Text("Like",
                                        style: TextStyle(
                                            color:
                                                liked ? Colors.red : Colors.grey[600])),
                                  ],
                                ),
                              );
                            },
                          ),

                          // COMMENT
                          _postAction(
                            Icons.comment_outlined,
                            "Comment",
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CommentsPage(
                                    postId: post.postId,
                                    currentUserId: widget.currentUserId,
                                  ),
                                ),
                              ).then((_) {
                                setStateIfMounted(() {
                                  _commentCounts.remove(post.postId);
                                });
                                _ensureCommentCount(post.postId);

                                final postProvider =
                                    Provider.of<PostProvider>(context, listen: false);
                                final repostProvider =
                                    Provider.of<RepostProvider>(context, listen: false);
                                    
                                postProvider.loadPostLikes(post.postId);
                                repostProvider.loadRepostData(post.postId);
                              });
                            },
                            count: _commentCounts[post.postId] ?? 0,
                          ),

                          // REPOST (uses RepostProvider)
                          Consumer<RepostProvider>(
                            builder: (context, repostProvider, _) {
                              final isReposted = repostProvider.isReposted(post.postId);
                              final count = repostProvider.getRepostCount(post.postId);

                              return GestureDetector(
                                onTap: () async {
                                  try {
                                    await repostProvider.toggleRepost(post.postId);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to update repost'),
                                      ),
                                    );
                                  }
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.repeat,
                                      size: 20,
                                      color: isReposted
                                          ? Colors.red
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "$count",
                                      style: TextStyle(
                                        color: isReposted
                                            ? Colors.red
                                            : Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Repost",
                                      style: TextStyle(
                                        color: isReposted
                                            ? Colors.red
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _postAction(IconData icon, String label, VoidCallback onTap, {int? count}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 6),
          if (count != null) ...[
            Text('$count',
                style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _createPostBar(String name, String? imageUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade200,
            backgroundImage:
                (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
            child: (imageUrl == null || imageUrl.isEmpty)
                ? const Icon(Icons.person, color: Colors.black54)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xffF5F6F8),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                "What's in your mind, $name?",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingCreatePostBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 24, backgroundColor: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          )
        ],
      ),
    );
  }

  String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return "${diff.inMinutes} minutes ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";
    if (diff.inDays < 7) return "${diff.inDays} days ago";

    final weeks = (diff.inDays / 7).floor();
    return "$weeks week${weeks > 1 ? 's' : ''} ago";
  }
}