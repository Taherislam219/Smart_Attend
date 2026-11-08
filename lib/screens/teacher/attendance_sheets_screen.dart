import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lesson 14B: create and list DRAFT attendance sheets for one teacher-owned class.
/// Opening GPS check-in and finalizing sheets will be implemented in later lessons.
class AttendanceSheetsScreen extends StatefulWidget {
  final String classId;
  final String courseName;
  final String section;

  const AttendanceSheetsScreen({
    super.key,
    required this.classId,
    required this.courseName,
    required this.section,
  });

  @override
  State<AttendanceSheetsScreen> createState() => _AttendanceSheetsScreenState();
}

class _AttendanceSheetsScreenState extends State<AttendanceSheetsScreen> {
  static const _background = Color(0xFFE8EEF3);
  static const _text = Color(0xFF263238);
  static const _muted = Color(0xFF607D8B);
  static const _shadow = Color(0xFFB8C4CE);

  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _sheets = [];

  @override
  void initState() {
    super.initState();
    _loadSheets();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadSheets() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _supabase
          .from('attendance_sheets')
          .select('id, lecture_title, status, created_at, radius_meters')
          .eq('class_id', widget.classId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _sheets = List<Map<String, dynamic>>.from(response);
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load sheets: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load attendance sheets.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createSheet() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final title = _titleController.text.trim();
    setState(() => _saving = true);
    try {
      // Server defaults to draft; do not submit GPS coordinates or status.
      // RLS confirms that the current teacher owns this class.
      await _supabase.from('attendance_sheets').insert({
        'class_id': widget.classId,
        'lecture_title': title,
      });
      _titleController.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft attendance sheet created.')),
      );
      await _loadSheets();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create sheet: ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create sheet. Please retry.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _background,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(color: Colors.white, offset: Offset(-5, -5), blurRadius: 11),
        BoxShadow(color: _shadow, offset: Offset(5, 5), blurRadius: 11),
      ],
    ),
    child: child,
  );

  String _dateLabel(Object? raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return 'Date unavailable';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        title: const Text('Attendance Sheets'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadSheets,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: RefreshIndicator(
              onRefresh: _loadSheets,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 26,
                ),
                children: [
                  Text(
                    widget.courseName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Section ${widget.section}',
                    style: const TextStyle(fontSize: 15, color: _muted),
                  ),
                  const SizedBox(height: 30),
                  _card(
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Prepare a lecture',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: _text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create a draft first. Students cannot check in until '
                            'the teacher opens the sheet in a later step.',
                            style: TextStyle(color: _muted),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _titleController,
                            maxLength: 100,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _createSheet(),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Enter a lecture title';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'Lecture title',
                              hintText: 'Lecture 1 - Introduction',
                              prefixIcon: const Icon(Icons.menu_book_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _saving ? null : _createSheet,
                            icon: _saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_rounded),
                            label: const Text('Create Draft Sheet'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _text,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  const Text(
                    'Lectures',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(color: _muted),
                    )
                  else if (_error != null)
                    _card(
                      Column(
                        children: [
                          Text(_error!, style: const TextStyle(color: _text)),
                          TextButton(
                            onPressed: _loadSheets,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (_sheets.isEmpty)
                    _card(
                      const Text(
                        'No attendance sheets yet.',
                        style: TextStyle(color: _muted),
                      ),
                    )
                  else
                    for (final sheet in _sheets) ...[
                      _card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sheet['lecture_title']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _text,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              'Status: ${sheet['status']}',
                              style: const TextStyle(color: _muted),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _dateLabel(sheet['created_at']),
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
