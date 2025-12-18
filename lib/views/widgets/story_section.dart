import 'dart:ui';
import 'package:flutter/material.dart';

class StorySection extends StatelessWidget {
  final String? myAvatarUrl;
  final List<Map<String, dynamic>> stories;

  const StorySection({
    super.key,
    required this.myAvatarUrl,
    required this.stories,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 8),

          _StoryAdd(avatarUrl: myAvatarUrl),

          for (final story in stories)
            _StoryCard(
              name: story['user_name'] ?? "User",
              imageUrl: story['story_image'],
              avatarUrl: story['profile_image'],
            ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ========================= MY STORY =========================
class _StoryAdd extends StatelessWidget {
  final String? avatarUrl;

  const _StoryAdd({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.grey.shade300,
                backgroundImage:
                    (avatarUrl != null && avatarUrl!.isNotEmpty)
                        ? NetworkImage(avatarUrl!)
                        : null,
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 28)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text("My Story", style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// ========================= STORY CARD =========================
class _StoryCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String? avatarUrl;

  const _StoryCard({
    required this.name,
    required this.imageUrl,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 118,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 110,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromARGB(205, 244, 67, 54),
                        Color.fromARGB(255, 255, 150, 85),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Image.network(imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -14,
                  left: (110 / 2) - 29,
                  child: CircleAvatar(
                    radius: 29,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage:
                          (avatarUrl != null && avatarUrl!.isNotEmpty)
                              ? NetworkImage(avatarUrl!)
                              : null,
                      child: (avatarUrl == null || avatarUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(name, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
