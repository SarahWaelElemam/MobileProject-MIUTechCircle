import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/screens/Splash_Screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://zljjdvyjjlfyycjtgqti.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsampkdnlqamxmeXljanRncXRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU1NDkxMTMsImV4cCI6MjA4MTEyNTExM30._KH7uUZ7ph027wuPLdD_515KalvG4Fus2DO4VNs1sY0',
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MIUTechCircleApp());
}

class MIUTechCircleApp extends StatelessWidget {
  const MIUTechCircleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MIU TechCircle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFE63946),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFFE63946),
          secondary: const Color(0xFFDC2F41),
          surface: Colors.white,
          background: Colors.grey[50]!,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// Global accessor for Supabase client
final supabase = Supabase.instance.client;