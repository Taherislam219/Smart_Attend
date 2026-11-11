import '../../theme/smartattend_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../utils/validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static Color get _background => SmartAttendPalette.background;
  static Color get _text => SmartAttendPalette.text;
  static Color get _muted => SmartAttendPalette.muted;
  static Color get _shadow => SmartAttendPalette.shadow;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _studentId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _authService = AuthService();

  bool _busy = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _name.dispose();
    _studentId.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _friendlyRegistrationMessage(Object error) {
    if (error is AuthException) {
      // Use only known, safe messages; never show raw backend JSON to a student.
      final message = error.message.toLowerCase();
      if (message.contains('already registered') ||
          message.contains('already exists') ||
          message.contains('user already')) {
        return 'This email may already have an account. Try logging in or resetting your password.';
      }
      if (message.contains('rate limit') || message.contains('too many')) {
        return 'Too many requests. Please try again later.';
      }
      if (message.contains('invalid email')) {
        return 'Please enter a valid email address.';
      }
      if (message.contains('weak password') || message.contains('password')) {
        return 'Please choose a stronger password and try again.';
      }
    }
    // A database trigger can fail on an existing student ID or backend setup.
    // Do not claim a specific cause, or expose its internals.
    return 'We couldn’t create your account. Check your details or try again later. If this continues, contact support.';
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _authService.registerStudent(
        fullName: _name.text.trim(),
        universityStudentId: _studentId.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _background,
          title: Text('Check your email'),
          content: Text(
            'If your registration was accepted, check your inbox for a verification link. '
            'Confirm your email before logging in.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      // Development-only diagnostics; do not expose raw errors in production UI.
      assert(() {
        debugPrint('Registration failed: ${error.runtimeType}');
        return true;
      }());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyRegistrationMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required FormFieldValidator<String> validator,
    TextInputType? keyboardType,
    bool obscure = false,
    TextInputAction? action,
    Widget? suffix,
    FocusNode? focusNode,
    VoidCallback? onEditingComplete,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 19),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: SmartAttendPalette.highlight, offset: Offset(-5, -5), blurRadius: 10),
          BoxShadow(color: _shadow, offset: Offset(5, 5), blurRadius: 10),
        ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        textInputAction: action,
        onEditingComplete: onEditingComplete,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild when the app theme changes.
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text('Student Registration'),
        centerTitle: true,
        backgroundColor: _background,
        foregroundColor: _text,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 12),
                    Icon(Icons.person_add_alt_1_rounded, size: 66, color: _text),
                    SizedBox(height: 20),
                    Text('Create Account',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _text)),
                    SizedBox(height: 10),
                    Text('Register as a student',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted)),
                    SizedBox(height: 32),
                    _field(
                      label: 'Full name',
                      controller: _name,
                      icon: Icons.person_outline,
                      validator: Validators.name,
                      action: TextInputAction.next,
                    ),
                    _field(
                      label: 'University student ID',
                      controller: _studentId,
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      validator: Validators.studentId,
                      action: TextInputAction.next,
                    ),
                    _field(
                      label: 'Email',
                      controller: _email,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                      action: TextInputAction.next,
                    ),
                    _field(
                      label: 'Password',
                      controller: _password,
                      icon: Icons.lock_outline,
                      obscure: _hidePassword,
                      validator: Validators.password,
                      action: TextInputAction.next,
                      suffix: IconButton(
                        tooltip: _hidePassword ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(_hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                    _field(
                      label: 'Confirm password',
                      controller: _confirm,
                      icon: Icons.verified_user_outlined,
                      obscure: _hideConfirm,
                      action: TextInputAction.done,
                      validator: (value) {
                        if ((value ?? '').isEmpty) return 'Confirm your password';
                        if (value != _password.text) return 'Passwords do not match';
                        return null;
                      },
                      onEditingComplete: _submit,
                      suffix: IconButton(
                        tooltip: _hideConfirm ? 'Show confirmation' : 'Hide confirmation',
                        onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                        icon: Icon(_hideConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                    SizedBox(height: 15),
                    Container(
                      height: 58,
                      decoration: BoxDecoration(
                        color: _background,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: SmartAttendPalette.highlight, offset: Offset(-5, -5), blurRadius: 10),
                          BoxShadow(color: _shadow, offset: Offset(5, 5), blurRadius: 10),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _busy ? null : _submit,
                          child: Center(
                            child: _busy
                                ? CircularProgressIndicator(color: _text)
                                : Text('Create Account',
                                    style: TextStyle(fontSize: 18,
                                        fontWeight: FontWeight.bold, color: _text)),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: Text('Already have an account? Log In',
                          style: TextStyle(color: _text)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
