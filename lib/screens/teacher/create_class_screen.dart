import '../../theme/smartattend_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  static Color get _background => SmartAttendPalette.background;
  static Color get _text => SmartAttendPalette.text;
  static Color get _muted => SmartAttendPalette.muted;
  static Color get _shadow => SmartAttendPalette.shadow;

  final _formKey = GlobalKey<FormState>();
  final _courseName = TextEditingController();
  final _courseCode = TextEditingController();
  final _semester = TextEditingController();
  final _section = TextEditingController();
  final _courseNameFocus = FocusNode();
  final _courseCodeFocus = FocusNode();
  final _semesterFocus = FocusNode();
  final _sectionFocus = FocusNode();
  bool _saving = false;

  @override
  void dispose() {
    _courseName.dispose();
    _courseCode.dispose();
    _semester.dispose();
    _section.dispose();
    _courseNameFocus.dispose();
    _courseCodeFocus.dispose();
    _semesterFocus.dispose();
    _sectionFocus.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    return null;
  }

  // Validate only the current field before moving focus.
  String? _validateField(String? value, int index) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    final text = value!.trim();
    if (index == 1 && !RegExp(r'^[A-Za-z][A-Za-z0-9 -]{1,19}$').hasMatch(text)) {
      return 'Enter a course code such as CSE-3212';
    }
    if (index == 3 && !RegExp(r'^[A-Za-z0-9]{1,10}$').hasMatch(text)) {
      return 'Use 1–10 letters or numbers';
    }
    return null;
  }

  void _nextField(int index, TextEditingController controller) {
    final error = _validateField(controller.text, index);
    if (error != null) {
      // Show the validator message and keep focus in this field.
      _formKey.currentState?.validate();
      return;
    }
    final targets = [_courseCodeFocus, _semesterFocus, _sectionFocus];
    if (index < 3) {
      FocusScope.of(context).requestFocus(targets[index]);
    } else {
      FocusScope.of(context).unfocus();
      _createClass();
    }
  }

  Future<void> _createClass() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Please log in again.');

      // The database checks that teacher_id belongs to the signed-in teacher.
      // The database trigger generates join_code; Flutter never creates it.
      await client.from('semester_classes').insert({
        'teacher_id': user.id,
        'course_name': _courseName.text.trim(),
        'course_code': _courseCode.text.trim().toUpperCase(),
        'semester': _semester.text.trim(),
        'section': _section.text.trim().toUpperCase(),
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create class: ${error.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create class. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon,
    FocusNode focusNode,
    int index,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: SmartAttendPalette.highlight, offset: Offset(-3, -3), blurRadius: 8),
          BoxShadow(color: _shadow, offset: Offset(3, 3), blurRadius: 8),
        ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        validator: (value) => _validateField(value, index),
        enabled: !_saving,
        textCapitalization: index == 0 || index == 2
            ? TextCapitalization.words
            : TextCapitalization.characters,
        textInputAction: index == 3 ? TextInputAction.done : TextInputAction.next,
        onFieldSubmitted: (_) => _nextField(index, controller),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
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
        title: Text('Create Class'),
        backgroundColor: _background,
        foregroundColor: _text,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(26),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('New Semester Class',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _text)),
                    SizedBox(height: 8),
                    Text('Enter the class details. A join code will be generated automatically.',
                        style: TextStyle(color: _muted)),
                    SizedBox(height: 30),
                    _field('Course name (e.g. Database Management Systems)', _courseName, Icons.book_outlined, _courseNameFocus, 0),
                    SizedBox(height: 20),
                    _field('Course code (e.g. CSE 321)', _courseCode, Icons.tag_rounded, _courseCodeFocus, 1),
                    SizedBox(height: 20),
                    _field('Semester (e.g. Fall 2026)', _semester, Icons.calendar_month_outlined, _semesterFocus, 2),
                    SizedBox(height: 20),
                    _field('Section (e.g. A)', _section, Icons.groups_outlined, _sectionFocus, 3),
                    SizedBox(height: 30),
                    Container(
                      height: 56,
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
                          onTap: _saving ? null : _createClass,
                          child: Center(
                            child: _saving
                                ? CircularProgressIndicator(color: _text)
                                : Text('Save Class',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
                          ),
                        ),
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
