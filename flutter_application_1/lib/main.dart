import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/login_page.dart';
import 'screens/auth/signup_page.dart';
import 'screens/auth/forgot_password_page.dart';
import 'screens/auth/reset_password_page.dart';
import 'screens/auth/email_verification_page.dart';
import 'screens/auth/email_confirmed_page.dart';
import 'screens/home/dummy_home_page.dart';
import 'screens/admin/admin_home_page.dart';
import 'screens/settings/settings_page.dart';
import 'supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: "https://aadoraweupxxqnotvkyw.supabase.co",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFhZG9yYXdldXB4eHFub3R2a3l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyODIzNDksImV4cCI6MjA4MDg1ODM0OX0._TkkjkldNNAyNA3yFKKiAPF30PeIdAX7ALO6c-v7E1g",
  );

  // ============================================================
  // AUTO LOGOUT ON APP START - ALWAYS GO TO LOGIN
  // ============================================================
  await Supabase.instance.client.auth.signOut();
  print("🚪 Auto-logged out on app start");

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
      
      if (user.emailConfirmedAt != null) {
        final service = SupabaseService();
        final existingProfile = await service.getUserByEmail(user.email!);
        
        if (existingProfile == null) {
          final metadata = user.userMetadata;
          
          await service.createUserProfile(
            name: metadata?['name'] ?? 'User',
            email: user.email!,
            role: metadata?['role'] ?? 'Student',
            profileImage: metadata?['profile_image'],
            coverImage: metadata?['cover_image'],
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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login', // ✅ ALWAYS START AT LOGIN
      routes: {
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignUpPage(),
        '/forgot-password': (_) => const ForgotPasswordPage(),
        '/reset-password': (_) => const ResetPasswordPage(),
        '/email-verification': (_) => const EmailVerificationPage(email: ''),
        '/email-confirmed': (_) => const EmailConfirmedPage(),
        '/dummy-home': (_) => const DummyHomePage(),
        '/admin-home': (_) => const AdminHomePage(),
        '/settings': (_) => const SettingsPage(),
      },
    );
  }
}