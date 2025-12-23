import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_stories.dart';
import '../models/user_model.dart';
import '../models/story.dart';
import '../models/Friendship.dart';

// 1. Define a simple State class to hold sorted data
class StoriesState {
  final UserStories? myStory;
  final List<UserStories> friendsStories;

  StoriesState({this.myStory, this.friendsStories = const []});
}

// 2. Update Provider
final storiesProvider = StateNotifierProvider<StoriesController, StoriesState>(
  (ref) => StoriesController(),
);

class StoriesController extends StateNotifier<StoriesState> {
  StoriesController() : super(StoriesState()) {
    loadStories();
  }

  final _supabase = Supabase.instance.client;

  // 🟢 HARDCODED ID (Temporary for testing)
  int get currentUserId => 20;

  Future<void> loadStories() async {
    final now = DateTime.now();
    final twentyFourHoursAgoIso = now
        .subtract(const Duration(hours: 24))
        .toIso8601String();

    // 1. Fetch Friendships (Accepted only)
    List<Friendship> friendships = [];
    try {
      final friendshipsData = await _supabase
          .from('friendships')
          .select()
          .or('user_id.eq.$currentUserId,friend_id.eq.$currentUserId')
          .eq('status', 'accepted');

      friendships = (friendshipsData as List<dynamic>)
          .map((json) => Friendship.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching friendships: $e");
      // Fallback: Continue with empty friends list (only show my stories)
    }

    // 2. Extract Friend IDs
    final friendIds = <int>{};
    for (final f in friendships) {
      if (f.userId == currentUserId) {
        friendIds.add(f.friendId);
      } else {
        friendIds.add(f.userId);
      }
    }

    // Always include myself
    friendIds.add(currentUserId);

    try {
      // 3. Fetch Stories (Only from friends + me)
      final data = await _supabase
          .from('stories')
          .select('''
            id, story_image, created_at, user_id,
            users (user_id, name, profile_image),
            story_views(viewer_id)
          ''')
          .filter('user_id', 'in', friendIds.toList()) // 🟢 FILTER APPLIED
          .gt('created_at', twentyFourHoursAgoIso)
          .order('created_at');

      final Map<int, UserStories> grouped = {};

      // Grouping Logic
      for (final item in data) {
        final uid = item['user_id'] is int
            ? item['user_id']
            : int.tryParse(item['user_id'].toString()) ?? 0;

        // Create UserStories entry if not exists
        if (!grouped.containsKey(uid)) {
          grouped[uid] = UserStories(
            user: UserProfile.fromMap(item['users']),
            stories: [],
          );
        }

        // Add Story
        grouped[uid]!.stories.add(
          Story(
            id: item['id'],
            userId: uid,
            mediaUrl: item['story_image'],
            createdAt: DateTime.parse(item['created_at']),
            expiresAt: DateTime.parse(
              item['created_at'],
            ).add(const Duration(hours: 24)),
            seenBy: (item['story_views'] as List)
                .map(
                  (v) => v['viewer_id'] is int
                      ? v['viewer_id']
                      : int.tryParse(v['viewer_id'].toString()) ?? 0,
                )
                .cast<int>()
                .toSet(),
          ),
        );
      }

      // SPLIT LOGIC: Done here once, so the UI is dumb and fast
      final allStories = grouped.values.toList();

      final myStory = allStories.firstWhere(
        (s) => s.user.id == currentUserId,
        orElse: () => UserStories(
          // Return empty structure if no story exists
          user: UserProfile(id: currentUserId, username: 'Me', avatarUrl: ''),
          stories: [],
        ),
      );

      final friends = allStories
          .where((s) => s.user.id != currentUserId)
          .toList();

      // 🟢 SORT: Unseen first
      friends.sort((a, b) {
        final aUnseen = a.hasUnseen(currentUserId);
        final bUnseen = b.hasUnseen(currentUserId);
        if (aUnseen && !bUnseen) return -1;
        if (!aUnseen && bUnseen) return 1;
        return 0;
      });

      state = StoriesState(myStory: myStory, friendsStories: friends);
    } catch (e) {
      debugPrint("Error loading stories: $e");
      // Even on error, ensure we have a "myStory" object so the UI can show the add button
      state = StoriesState(
        myStory: UserStories(
          user: UserProfile(id: currentUserId, username: 'Me', avatarUrl: ''),
          stories: [],
        ),
        friendsStories: [],
      );
    }
  }

  Future<void> markStoryAsSeen(int storyId) async {
    debugPrint("markStoryAsSeen called for story: $storyId");
    debugPrint("Current User ID: $currentUserId");

    // 1. OPTIMISTIC UPDATE: Update local state immediately so UI feels instant
    bool stateChanged = false;

    final newFriends = state.friendsStories.map((user) {
      // Optimization: Only update if this user actually has the story
      if (!user.stories.any((s) => s.id == storyId)) return user;

      bool userChanged = false;
      final newStories = user.stories.map((story) {
        if (story.id == storyId) {
          if (story.seenBy.contains(currentUserId)) {
            debugPrint("Story already seen by user locally.");
            return story; // Already seen, no change
          }
          debugPrint("Marking story as seen locally.");
          userChanged = true;
          return story.copyWith(seenBy: {...story.seenBy, currentUserId});
        }
        return story;
      }).toList();

      if (userChanged) {
        stateChanged = true;
        return UserStories(user: user.user, stories: newStories);
      }
      return user;
    }).toList();

    UserStories? newMyStory = state.myStory;
    if (newMyStory != null && newMyStory.stories.any((s) => s.id == storyId)) {
      bool myStoryChanged = false;
      final newMyStoriesList = newMyStory.stories.map((story) {
        if (story.id == storyId) {
          if (story.seenBy.contains(currentUserId)) {
            return story;
          }
          myStoryChanged = true;
          return story.copyWith(seenBy: {...story.seenBy, currentUserId});
        }
        return story;
      }).toList();

      if (myStoryChanged) {
        stateChanged = true;
        newMyStory = UserStories(
          user: newMyStory.user,
          stories: newMyStoriesList,
        );
      }
    }

    if (stateChanged) {
      debugPrint("State changed, updating provider state.");
      state = StoriesState(myStory: newMyStory, friendsStories: newFriends);
    } else {
      debugPrint("No state change detected.");
    }

    // 2. Sync with Database (Background)
    try {
      debugPrint("Attempting DB insert for story_views...");
      await _supabase.from('story_views').insert({
        'story_id': storyId,
        'viewer_id': currentUserId,
        'seen_at': DateTime.now().toIso8601String(),
      });
      debugPrint("DB insert successful.");
    } catch (e) {
      // Ignore duplicate key errors (user already viewed this story)
      if (e.toString().contains('duplicate') ||
          e.toString().contains('23505')) {
        debugPrint("Story view already exists in DB (expected).");
      } else {
        debugPrint("Database Error (markStoryAsSeen): $e");
      }
    }
  }

  Future<void> addStory(File file) async {
    final ext = file.path.split('.').last;
    final name =
        '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage.from('story-media').upload(name, file);

    final url = _supabase.storage.from('story-media').getPublicUrl(name);

    await _supabase.from('stories').insert({
      'user_id': currentUserId,
      'story_image': url,
    });

    await loadStories();
  }

  Future<void> deleteStory(int storyId) async {
    final myStories = state.myStory;
    if (myStories == null) return;

    // 1. Find story implicitly (Throws error if not found, which is what we want)
    final story = myStories.stories.firstWhere((s) => s.id == storyId);

    // 2. Delete from DB
    await _supabase.from('stories').delete().eq('id', storyId);

    // 3. Update Local State (Clean & readable)
    state = StoriesState(
      myStory: UserStories(
        user: myStories.user,
        stories: myStories.stories.where((s) => s.id != storyId).toList(),
      ),
      friendsStories: state.friendsStories,
    );

    // 4. Delete from Storage (Fire-and-forget with silent error handling)
    // We do this LAST so the UI feels instant.
    final path = story.mediaUrl.split('/story-media/').last;
    _supabase.storage
        .from('story-media')
        .remove([path])
        .catchError((_) => <FileObject>[]);
  }
}