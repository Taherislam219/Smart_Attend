import '../../theme/smartattend_theme.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'join_class_screen.dart';
import 'enrolled_classes_screen.dart';
import 'overall_attendance_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  static Color get _background => SmartAttendPalette.background;
  static Color get _text => SmartAttendPalette.text;
  static Color get _muted => SmartAttendPalette.muted;
  static Color get _shadow => SmartAttendPalette.shadow;

  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  String _fullName = '';
  String _studentId = '';
  String _email = '';
  String _attendancePercent = '—';
  List<Map<String, dynamic>> _enrollments = [];
  Timer? _attendanceTimer;
  bool _checkingActiveAttendance = false;
  bool _isMarkingAttendance = false;
  final Set<String> _promptedSheetIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadStudentProfile();
    // Lightweight foreground refresh: picks up teacher approvals and newly
    // opened attendance without requiring students to navigate two screens.
    _attendanceTimer = Timer.periodic(Duration(seconds: 30), (_) {
      _checkForActiveAttendance();
    });
  }

  @override
  void dispose() {
    _attendanceTimer?.cancel();
    super.dispose();
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
      // Load the overall percent separately: a slow report should never
      // prevent the student dashboard from opening.
      await _loadAttendanceSummary();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkForActiveAttendance();
        });
      }
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
        .push<bool>(MaterialPageRoute(builder: (_) => JoinClassScreen()));
    if (!mounted) return;
    if (requested == true) {
      await _loadStudentProfile();
    }
  }

  Future<void> _openEnrolledClasses() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EnrolledClassesScreen()));
    if (mounted) await _loadStudentProfile();
  }

  Future<void> _openOverallAttendance() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => OverallAttendanceScreen()));
    if (mounted) await _loadAttendanceSummary();
  }

  Future<void> _loadAttendanceSummary() async {
    final approved = _enrollments.where((e) => e['status'] == 'approved');
    try {
      final results = await Future.wait(
        approved.map(
          (item) => _supabase.rpc(
            'my_finalized_attendance',
            params: {'p_class_id': item['class_id'].toString()},
          ),
        ),
      );
      var present = 0;
      var counted = 0;
      for (final result in results) {
        for (final raw in result as List) {
          final status = (raw as Map)['attendance_status'];
          // NM (No Mark) counts as a missed finalized lecture.
          // Only P contributes to the present total.
          if (status == 'P' || status == 'A' || status == 'NM') {
            counted++;
            if (status == 'P') present++;
          }
        }
      }
      if (!mounted) return;
      setState(
        () => _attendancePercent = counted == 0
            ? '—'
            : '${(present * 100 / counted).toStringAsFixed(1)}%',
      );
    } catch (_) {
      // Keep the dashboard usable if reports are temporarily unavailable.
      if (mounted) setState(() => _attendancePercent = '—');
    }
  }

  /// Look for eligible OPEN sheets without exposing other classes or GPS
  /// coordinates. The RPCs already validate the current student on the server.
  Future<void> _checkForActiveAttendance() async {
    if (!mounted ||
        _checkingActiveAttendance ||
        _isMarkingAttendance ||
        _isLoading ||
        _errorMessage != null) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _checkingActiveAttendance = true;
    try {
      final data = await _supabase.rpc('get_my_class_enrollments');
      final latest = List<Map<String, dynamic>>.from(data as List);
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      setState(() => _enrollments = latest);
      for (final classroom in latest.where((e) => e['status'] == 'approved')) {
        final classId = classroom['class_id'].toString();
        final sheets = await _supabase.rpc(
          'get_my_class_attendance',
          params: {'p_class_id': classId},
        );
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        for (final sheet in List<Map<String, dynamic>>.from(sheets as List)) {
          final sheetId = sheet['sheet_id'].toString();
          final closes = DateTime.tryParse(
            sheet['closes_at']?.toString() ?? '',
          );
          if (sheet['checked_in_at'] != null ||
              closes == null ||
              !DateTime.now().isBefore(closes.toLocal()) ||
              _promptedSheetIds.contains(sheetId)) {
            continue;
          }
          _promptedSheetIds.add(sheetId);
          if (!mounted) return;
          await _showQuickAttendanceDialog(classroom, sheet);
          // Avoid stacking many popups; remaining sheets appear on refresh.
          return;
        }
      }
    } catch (_) {
      // This optional convenience must never block the normal dashboard.
    } finally {
      _checkingActiveAttendance = false;
    }
  }

  Future<void> _showQuickAttendanceDialog(
    Map<String, dynamic> classroom,
    Map<String, dynamic> sheet,
  ) async {
    final shouldMark = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.location_on_outlined, color: _text),
            SizedBox(width: 12),
            Expanded(child: Text('Attendance is open')),
          ],
        ),
        content: Text(
          '${classroom['course_name'] ?? 'Your class'}\n'
          '${sheet['lecture_title'] ?? 'Lecture'}\n\n'
          'Mark attendance now using GPS?',
          style: TextStyle(color: _text),
        ),
        actions: [
          SizedBox(width: 8),

          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Mark now'),
          ),
        ],
      ),
    );
    if (!mounted || shouldMark != true) return;
    await _quickMarkAttendance(sheet['sheet_id'].toString());
  }

  Future<void> _quickMarkAttendance(String sheetId) async {
    if (_isMarkingAttendance) return;
    setState(() => _isMarkingAttendance = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Enable Location Services before checking in.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Allow precise location access for SmartAttend.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(Duration(seconds: 30));
      if (position.accuracy > 50) {
        throw Exception('Location accuracy is too low. Try again on a phone.');
      }
      // Server enforces eligible roster, 5/10-minute deadline, classroom
      // radius and unique student submission. No client-only decisions.
      await _supabase.rpc(
        'mark_my_attendance',
        params: {
          'p_sheet_id': sheetId,
          'p_latitude': position.latitude,
          'p_longitude': position.longitude,
          'p_accuracy_meters': position.accuracy,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance recorded successfully.')),
      );
      await _loadAttendanceSummary();
    } catch (error) {
      if (!mounted) return;
      // Avoid exposing raw SQL errors in the dashboard popup.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not check in. Check GPS, classroom distance and closing time, then try from your class.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isMarkingAttendance = false);
    }
  }

  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed. Please try again.')),
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
        boxShadow: [
          BoxShadow(
            color: SmartAttendPalette.highlight,
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
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: _muted, size: 26),
                SizedBox(height: 18),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                ),
                SizedBox(height: 6),
                Text(title, style: TextStyle(color: _muted, fontSize: 12)),
                if (onTap != null) ...[
                  SizedBox(height: 8),
                  Text(
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
      padding: EdgeInsets.only(bottom: 18),
      child: _neumorphicCard(
        child: Row(
          children: [
            Icon(statusIcon, color: _muted, size: 30),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courseName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _text,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '$courseCode • $semester • Section $section',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  SizedBox(height: 9),
                  Text(
                    label,
                    style: TextStyle(
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
          constraints: BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: EdgeInsets.all(24),
            children: [
              Text(
                'SMARTATTEND',
                style: TextStyle(
                  color: _muted,
                  letterSpacing: 2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Student Dashboard',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              SizedBox(height: 30),
              _neumorphicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      _fullName,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Student ID: $_studentId',
                      style: TextStyle(fontSize: 15, color: _muted),
                    ),
                    SizedBox(height: 6),
                    Text(_email, style: TextStyle(fontSize: 14, color: _muted)),
                  ],
                ),
              ),
              SizedBox(height: 28),
              Row(
                children: [
                  _statCard(
                    icon: Icons.menu_book_rounded,
                    title: 'Enrolled Classes',
                    value: '$approvedCount',
                    onTap: _openEnrolledClasses,
                  ),
                  SizedBox(width: 18),
                  _statCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Attendance',
                    value: _attendancePercent,
                    onTap: _openOverallAttendance,
                  ),
                ],
              ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _openJoinClass,
                  icon: Icon(Icons.add_rounded),
                  label: Text('Join Class'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _text,
                    foregroundColor: SmartAttendPalette.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30),
              Text(
                'My Semester Classes',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              SizedBox(height: 18),
              if (_enrollments.isEmpty)
                _neumorphicCard(
                  child: Column(
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
                Text(
                  'Enrollment requests and their current approval status:',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                SizedBox(height: 16),
                for (final enrollment in _enrollments)
                  _enrollmentCard(enrollment),
              ],
              SizedBox(height: 32),
              SizedBox(height: 30),
            ],
          ),
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
        title: Text('Student Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: Icon(Icons.more_vert_rounded, color: _text),
            onSelected: (action) async {
              if (action == 'theme') {
                SmartAttendTheme.toggle();
              } else if (action == 'logout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text('Log out?'),
                    content: Text(
                      'Are you sure you want to log out of SmartAttend?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text('Log out'),
                      ),
                    ],
                  ),
                );
                if (!mounted || confirm != true) return;
                await _logout();
              }
            },
            itemBuilder: (menuContext) => [
              PopupMenuItem<String>(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(
                      SmartAttendTheme.isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    SizedBox(width: 12),
                    Text(SmartAttendTheme.isDark ? 'Light Mode' : 'Dark Mode'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _muted))
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: _muted, size: 42),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _text),
                      ),
                      SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _loadStudentProfile();
                        },
                        child: Text('Retry'),
                      ),
                      TextButton(onPressed: _logout, child: Text('Logout')),
                    ],
                  ),
                ),
              )
            : _buildDashboard(),
      ),
    );
  }
}
