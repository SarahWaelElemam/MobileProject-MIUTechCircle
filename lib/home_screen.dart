import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/stories/screens/stories_row.dart';
import 'features/stories/controllers/stories_controller.dart';
import 'features/search/views/search_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text("Home")),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh stories
          await ref.read(storiesProvider.notifier).loadStories();
        },
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Column(
                children: [
                  SizedBox(height: 10),
                  StoriesRow(),
                  SizedBox(height: 10),
                ],
              ),
            ),
            const SliverFillRemaining(
              child: Center(child: Text("Feed Items Here")),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          );
        },
        child: const Icon(Icons.search),
      ),
    );
  }
}
