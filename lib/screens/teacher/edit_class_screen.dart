import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditClassScreen extends StatefulWidget {
  final Map<String, dynamic> classData;

  const EditClassScreen({super.key, required this.classData});

  @override
  State<EditClassScreen> createState() => _EditClassScreenState();
}

class _EditClassScreenState extends State<EditClassScreen> {
  static const _background = Color(0xFFE8EEF3);
  static const _text = Color(0xFF263238);
  static const _muted = Color(0xFF607D8B);
  static const _shadow = Color(0xFFB8C4CE);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _courseName;
  late final TextEditingController _courseCode;
  late final TextEditingController _semester;
  late final TextEditingController _section;
  final _courseNameFocus = FocusNode();
  final _courseCodeFocus = FocusNode();
  final _semesterFocus = FocusNode();
  final _sectionFocus = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _courseName = TextEditingController(
      text: widget.classData['course_name']?.toString() ?? '',
    );
    _courseCode = TextEditingController(
      text: widget.classData['course_code']?.toString() ?? '',
    );
    _semester = TextEditingController(
      text: widget.classData['semester']?.toString() ?? '',
    );
    _section = TextEditingController(
      text: widget.classData['section']?.toString() ?? '',
    );
  }

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

  String? _validateField(String? value, int index) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'This field is required';
    if (index == 1 &&
        !RegExp(r'^[A-Za-z][A-Za-z0-9 -]{1,19}$').hasMatch(text)) {
      return 'Enter a course code such as CSE-3212';
    }
    if (index == 3 && !RegExp(r'^[A-Za-z0-9]{1,10}$').hasMatch(text)) {
      return 'Use 1–10 letters or numbers';
    }
    return null;
  }

  void _nextField(int index, TextEditingController controller) {
    if (_saving) return;
    if (_validateField(controller.text, index) != null) {
      _formKey.currentState?.validate();
      return;
    }
    final next = [_courseCodeFocus, _semesterFocus, _sectionFocus];
    if (index < 3) {
      FocusScope.of(context).requestFocus(next[index]);
    } else {
      FocusScope.of(context).unfocus();
      _saveChanges();
    }
  }

  Future<void> _saveChanges() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Please log in again.');

      // Update only editable details. Never update class ID, teacher or join code.
      // RLS independently checks that the logged-in teacher owns the class.
      await client
          .from('semester_classes')
          .update({
            'course_name': _courseName.text.trim(),
            'course_code': _courseCode.text.trim().toUpperCase(),
            'semester': _semester.text.trim(),
            'section': _section.text.trim().toUpperCase(),
          })
          .eq('id', widget.classData['id'])
          .eq('teacher_id', user.id)
          .select('id')
          .single();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update class: ${error.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update class. Please try again.'),
        ),
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
        boxShadow: const [
          BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 8),
          BoxShadow(color: _shadow, offset: Offset(3, 3), blurRadius: 8),
        ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: !_saving,
        validator: (value) => _validateField(value, index),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        textCapitalization: index == 0 || index == 2
            ? TextCapitalization.words
            : TextCapitalization.characters,
        textInputAction: index == 3
            ? TextInputAction.done
            : TextInputAction.next,
        onFieldSubmitted: (_) => _nextField(index, controller),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Edit Class'),
        backgroundColor: _background,
        foregroundColor: _text,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Edit Semester Class',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Correct the class details. The join code and student enrollments will stay the same.',
                      style: TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 30),
                    _field(
                      'Course name',
                      _courseName,
                      Icons.book_outlined,
                      _courseNameFocus,
                      0,
                    ),
                    const SizedBox(height: 20),
                    _field(
                      'Course code',
                      _courseCode,
                      Icons.tag_rounded,
                      _courseCodeFocus,
                      1,
                    ),
                    const SizedBox(height: 20),
                    _field(
                      'Semester',
                      _semester,
                      Icons.calendar_month_outlined,
                      _semesterFocus,
                      2,
                    ),
                    const SizedBox(height: 20),
                    _field(
                      'Section',
                      _section,
                      Icons.groups_outlined,
                      _sectionFocus,
                      3,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Join code: ${widget.classData['join_code'] ?? ''} (unchanged)',
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: _background,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-5, -5),
                            blurRadius: 10,
                          ),
                          BoxShadow(
                            color: _shadow,
                            offset: Offset(5, 5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _saving ? null : _saveChanges,
                          child: Center(
                            child: _saving
                                ? const CircularProgressIndicator(color: _text)
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _text,
                                    ),
                                  ),
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
