import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ================= Supabase =================
import 'package:supabase_flutter/supabase_flutter.dart';

// ================= Riverpod =================
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

// ================= Provider =================
import 'package:provider/provider.dart';

// ================= App Screens =================
import 'views/screens/Splash_Screen.dart';
import 'views/screens/HomePage.dart';
import 'views/screens/login_page.dart';
import 'views/screens/signup_page.dart';
import 'views/screens/forgot_password_page.dart';
import 'views/screens/reset_password_with_otp_page.dart';
import 'views/screens/email_confirmed_page.dart';
import 'views/screens/email_verification_page.dart';

// ================= Providers =================
import 'providers/SavedPostProvider.dart';
import 'providers/StoryProvider.dart';
import 'providers/post_provider.dart';
import 'providers/repost_provider.dart';
import 'providers/comment_provider.dart';
import 'providers/FreelancingHubProvider.dart';  // 🆕 ADD THIS

// ================= Services =================
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print("🔌 Initializing Supabase...");
    
    await Supabase.initialize(
      url: 'https://aadoraweupxxqnotvkyw.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFhZG9yYXdldXB4eHFub3R2a3l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyODIzNDksImV4cCI6MjA4MDg1ODM0OX0._TkkjkldNNAyNA3yFKKiAPF30PeIdAX7ALO6c-v7E1g',
    );

    print("✅ Supabase initialized successfully");

    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      print("🔔 Auth event: $event");

      if (event == AuthChangeEvent.passwordRecovery) {
        print("🔐 Password recovery detected");
      }

      if (event == AuthChangeEvent.signedIn && session?.user != null) {
        final user = session!.user;
        
        print("✅ User signed in: ${user.email}");
        print("📧 Email confirmed at: ${user.emailConfirmedAt}");
        
        if (user.emailConfirmedAt != null) {
          try {
            final service = SupabaseService();
            final existingProfile = await service.getUserByEmail(user.email!);
            
            if (existingProfile == null) {
              final metadata = user.userMetadata;
              
              await service.createUserProfile(
                userId: user.id,
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
          } catch (e) {
            print("❌ Error creating profile: $e");
          }
        }
      }

      if (event == AuthChangeEvent.signedOut) {
        print("🚪 User signed out");
      }
    });

  } catch (e) {
    print("❌ Supabase initialization error: $e");
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    riverpod.ProviderScope(
      child: const MIUTechCircleApp(),
    ),
  );
}

class MIUTechCircleApp extends StatelessWidget {
  const MIUTechCircleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SavedPostProvider()),
        ChangeNotifierProvider(create: (_) => StoryProvider()),
        ChangeNotifierProvider(
          create: (_) => PostProvider(
            currentUserId: _getCurrentUserId(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RepostProvider(
            currentUserId: _getCurrentUserId(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => CommentProvider()),
        ChangeNotifierProvider(create: (_) => FreelancingHubProvider()),  // 🆕 ADD THIS
      ],
      child: MaterialApp(
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
        
        // Simple routes without parameters
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginPage(),
          '/signup': (context) => const SignUpPage(),
          '/forgot-password': (context) => const ForgotPasswordPage(),
          '/email-confirmed': (context) => const EmailConfirmedPage(),
          '/home': (context) => HomePage(currentUserId: _getCurrentUserId()),
          '/new-home': (context) => HomePage(currentUserId: _getCurrentUserId()),
        },

        // Handle routes with arguments
        onGenerateRoute: (settings) {
          print("🔗 Route requested: ${settings.name}");
          
          if (settings.name == null) return null;
          
          // Parse URI for deep links
          final uri = Uri.tryParse(settings.name!);
          if (uri == null) return null;
          
          // ============ PASSWORD RESET ROUTES ============
          
          // OTP password reset with email parameter
          if (uri.path == '/reset-password-otp' || settings.name == '/reset-password-otp') {
            String emailValue = '';
            
            // Try to get email from arguments first
            if (settings.arguments != null && settings.arguments is String) {
              emailValue = settings.arguments as String;
            } 
            // Then try URI query parameters
            else if (uri.queryParameters.containsKey('email')) {
              emailValue = uri.queryParameters['email'] ?? '';
            }
            
            print("🔐 OTP password reset for: $emailValue");
            return MaterialPageRoute(
              builder: (context) => ResetPasswordWithOtpPage(email: emailValue),
              settings: settings,
            );
          }

          // ============ EMAIL VERIFICATION ROUTES ============
          
          // Email confirmation link from Supabase
          if (uri.path == '/email-confirmed' || 
              uri.fragment.contains('type=signup') ||
              settings.name!.contains('type=signup')) {
            print("📧 Email confirmation link detected");
            return MaterialPageRoute(
              builder: (context) => const EmailConfirmedPage(),
              settings: settings,
            );
          }

          // Email verification page with email parameter
          if (uri.path == '/email-verification' || settings.name == '/email-verification') {
            String emailValue = '';
            
            // Try to get email from arguments first
            if (settings.arguments != null && settings.arguments is String) {
              emailValue = settings.arguments as String;
            }
            // Then try URI query parameters
            else if (uri.queryParameters.containsKey('email')) {
              emailValue = uri.queryParameters['email'] ?? '';
            }
            
            print("📧 Email verification page for: $emailValue");
            return MaterialPageRoute(
              builder: (context) => EmailVerificationPage(email: emailValue),
              settings: settings,
            );
          }

          // ============ HOME ROUTES WITH USER ID ============
          
          if (settings.name == '/home-with-id') {
            final userId = settings.arguments as int? ?? _getCurrentUserId();
            return MaterialPageRoute(
              builder: (context) => HomePage(currentUserId: userId),
              settings: settings,
            );
          }
          
          // Return null to let the default routing handle it
          return null;
        },

        // Handle completely unknown routes
        onUnknownRoute: (settings) {
          print("❓ Unknown route: ${settings.name}");
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Page Not Found'),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '404 - Page Not Found',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Route: ${settings.name ?? 'Unknown'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.home),
                      label: const Text('Go to Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Get current user ID from Supabase auth
  int _getCurrentUserId() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Try to get user_id from metadata
        final userId = user.userMetadata?['user_id'];
        if (userId != null && userId is int) {
          return userId;
        }
      }
    } catch (e) {
      print("❌ Error getting current user ID: $e");
    }
    return 6; // Default fallback user ID
  }
}

// ================= Global Helpers =================

/// Global Supabase client instance
final supabase = Supabase.instance.client;

/// Check if user is currently authenticated
bool get isAuthenticated {
  return Supabase.instance.client.auth.currentUser != null;
}

/// Get current user's email
String? get currentUserEmail {
  return Supabase.instance.client.auth.currentUser?.email;
}

/// Get current user's auth ID (UUID)
String? get currentUserId {
  return Supabase.instance.client.auth.currentUser?.id;
}

/// Sign out the current user
Future<void> signOutUser() async {
  try {
    await Supabase.instance.client.auth.signOut();
    print("🚪 User signed out successfully");
  } catch (e) {
    print("❌ Error signing out: $e");
  }
}

/// Check if current user's email is verified
bool get isEmailVerified {
  final user = Supabase.instance.client.auth.currentUser;
  return user?.emailConfirmedAt != null;
}

/// Get current user's role from metadata
String? get userRole {
  return Supabase.instance.client.auth.currentUser?.userMetadata?['role'];
}

/// Get current user's name from metadata
String? get userName {
  return Supabase.instance.client.auth.currentUser?.userMetadata?['name'];
}

/// Navigate to route with email argument (helper function)
void navigateToRouteWithEmail(BuildContext context, String routeName, String email) {
  Navigator.pushNamed(
    context,
    routeName,
    arguments: email,
  );
}

/// Navigate to home with specific user ID
void navigateToHomeWithUserId(BuildContext context, int userId) {
  Navigator.pushNamed(
    context,
    '/home-with-id',
    arguments: userId,
  );
}