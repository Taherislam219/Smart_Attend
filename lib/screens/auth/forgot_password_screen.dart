import '../../theme/smartattend_theme.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static Color get _background => SmartAttendPalette.background;
  static Color get _text => SmartAttendPalette.text;
  late final TextEditingController _email;
  bool _sending = false;
  final bool _sent = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Enter a valid email address.')));
      return;
    }
    setState(() => _sending = true);
    try {
      // Web runs on a fixed localhost port; iOS/Android use a registered deep link.
      final redirect = kIsWeb
          ? '${Uri.base.origin}/'
          : 'io.smartattend.app://reset-password/';
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirect,
      );
      if (!mounted) return;
      // Return to Login after requesting the email. The actual recovery
      // link still opens ResetPasswordScreen through the auth listener.
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not request a reset email. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      title: Text('Forgot Password'),
      backgroundColor: _background,
      foregroundColor: _text,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 500),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.all(26),
          children: [
            Icon(Icons.mark_email_read_outlined, size: 58, color: _text),
            SizedBox(height: 24),
            Text(
              _sent
                  ? 'If an account exists for this email, a recovery link will arrive shortly.'
                  : 'Enter your registered email address to request a password reset.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _text, fontSize: 16),
            ),
            SizedBox(height: 28),
            if (!_sent) ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              SizedBox(height: 22),
              ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _text,
                  foregroundColor: SmartAttendPalette.background,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_sending ? 'Sending...' : 'Send Reset Link'),
              ),
            ],
            if (_sent)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Return to Login'),
              ),
          ],
        ),
      ),
    ),
  );
}
