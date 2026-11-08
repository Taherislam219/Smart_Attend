import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'join_class_screen.dart';
import 'enrolled_classes_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  static const Color _background = Color(0xFFE8EEF3);
  static const Color _text = Color(0xFF263238);
  static const Color _muted = Color(0xFF607D8B);
  static const Color _shadow = Color(0xFFB8C4CE);

  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  String _fullName = '';
  String _studentId = '';
  String _email = '';
  List<Map<String, dynamic>> _enrollments = [];

  @override
  void initState() {
    super.initState();
    _loadStudentProfile();
  }

  Future<void> _loadStudentProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('You are not logged in.');

      final profile = await _supabase
          .from('profiles')
          .select('full_name, university_student_id, role')
          .eq('id', user.id)
          .single();
      if (profile['role'] != 'student') {
        throw Exception('Student access only.');
      }

      // Secure RPC returns only this student's class requests,
      // including the actual course title (without exposing join codes).
      final enrollmentRows = await _supabase.rpc('get_my_class_enrollments');

      if (!mounted) return;
      setState(() {
        _fullName = profile['full_name'] as String? ?? '';
        _studentId = profile['university_student_id'] as String? ?? '';
        _email = user.email ?? '';
        _enrollments = List<Map<String, dynamic>>.from(enrollmentRows);
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load your student dashboard. Please retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openJoinClass() async {
    final requested = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const JoinClassScreen()));
    if (!mounted) return;
    if (requested == true) {
      await _loadStudentProfile();
    }
  }

  Future<void> _openEnrolledClasses() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const EnrolledClassesScreen()));
    if (mounted) await _loadStudentProfile();
  }

  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  Widget _neumorphicCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-5, -5),
            blurRadius: 12,
          ),
          BoxShadow(color: _shadow, offset: Offset(5, 5), blurRadius: 12),
        ],
      ),
      child: child,
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: _neumorphicCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: _muted, size: 26),
                const SizedBox(height: 18),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                if (onTap != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to view',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _enrollmentCard(Map<String, dynamic> enrollment) {
    final status = (enrollment['status'] as String? ?? 'pending');
    final courseName = enrollment['course_name']?.toString() ?? 'Class';
    final courseCode = enrollment['course_code']?.toString() ?? '';
    final semester = enrollment['semester']?.toString() ?? '';
    final section = enrollment['section']?.toString() ?? '';
    final label = switch (status) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Pending approval',
    };
    final statusIcon = switch (status) {
      'approved' => Icons.check_circle_outline_rounded,
      'rejected' => Icons.cancel_outlined,
      _ => Icons.hourglass_top_rounded,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: _neumorphicCard(
        child: Row(
          children: [
            Icon(statusIcon, color: _muted, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courseName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _text,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$courseCode • $semester • Section $section',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _text,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final approvedCount = _enrollments
        .where((entry) => entry['status'] == 'approved')
        .length;

    return RefreshIndicator(
      onRefresh: _loadStudentProfile,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              const Text(
                'SMARTATTEND',
                style: TextStyle(
                  color: _muted,
                  letterSpacing: 2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Student Dashboard',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              const SizedBox(height: 30),
              _neumorphicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _fullName,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Student ID: $_studentId',
                      style: const TextStyle(fontSize: 15, color: _muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _email,
                      style: const TextStyle(fontSize: 14, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  _statCard(
                    icon: Icons.menu_book_rounded,
                    title: 'Enrolled Classes',
                    value: '$approvedCount',
                    onTap: _openEnrolledClasses,
                  ),
                  const SizedBox(width: 18),
                  _statCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Attendance',
                    value: '—',
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _openJoinClass,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Join Class'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _text,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'My Semester Classes',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              const SizedBox(height: 18),
              if (_enrollments.isEmpty)
                _neumorphicCard(
                  child: const Column(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 42,
                        color: _muted,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'No class requests yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Use Join Class to request access to a semester class.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else ...[
                const Text(
                  'Enrollment requests and their current approval status:',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                for (final enrollment in _enrollments)
                  _enrollmentCard(enrollment),
              ],
              const SizedBox(height: 32),
              InkWell(
                onTap: _logout,
                borderRadius: BorderRadius.circular(18),
                child: _neumorphicCard(
                  padding: const EdgeInsets.all(16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: _text),
                      SizedBox(width: 10),
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _muted))
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: _muted, size: 42),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _text),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _loadStudentProfile();
                        },
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: _logout,
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                ),
              )
            : _buildDashboard(),
      ),
    );
  }
}
