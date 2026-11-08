import 'package:flutter/material.dart';

import '../../utils/validators.dart';
import '../../services/auth_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const background = Color(0xFFE8EEF3);
  static const ink = Color(0xFF263238);
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final studentId = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool hidePassword = true;
  bool hideConfirm = true;

  @override
  void dispose() {
    name.dispose();
    studentId.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    // Step 1: Check all form fields.
    if (!formKey.currentState!.validate()) return;

    // Step 2: Prevent repeated submissions.
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 3: Register student using Supabase Auth.
      await _authService.registerStudent(
        fullName: name.text,
        universityStudentId: studentId.text,
        email: email.text,
        password: password.text,
      );

      if (!mounted) return;

      // Step 4: Inform the student.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration submitted! Check your email '
            'for the verification link.',
          ),
        ),
      );

      // Step 5: Return to the login screen.
      Navigator.pop(context);
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 9),
          BoxShadow(
            color: Color(0xFFB8C4CE),
            offset: Offset(4, 4),
            blurRadius: 9,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboard,
        obscureText: obscure,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 19,
            horizontal: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Student Registration'),
        backgroundColor: background,
        foregroundColor: ink,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 66,
                  color: ink,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Register as a student',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF607D8B)),
                ),
                const SizedBox(height: 32),
                field(
                  label: 'Full name',
                  controller: name,
                  icon: Icons.person_outline,
                  validator: Validators.name,
                ),
                field(
                  label: 'University student ID',
                  controller: studentId,
                  icon: Icons.badge_outlined,
                  keyboard: TextInputType.number,
                  validator: Validators.studentId,
                ),
                field(
                  label: 'Email',
                  controller: email,
                  icon: Icons.email_outlined,
                  keyboard: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                field(
                  label: 'Password',
                  controller: password,
                  icon: Icons.lock_outline,
                  obscure: hidePassword,
                  validator: Validators.password,
                  suffix: IconButton(
                    tooltip: hidePassword ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => hidePassword = !hidePassword),
                    icon: Icon(
                      hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                field(
                  label: 'Confirm password',
                  controller: confirm,
                  icon: Icons.verified_user_outlined,
                  obscure: hideConfirm,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm your password';
                    }
                    if (value != password.text) return 'Passwords do not match';
                    return null;
                  },
                  suffix: IconButton(
                    tooltip: hideConfirm
                        ? 'Show confirmation'
                        : 'Hide confirmation',
                    onPressed: () => setState(() => hideConfirm = !hideConfirm),
                    icon: Icon(
                      hideConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.white,
                        offset: Offset(-5, -5),
                        blurRadius: 10,
                      ),
                      BoxShadow(
                        color: Color(0xFFB8C4CE),
                        offset: Offset(5, 5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: submit,
                      child: const Center(
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Already have an account? Log In',
                    style: TextStyle(color: ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
