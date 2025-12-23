import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import your existing screens
import 'package:flutter_application_1/screens/Splash_Screen.dart';
import 'package:flutter_application_1/screens/HomeScreen.dart';
import 'package:flutter_application_1/screens/My_Profile.dart';
import 'package:flutter_application_1/screens/AddPostScreen.dart';

// Import auth screens
import 'package:flutter_application_1/screens/auth/login_page.dart';
import 'package:flutter_application_1/screens/auth/signup_page.dart';
import 'package:flutter_application_1/screens/auth/forgot_password_page.dart';
import 'package:flutter_application_1/screens/auth/reset_password_page.dart';
import 'package:flutter_application_1/screens/auth/email_verification_page.dart';
import 'package:flutter_application_1/screens/auth/email_confirmed_page.dart';

// Import home screens
import 'package:flutter_application_1/screens/home/dummy_home_page.dart';

// Import service
import 'package:flutter_application_1/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with YOUR credentials
  await Supabase.initialize(
    url: 'https://aadoraweupxxqnotvkyw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFhZG9yYXdldXB4eHFub3R2a3l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyODIzNDksImV4cCI6MjA4MDg1ODM0OX0._TkkjkldNNAyNA3yFKKiAPF30PeIdAX7ALO6c-v7E1g',
  );

  // ============================================================
  // LISTEN FOR EMAIL CONFIRMATION - CREATE PROFILE AFTER VERIFICATION
  // ============================================================
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final session = data.session;

    print("🔔 Auth event: $event");

    if (event == AuthChangeEvent.signedIn && session?.user != null) {
      final user = session!.user;
      
      print("✅ User signed in: ${user.email}");
      print("📧 Email confirmed at: ${user.emailConfirmedAt}");
      
      // Only create profile if email is confirmed
      if (user.emailConfirmedAt != null) {
        final service = SupabaseService();
        final existingProfile = await service.getUserByEmail(user.email!);
        
        if (existingProfile == null) {
          // Create profile from metadata stored during signup
          final metadata = user.userMetadata;
          
          // ✅ FIXED: Pass user.id as userId parameter
          await service.createUserProfile(
            userId: user.id,  // ✅ THIS WAS MISSING
            name: metadata?['name'] ?? 'User',
            email: user.email!,
            role: metadata?['role'] ?? 'Student',
            profileImage: metadata?['profile_image'],
            department: metadata?['department'] ?? 'Unknown',
            bio: metadata?['bio'] ?? '',
            academicYear: metadata?['academic_year'] ?? 1,
            location: metadata?['location'],
          );
          
          print("✅ Profile created in database for ${user.email}");
        } else {
          print("ℹ️ Profile already exists for ${user.email}");
        }
      }
    }
  });

  // Set system UI overlay style
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
      
      // Start with splash screen
      home: const SplashScreen(),
      
      
      
      // Define routes (Note: MyProfile requires userId parameter, use Navigator.push instead of named route)
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignUpPage(),
        '/forgot-password': (_) => const ForgotPasswordPage(),
        '/reset-password': (_) => const ResetPasswordPage(),
        '/email-verification': (_) => const EmailVerificationPage(email: ''),
        '/email-confirmed': (_) => const EmailConfirmedPage(),
        '/home': (_) => const DummyHomePage(),
        '/dummy-home': (_) => const DummyHomePage(),
        
      },
    );
  }
}

// Global accessor for Supabase client
final supabase = Supabase.instance.client;