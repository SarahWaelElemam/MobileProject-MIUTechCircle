import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class StoryController {
  static final _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchStories({
    required int currentUserId,
    required bool forYou,
  }) async {
    try {
      debugPrint('🔍 fetchStories - currentUserId: $currentUserId, forYou: $forYou');
      
      List<int> friendIds = [];

      // ✅ If For You → Get friends
      if (forYou) {
        final friendsResult = await _supabase
            .from('friendships')
            .select('user_id, friend_id, status')
            .or(
              'and(user_id.eq.$currentUserId,status.eq.accepted),'
              'and(friend_id.eq.$currentUserId,status.eq.accepted)',
            );

        debugPrint('🔍 friendsResult: $friendsResult');

        for (final f in friendsResult as List) {
          if (f['user_id'] != currentUserId) {
            friendIds.add(f['user_id']);
          }
          if (f['friend_id'] != currentUserId) {
            friendIds.add(f['friend_id']);
          }
        }

        debugPrint('🔍 friendIds: $friendIds');

        // ❗ No friends → No stories
        if (friendIds.isEmpty) {
          debugPrint('⚠️ No friends found, returning empty list');
          return [];
        }
      }

      // =========================
      // Stories Query
      // =========================
      final List<dynamic> stories;
      
      if (forYou) {
        debugPrint('🔍 Querying stories for friends: ${friendIds.join(',')}');
        stories = await _supabase
            .from('stories')
            .select('id, user_id, story_image, created_at')
            .filter('user_id', 'in', '(${friendIds.join(',')})')
            .order('created_at', ascending: false);
      } else {
        stories = await _supabase
            .from('stories')
            .select('id, user_id, story_image, created_at')
            .order('created_at', ascending: false);
      }
      debugPrint('🔍 Stories fetched: ${stories.length} stories');

      // =========================
      // Attach user data
      // =========================
      List<Map<String, dynamic>> result = [];

      for (final story in stories as List) {
        debugPrint('🔍 Processing story: ${story['id']}, user_id: ${story['user_id']}');
        
        final user = await _supabase
            .from('users')
            .select('name, profile_image')
            .eq('user_id', story['user_id'])
            .maybeSingle();

        debugPrint('🔍 User data: ${user?['name']}');

        result.add({
          'story_image': story['story_image'],
          'user_name': user?['name'] ?? 'User',
          'profile_image': user?['profile_image'],
        });
      }

      debugPrint('✅ Returning ${result.length} stories with user data');
      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching stories: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }
}