import '../../theme/smartattend_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Opened only when Supabase reports a passwordRecovery event.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static Color get _background => SmartAttendPalette.background;
  static Color get _text => SmartAttendPalette.text;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _key = GlobalKey<FormState>();
  bool _saving = false;
  bool _show = false;

  @override
  void dispose() { _password.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _password.text));
      // Recovery establishes a temporary session. End it to require normal login.
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password changed. Please log in.')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset failed. Try the link again.')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(title: Text('Set New Password'),
      backgroundColor: _background, foregroundColor: _text,
      automaticallyImplyLeading: false),
    body: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 500),
      child: Form(key: _key, child: ListView(shrinkWrap: true,
        padding: EdgeInsets.all(26), children: [
          Icon(Icons.lock_reset_rounded, size: 60, color: _text),
          SizedBox(height: 20),
          Text('Choose a new password', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _text)),
          SizedBox(height: 30),
          TextFormField(controller: _password, obscureText: !_show,
            decoration: InputDecoration(labelText: 'New password',
              prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(onPressed: () => setState(() => _show = !_show),
                icon: Icon(_show ? Icons.visibility_off : Icons.visibility)),
              border: OutlineInputBorder()),
            validator: (value) => value == null || value.length < 8
              ? 'Use at least 8 characters.' : null),
          SizedBox(height: 18),
          TextFormField(controller: _confirm, obscureText: !_show,
            decoration: InputDecoration(labelText: 'Confirm new password',
              prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
            validator: (value) => value != _password.text
              ? 'Passwords do not match.' : null),
          SizedBox(height: 28),
          ElevatedButton(onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: _text,
              foregroundColor: SmartAttendPalette.background,
              padding: EdgeInsets.symmetric(vertical: 16)),
            child: Text(_saving ? 'Saving...' : 'Update Password')),
        ])))),
  );
}
