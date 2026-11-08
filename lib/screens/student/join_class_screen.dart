import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({super.key});

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  static const _background = Color(0xFFE8EEF3);
  static const _text = Color(0xFF263238);
  static const _muted = Color(0xFF607D8B);
  static const _shadow = Color(0xFFB8C4CE);

  final _formKey = GlobalKey<FormState>();
  final _joinCodeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  String? _validateJoinCode(String? value) {
    final code = (value ?? '').trim().toUpperCase();
    if (code.isEmpty) return 'Please enter the class join code.';
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)) {
      return 'Enter the 8-character code your teacher shared.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final code = _joinCodeController.text.trim().toUpperCase();
      await Supabase.instance.client.rpc(
        'request_class_enrollment',
        params: {'p_join_code': code},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent! Waiting for teacher approval.'),
        ),
      );
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      // Avoid exposing internal database details in the student UI.
      final detail = error.message.toLowerCase();
      final message =
          detail.contains('duplicate') ||
              detail.contains('already') ||
              detail.contains('existing')
          ? 'You have already requested to join this class.'
          : detail.contains('invalid') ||
                detail.contains('not found') ||
                detail.contains('unknown')
          ? 'Class code not found. Please check the code.'
          : 'Unable to send request. Check the code and try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Join a Class'),
        backgroundColor: _background,
        foregroundColor: _text,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _background,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-5, -5),
                            blurRadius: 12,
                          ),
                          BoxShadow(
                            color: _shadow,
                            offset: Offset(5, 5),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.vpn_key_rounded,
                            size: 50,
                            color: _text,
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'Enter your class code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _text,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Ask your teacher for the 8-character join code. '
                            'Joining requires teacher approval.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                          const SizedBox(height: 26),
                          TextFormField(
                            controller: _joinCodeController,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            maxLength: 8,
                            autocorrect: false,
                            enableSuggestions: false,
                            validator: _validateJoinCode,
                            onFieldSubmitted: (_) {
                              if (_validateJoinCode(_joinCodeController.text) ==
                                  null) {
                                _submit();
                              } else {
                                _formKey.currentState?.validate();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Class join code',
                              hintText: '8 characters',
                              prefixIcon: const Icon(Icons.key_rounded),
                              filled: true,
                              fillColor: _background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _submit,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                              label: Text(
                                _isSubmitting
                                    ? 'Sending...'
                                    : 'Request to Join',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _text,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
