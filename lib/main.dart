import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 👈 ADD THIS
import 'messaging_page.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xrtrxelzjarmnzqmwkkk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhydHJ4ZWx6amFybW56cW13a2trIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4MTE5OTIsImV4cCI6MjA3OTM4Nzk5Mn0.4wrY4eZbmhYu-yYo2rDUNaiLY6SPJpmQR4lnt5cSRPA',
  );

  runApp(
    const ProviderScope(  // 👈 WRAP YOUR APP WITH THIS
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatsListPage(), // start from Chats List
    );
  }
}