// ============================================================
// FILE 6: main.dart (SUPER CLEAN WORKING VERSION — NO UNI_LINKS)
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// AUTH SCREENS
import 'screens/auth/login_page.dart';
import 'screens/auth/signup_page.dart';
import 'screens/auth/forgot_password_page.dart';
import 'screens/auth/email_verification_page.dart';
import 'screens/auth/reset_password_page.dart';

// ADMIN / OTHER SCREENS
import 'screens/settings/about_page.dart';
import 'screens/admin/admin_home_page.dart';
import 'screens/admin/manage_users_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: "https://aadoraweupxxqnotvkyw.supabase.co",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFhZG9yYXdldXB4eHFub3R2a3l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyODIzNDksImV4cCI6MjA4MDg1ODM0OX0._TkkjkldNNAyNA3yFKKiAPF30PeIdAX7ALO6c-v7E1g",
  );

  runApp(const TechCircleApp());
}

class TechCircleApp extends StatelessWidget {
  const TechCircleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "MIU Tech Circle",

      theme: ThemeData(
        colorSchemeSeed: Colors.red,
        useMaterial3: true,
      ),

      // Default screen
      home: const LoginPage(),

      // App routes
      routes: {
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignUpPage(),
        '/forgot-password': (_) => const ForgotPasswordPage(),
        '/email-verification': (_) => const EmailVerificationPage(),
        '/reset-password': (_) => const ResetPasswordPage(),
        '/about': (_) => const AboutPage(),
        '/admin-home': (_) => const AdminHomePage(),
        '/manage-users': (_) => const ManageUsersPage(),
      },
    );
  }
}
