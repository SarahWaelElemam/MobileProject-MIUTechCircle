// ============================================================
// FILE: signup_page.dart (FINAL VERSION – NO IMAGE PICKER)
// EMAIL VERIFICATION + DB PROFILE CREATION
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase_service.dart';
import 'email_verification_page.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _service = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _department = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _location = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;

  String _selectedRole = "Student";
  int _selectedAcademicYear = 1;

  bool isMIUEmail(String email) {
    return email.toLowerCase().trim().endsWith("@miuegypt.edu.eg");
  }

  // ============================================================
  // SIGN UP + EMAIL VERIFICATION
  // ============================================================
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isLoading = true);

    try {
      // 1) CREATE SUPABASE USER AUTH ACCOUNT
      final response = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text.trim(),
        emailRedirectTo: 'myapp://email-confirmed',
      );

      if (response.user == null) {
        throw "Signup failed — no user returned.";
      }

      // 2) SAVE USER PROFILE IN DATABASE (NO IMAGE)
      await _service.createUserProfile(
        name: _name.text.trim(),
        email: _email.text.trim(),
        role: _selectedRole,
        profileImage: null, // removed image picker
        department: _department.text.trim(),
        bio: _bio.text.trim(),
        academicYear: _selectedAcademicYear,
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text("Account created! Check your email to verify."),
          backgroundColor: Colors.green,
        ),
      );

      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Signup Error: $e")),
      );
    }

    setState(() => _isLoading = false);
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),

                // DEFAULT AVATAR (NO IMAGE PICKER)
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color.fromARGB(40, 255, 0, 0),
                  child: Icon(Icons.person, size: 50, color: Colors.red),
                ),

                const SizedBox(height: 20),

                _input("Full Name", Icons.person, _name),
                const SizedBox(height: 16),

                _input("MIU Email", Icons.email, _email, validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  if (!isMIUEmail(v)) return "Use MIU email only";
                  return null;
                }),
                const SizedBox(height: 16),

                _input("Department", Icons.school, _department),
                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
                  value: _selectedAcademicYear,
                  decoration: InputDecoration(
                    labelText: "Academic Year",
                    prefixIcon: const Icon(Icons.calendar_today, color: Colors.red),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("Year 1")),
                    DropdownMenuItem(value: 2, child: Text("Year 2")),
                    DropdownMenuItem(value: 3, child: Text("Year 3")),
                    DropdownMenuItem(value: 4, child: Text("Year 4")),
                  ],
                  onChanged: (v) => setState(() => _selectedAcademicYear = v!),
                ),
                const SizedBox(height: 16),

                _input("Bio", Icons.info, _bio, maxLines: 2),
                const SizedBox(height: 16),

                _input("Location (optional)", Icons.location_on, _location,
                    validator: (v) => null),
                const SizedBox(height: 16),

                DropdownButtonFormField(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: "Role",
                    prefixIcon: const Icon(Icons.badge, color: Colors.red),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: "Student", child: Text("Student")),
                    DropdownMenuItem(value: "Instructor", child: Text("Instructor")),
                    DropdownMenuItem(value: "TA", child: Text("TA")),
                    DropdownMenuItem(value: "Admin", child: Text("Admin")),
                  ],
                  onChanged: (v) => setState(() => _selectedRole = v!),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock, color: Colors.red),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) =>
                      v != null && v.length >= 6 ? null : "Minimum 6 characters",
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Create Account",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text(
                    "Already have an account? Login",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT FIELD BUILDER
  // ============================================================
  Widget _input(
    String label,
    IconData icon,
    TextEditingController controller, {
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator ?? (v) => v == null || v.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.red),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
