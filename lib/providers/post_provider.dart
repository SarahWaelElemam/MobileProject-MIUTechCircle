import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class PostProvider extends ChangeNotifier {
  // postId -> like count
  final Map<int, int> postLikeCounts = {};

  // set of postIds liked by the current user
  final Set<int> likedByMe = {};

  final int currentUserId;
  PostProvider({required this.currentUserId});

  // load like count and whether current user liked the post
  Future<void> loadPostLikes(int postId) async {
    try {
      final likes = await _supabase.from('likes').select('user_id').eq('post_id', postId);
      final list = likes as List;
      postLikeCounts[postId] = list.length;
      likedByMe.remove(postId); // reset then check
      for (final l in list) {
        if (l['user_id'] == currentUserId) {
          likedByMe.add(postId);
          break;
        }
      }
      notifyListeners();
    } catch (e) {
      // ignore or log
    }
  }

  // optimistic toggle
  Future<void> togglePostLike(int postId) async {
    final currentlyLiked = likedByMe.contains(postId);

    // optimistic update local state
    if (currentlyLiked) {
      likedByMe.remove(postId);
      postLikeCounts[postId] = (postLikeCounts[postId] ?? 1) - 1;
    } else {
      likedByMe.add(postId);
      postLikeCounts[postId] = (postLikeCounts[postId] ?? 0) + 1;
    }
    notifyListeners();

    try {
      if (currentlyLiked) {
        await _supabase
            .from('likes')
            .delete()
            .match({'post_id': postId, 'user_id': currentUserId});
      } else {
        await _supabase.from('likes').insert({
          'post_id': postId,
          'user_id': currentUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // rollback on error
      if (currentlyLiked) {
        likedByMe.add(postId);
        postLikeCounts[postId] = (postLikeCounts[postId] ?? 0) + 1;
      } else {
        likedByMe.remove(postId);
        postLikeCounts[postId] = (postLikeCounts[postId] ?? 1) - 1;
      }
      notifyListeners();
    }
  }
}
