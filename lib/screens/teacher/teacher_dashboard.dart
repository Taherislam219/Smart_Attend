import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'create_class_screen.dart';
import 'edit_class_screen.dart';
import 'enrollment_requests_screen.dart';
import 'attendance_sheets_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  static const _background = Color(0xFFE8EEF3);
  static const _text = Color(0xFF263238);
  static const _muted = Color(0xFF607D8B);
  static const _shadow = Color(0xFFB8C4CE);

  final _supabase = Supabase.instance.client;
  String _teacherName = 'Teacher';
  String _teacherEmail = '';
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;
  bool _classesLoading = false;
  bool _loggingOut = false;
  String? _classesError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not signed in');
      final profile = await _supabase
          .from('profiles')
          .select('full_name, role')
          .eq('id', user.id)
          .single();
      if (profile['role'] != 'teacher') throw Exception('Not a teacher');
      if (!mounted) return;
      setState(() {
        _teacherName = profile['full_name'] as String;
        _teacherEmail = user.email ?? '';
        _loading = false;
      });
      await _loadClasses();
    } catch (_) {
      await _supabase.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher verification failed. Please log in again.'),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _loadClasses() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() {
      _classesLoading = true;
      _classesError = null;
    });
    try {
      final rows = await _supabase
          .from('semester_classes')
          .select('id, course_name, course_code, semester, section, join_code')
          .eq('teacher_id', user.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() => _classes = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      if (!mounted) return;
      setState(() => _classesError = 'Could not load classes. Tap Retry.');
    } finally {
      if (mounted) setState(() => _classesLoading = false);
    }
  }

  Future<void> _openCreateClass() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreateClassScreen()));
    if (!mounted) return;
    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class created successfully!')),
      );
      await _loadClasses();
    }
  }

  Future<void> _openEditClass(Map<String, dynamic> classData) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditClassScreen(classData: classData)),
    );
    if (!mounted) return;
    if (updated == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class updated successfully!')),
      );
      await _loadClasses();
    }
  }

  Future<void> _openEnrollmentRequests(Map<String, dynamic> classData) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EnrollmentRequestsScreen(
          classId: classData['id'].toString(),
          courseName: classData['course_name'].toString(),
          section: classData['section'].toString(),
        ),
      ),
    );
  }

  Future<void> _openAttendanceSheets(Map<String, dynamic> classData) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceSheetsScreen(
          classId: classData['id'].toString(),
          courseName: classData['course_name'].toString(),
          section: classData['section'].toString(),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-6, -6),
            blurRadius: 12,
          ),
          BoxShadow(color: _shadow, offset: Offset(6, 6), blurRadius: 12),
        ],
      ),
      child: child,
    );
  }

  Widget _classCard(Map<String, dynamic> item) {
    final joinCode = item['join_code']?.toString() ?? '';
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['course_name']?.toString() ?? '',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${item['course_code']}  •  ${item['semester']}  •  Section ${item['section']}',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openEditClass(item),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Class'),
              style: TextButton.styleFrom(foregroundColor: _text),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openEnrollmentRequests(item),
              icon: const Icon(Icons.people_outline_rounded),
              label: const Text('Enrollment Requests'),
              style: TextButton.styleFrom(foregroundColor: _text),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openAttendanceSheets(item),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Attendance Sheets'),
              style: TextButton.styleFrom(foregroundColor: _text),
            ),
          ),
          Row(
            children: [
              const Text('Join code: ', style: TextStyle(color: _muted)),
              Expanded(
                child: SelectableText(
                  joinCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _text,
                    fontSize: 17,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy join code',
                icon: const Icon(Icons.copy_rounded, color: _text),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: joinCode));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Join code copied')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        backgroundColor: _background,
        foregroundColor: _text,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _loggingOut ? null : _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _text))
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: RefreshIndicator(
                    onRefresh: _loadClasses,
                    child: ListView(
                      padding: const EdgeInsets.all(26),
                      children: [
                        const SizedBox(height: 12),
                        _card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.co_present_rounded,
                                size: 46,
                                color: _text,
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Welcome,',
                                style: TextStyle(fontSize: 16, color: _muted),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _teacherName,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: _text,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _teacherEmail,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 38),
                        const Text(
                          'My Classes',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_classesLoading)
                          const Center(
                            child: CircularProgressIndicator(color: _text),
                          )
                        else if (_classesError != null)
                          _card(
                            Column(
                              children: [
                                Text(
                                  _classesError!,
                                  style: const TextStyle(color: _muted),
                                ),
                                TextButton(
                                  onPressed: _loadClasses,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        else if (_classes.isEmpty)
                          _card(
                            const Column(
                              children: [
                                Icon(
                                  Icons.class_outlined,
                                  size: 48,
                                  color: _muted,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No classes yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _text,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Your semester classes will appear here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _muted),
                                ),
                              ],
                            ),
                          )
                        else
                          for (final item in _classes) ...[
                            _classCard(item),
                            const SizedBox(height: 20),
                          ],
                        const SizedBox(height: 28),
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
                              onTap: _openCreateClass,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded, color: _text),
                                  SizedBox(width: 8),
                                  Text(
                                    'Create Class',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
