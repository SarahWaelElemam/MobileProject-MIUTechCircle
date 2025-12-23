import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Providers
import 'package:project/providers/post_provider.dart';
import 'package:project/providers/comment_provider.dart';
import 'package:project/providers/repost_provider.dart';
import 'package:project/providers/StoryProvider.dart';
import 'package:project/providers/SavedPostProvider.dart';
// Views
import 'package:project/views/HomePage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://aadoraweupxxqnotvkyw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFhZG9yYXdldXB4eHFub3R2a3l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyODIzNDksImV4cCI6MjA4MDg1ODM0OX0._TkkjkldNNAyNA3yFKKiAPF30PeIdAX7ALO6c-v7E1g',
  );

  // TEMP: Hard-coded current user
  const int currentUserId = 6;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SavedPostProvider()),
        ChangeNotifierProvider(create: (_) => StoryProvider()),
        ChangeNotifierProvider(
          create: (_) => PostProvider(currentUserId: currentUserId),
        ),
        ChangeNotifierProvider(
      create: (context) => RepostProvider(currentUserId: currentUserId),
        ),
        ChangeNotifierProvider(create: (_) => CommentProvider()),

      ],
      child: const MainApp(currentUserId: currentUserId),
    ),
  );
}

class MainApp extends StatelessWidget {
  final int currentUserId;

  const MainApp({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(currentUserId: currentUserId),
    );
  }
}
