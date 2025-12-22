import 'user_model.dart';
import 'story.dart';

class UserStories {
  final UserProfile user;
  final List<Story> stories;

  UserStories({required this.user, required this.stories});

  /// Check if this user is the current logged-in user
  bool isMine(String currentUserId) => user.id == currentUserId;

  /// Check if there are any stories the current user hasn't seen yet
  bool hasUnseen(String currentUserId) {
    return stories.any((s) => !s.seenBy.contains(currentUserId));
  }
}
