import '../../theme/smartattend_theme.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Displays only the signed-in student's own finalized attendance records.
class StudentAttendanceHistoryScreen extends StatefulWidget {
  final String classId;
  final String courseName;
  const StudentAttendanceHistoryScreen({
    super.key,
    required this.classId,
    required this.courseName,
  });

  @override
  State<StudentAttendanceHistoryScreen> createState() =>
      _StudentAttendanceHistoryScreenState();
}

class _StudentAttendanceHistoryScreenState
    extends State<StudentAttendanceHistoryScreen> {
  static Color get bg => SmartAttendPalette.background;
  static Color get ink => SmartAttendPalette.text;
  static Color get muted => SmartAttendPalette.muted;
  static Color get shadow => SmartAttendPalette.shadow;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await Supabase.instance.client.rpc(
        'my_finalized_attendance',
        params: {'p_class_id': widget.classId},
      );
      if (!mounted) return;
      setState(() => rows = List<Map<String, dynamic>>.from(data as List));
    } on PostgrestException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to load attendance history.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String dateLabel(dynamic value) {
    final time = DateTime.tryParse(value?.toString() ?? '');
    if (time == null) return 'Unknown date';
    final dt = time.toUtc().add(Duration(hours: 6));
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild when the app theme changes.
    final present = rows.where((r) => r['attendance_status'] == 'P').length;
    final absent = rows.where((r) => r['attendance_status'] == 'A').length;
    final notMarked = rows.where((r) => r['attendance_status'] == 'NM').length;
    final percentage = rows.isEmpty
        ? '—'
        : '${(present * 100 / rows.length).toStringAsFixed(1)}%';
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('My Attendance History'),
        backgroundColor: bg,
        foregroundColor: ink,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: load,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: EdgeInsets.all(24),
              children: [
                Text(
                  widget.courseName,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
                SizedBox(height: 18),
                if (loading)
                  Center(child: CircularProgressIndicator())
                else if (error != null)
                  Text(error!, style: TextStyle(color: ink))
                else ...[
                  Container(
                    padding: EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: SmartAttendPalette.highlight,
                          offset: Offset(-5, -5),
                          blurRadius: 12,
                        ),
                        BoxShadow(
                          color: shadow,
                          offset: Offset(5, 5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance: $percentage',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Present: $present   Absent: $absent   '
                          'No Mark: $notMarked   Finalized: ${rows.length}',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 28),
                  if (rows.isEmpty)
                    Text(
                      'No finalized attendance records yet.',
                      style: TextStyle(color: muted),
                    )
                  else
                    for (final row in rows) ...[
                      ListTile(
                        title: Text(
                          row['lecture_title']?.toString() ?? 'Lecture',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          dateLabel(row['lecture_date']),
                          style: TextStyle(color: muted),
                        ),
                        trailing: Text(
                          row['attendance_status'] == 'P'
                              ? 'Present'
                              : row['attendance_status'] == 'NM'
                              ? 'No Mark'
                              : 'Absent',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Divider(),
                    ],
                  SizedBox(height: 22),
                  Text(
                    'NM (No Mark) counts as absent. Only finalized lectures '
                    'count; corrections appear after refreshing.',
                    style: TextStyle(color: muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
