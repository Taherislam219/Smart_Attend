import '../../theme/smartattend_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../student/student_dashboard.dart';
import '../teacher/teacher_dashboard.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final String role;

  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static Color get _background => SmartAttendPalette.background;
  static Color get _text => SmartAttendPalette.text;
  static Color get _muted => SmartAttendPalette.muted;

  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Login using Supabase and verify the account role.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // STEP 1: Authenticate and retrieve role.
      final actualRole = await _authService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // STEP 2: Compare database role with selected role.
      if (actualRole != widget.role.toLowerCase()) {
        await Supabase.instance.client.auth.signOut();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This account cannot access the selected role.'),
          ),
        );

        return;
      }

      if (!mounted) {
        return;
      }

      // STEP 3: Open the correct dashboard.
      if (actualRole == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => StudentDashboard()),
        );
      } else if (actualRole == 'teacher') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TeacherDashboard()),
        );
      }
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild when the app theme changes.
    final isTeacher = widget.role == 'Teacher';

    return Scaffold(
      backgroundColor: _background,


      body: Stack(
        children: [
          SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 26, vertical: 28),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                SizedBox(height: 40),

                // Neumorphic role icon.
                Center(
                  child: Container(
                    width: 112,
                    height: 112,

                    decoration: BoxDecoration(
                      color: _background,
                      borderRadius: BorderRadius.circular(30),

                      boxShadow: [
                        BoxShadow(
                          color: SmartAttendPalette.highlight,
                          offset: Offset(-7, -7),
                          blurRadius: 14,
                        ),
                        BoxShadow(
                          color: SmartAttendPalette.shadow,
                          offset: Offset(7, 7),
                          blurRadius: 14,
                        ),
                      ],
                    ),

                    child: Icon(
                      isTeacher
                          ? Icons.co_present_rounded
                          : Icons.menu_book_rounded,
                      color: _text,
                      size: 56,
                    ),
                  ),
                ),

                SizedBox(height: 38),

                Text(
                  'Welcome back!',
                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                ),

                SizedBox(height: 10),

                Text(
                  'Sign in to your ${widget.role.toLowerCase()} account',
                  textAlign: TextAlign.center,

                  style: TextStyle(fontSize: 15, color: _muted),
                ),

                SizedBox(height: 44),

                // Email field.
                _inputField(
                  controller: _emailController,
                  label: 'Email address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),

                SizedBox(height: 22),

                // Password field.
                _inputField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  validator: Validators.password,

                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',

                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),

                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : () async {
                      final sent = await Navigator.push<bool>(context, MaterialPageRoute(
                        builder: (_) => ForgotPasswordScreen(
                          initialEmail: _emailController.text.trim(),
                        ),
                      ));
                      if (!mounted || sent != true) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('If this account exists, a password reset email has been sent. Check your inbox and spam folder.')),
                      );
                    },
                    child: Text('Forgot Password?',
                      style: TextStyle(color: _text, fontWeight: FontWeight.bold)),
                  ),
                ),

                SizedBox(height: 16),

                // Neumorphic login button.
                Container(
                  height: 58,

                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(18),

                    boxShadow: [
                      BoxShadow(
                        color: SmartAttendPalette.highlight,
                        offset: Offset(-5, -5),
                        blurRadius: 10,
                      ),
                      BoxShadow(
                        color: SmartAttendPalette.shadow,
                        offset: Offset(5, 5),
                        blurRadius: 10,
                      ),
                    ],
                  ),

                  child: Material(
                    color: Colors.transparent,

                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _isLoading ? null : _submit,

                      child: Center(
                        child: _isLoading
                            ? CircularProgressIndicator(color: _text)
                            : Text(
                                'Login',
                                style: TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 28),

                // Registration navigation.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    Flexible(
                      child: Text(
                        "Don't have an account?",
                        style: TextStyle(color: _muted),
                      ),
                    ),

                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (isTeacher) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Teacher accounts require trusted provisioning.',
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RegisterScreen(),
                                  ),
                                );
                              }
                            },

                      child: Text(
                        'Register',

                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      ),
                    ),
                  ],
                ),

                if (isTeacher)
                  Padding(
                    padding: EdgeInsets.only(top: 8),

                    child: Text(
                      'Teacher access requires a verified teacher account.',
                      textAlign: TextAlign.center,

                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
            ),
          ),
        ),
      ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: IconButton(
                  tooltip: 'Back',
                  icon: Icon(Icons.arrow_back_rounded),
                  color: _text,
                  onPressed: _isLoading ? null : () => Navigator.maybePop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reusable Neumorphic input field.
  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required FormFieldValidator<String> validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(color: SmartAttendPalette.highlight, offset: Offset(-3, -3), blurRadius: 8),
          BoxShadow(
            color: SmartAttendPalette.shadow,
            offset: Offset(3, 3),
            blurRadius: 8,
          ),
        ],
      ),

      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,

        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),

          contentPadding: EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 16,
          ),
        ),
      ),
    );
  }
}
