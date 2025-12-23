import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/stories_controller.dart';
import '../models/user_stories.dart';
import '../screens/story_viewer_screen.dart';
import '../screens/create_story_screen.dart';
import '../widgets/story_avatar.dart';

class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key});

  void _navToCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
    );
  }

  void _navToView(BuildContext context, List<UserStories> users, int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false, // 🟢 This allows the previous screen to show through
        pageBuilder: (_, __, ___) =>
            StoryViewerScreen(users: users, initialUserIndex: index),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Optional: A simple fade transition
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storiesProvider);
    final myStory = state.myStory;
    final friends = state.friendsStories;
    final currentUserId = ref.read(storiesProvider.notifier).currentUserId;

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // ================= YOUR STORY =================
          if (myStory != null)
            Stack(
              alignment: Alignment.center,
              children: [
                // 1. THE AVATAR (Context Aware)
                GestureDetector(
                  onTap: () {
                    if (myStory.stories.isEmpty) {
                      _navToCreate(context); // No story? Create one.
                    } else {
                      _navToView(context, [myStory], 0); // Has story? View it.
                    }
                  },
                  child: StoryAvatar(
                    userId: myStory.user.id,
                    avatarUrl: myStory.user.avatarUrl,
                    username: 'Your story',
                    hasUnseenStories: false,
                    isYou: true,
                  ),
                ),

                // 2. THE BLUE PLUS BUTTON (Always Adds)
                Positioned(
                  bottom: 26, // Aligns with bottom of the circular image
                  right: 2, // Aligns to the right side
                  child: GestureDetector(
                    onTap: () => _navToCreate(context), // ALWAYS opens create
                    child: Container(
                      padding: const EdgeInsets.all(
                        2,
                      ), // White border thickness
                      decoration: const BoxDecoration(
                        color: Colors.black, // Match background to hide overlap
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(width: 12),

          // ================= FRIENDS STORIES =================
          ...friends.map((friendStories) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => _navToView(
                  context,
                  friends,
                  friends.indexOf(friendStories),
                ),
                child: StoryAvatar(
                  key: ValueKey(
                    '${friendStories.user.id}_${friendStories.hasUnseen(currentUserId)}',
                  ),
                  userId: friendStories.user.id,
                  avatarUrl: friendStories.user.avatarUrl,
                  username: friendStories.user.username,
                  hasUnseenStories: friendStories.hasUnseen(currentUserId),
                  isYou: false,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}