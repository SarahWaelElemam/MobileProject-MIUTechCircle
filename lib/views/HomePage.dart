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
final supabase = Supabase.instance.client;

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
  late Future<List<PostModel>> _postsFuture;

  // Cache friend IDs for repost indicator
  List<int> _cachedFriendIds = [];

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _postsFuture = _fetchPosts();
    _confettiController =
      ConfettiController(duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoryProvider>().loadStories(
      currentUserId: widget.currentUserId,
      forYou: _showForYou,
    );
    });
  }

  Future<void> _loadLikesAndRepostsForPosts() async {
    try {
      final posts = await _postsFuture;
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final repostProvider = Provider.of<RepostProvider>(context, listen: false);
      
      final postIds = posts.map((p) => p.postId).toList();
      
      // Load likes for all posts
      for (final p in posts) {
        postProvider.loadPostLikes(p.postId);
      }
      
      // Batch load reposts
      await repostProvider.loadRepostsForPosts(postIds);
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

  // ================================================================
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
                          _postsFuture = _fetchPosts();
                          _loadLikesAndRepostsForPosts();
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
                          _postsFuture = _fetchPosts();
                         _loadLikesAndRepostsForPosts();
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
                          _postsFuture = _fetchPosts();
                          _loadLikesAndRepostsForPosts();
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
                          _postsFuture = _fetchPosts();
                          _loadLikesAndRepostsForPosts();
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
                          _postsFuture = _fetchPosts();
                          _loadLikesAndRepostsForPosts();
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
                          _postsFuture = _fetchPosts();
                          _loadLikesAndRepostsForPosts();
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
                          _postsFuture = _fetchPosts();
                          _loadLikesAndRepostsForPosts();
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
      _postsFuture = _fetchPosts();
      _loadLikesAndRepostsForPosts();
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
      _postsFuture = _fetchPosts();
      _loadLikesAndRepostsForPosts();
    });
  },
),

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
              FutureBuilder<List<PostModel>>(
                future: _postsFuture,
                builder: (context, postSnapshot) {
                  if (postSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!postSnapshot.hasData ||
                      postSnapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Center(child: Text("No posts available")),
                    );
                  }

                  return Column(
                    children: postSnapshot.data!
                        .map((p) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 10),
                              child: _feedCard(p),
                            ))
                        .toList(),
                  );
                },
              ),
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
if (!_showForYou && post.authorId != widget.currentUserId)
  FutureBuilder<bool>(
    future: _isFollowing(post.authorId),
    builder: (context, followSnapshot) {
      final isFollowing = followSnapshot.data ?? false;

      return GestureDetector(
        onTap: () => _toggleFollow(post.authorId, userName),
        child: Text(
          isFollowing ? "" : "+ Follow",
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    },
  )

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