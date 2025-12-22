import 'package:flutter/material.dart';

class StoryProgressBar extends StatelessWidget {
  final int itemCount;
  final int currentIndex;
  final double progress; // 0 → 1

  const StoryProgressBar({
    super.key,
    required this.itemCount,
    required this.currentIndex,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(itemCount, (index) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: LinearProgressIndicator(
              value: index < currentIndex
                  ? 1
                  : index == currentIndex
                  ? progress
                  : 0,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      }),
    );
  }
}
