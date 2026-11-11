import '../../theme/smartattend_theme.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'student_attendance_history_screen.dart';

/// Overall percentage across ALL finalized lectures in approved classes.
/// A lecture is weighted equally; class percentages are not averaged.
class OverallAttendanceScreen extends StatefulWidget {
  const OverallAttendanceScreen({super.key});

  @override
  State<OverallAttendanceScreen> createState() =>
      _OverallAttendanceScreenState();
}

class _OverallAttendanceScreenState extends State<OverallAttendanceScreen> {
  static Color get _bg => SmartAttendPalette.background;
  static Color get _ink => SmartAttendPalette.text;
  static Color get _muted => SmartAttendPalette.muted;
  static Color get _shadow => SmartAttendPalette.shadow;
  static const double _lowThreshold = 75.0;

  bool _loading = true;
  String? _error;
  List<_ClassAttendance> _classes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      if (supabase.auth.currentUser == null) throw StateError('Not signed in');
      final enrollmentData = await supabase.rpc('get_my_class_enrollments');
      final approved = List<Map<String, dynamic>>.from(enrollmentData as List)
          .where((row) => row['status'] == 'approved')
          .toList();

      final items = await Future.wait(
        approved.map((row) async {
          final classId = row['class_id'].toString();
          final data = await supabase.rpc(
            'my_finalized_attendance',
            params: {'p_class_id': classId},
          );
          final records = List<Map<String, dynamic>>.from(data as List);
          final present = records
              .where((r) => r['attendance_status'] == 'P')
              .length;
          final absent = records
              .where((r) => r['attendance_status'] == 'A')
              .length;
          final notMarked = records
              .where((r) => r['attendance_status'] == 'NM')
              .length;
          return _ClassAttendance(
            id: classId,
            name: row['course_name']?.toString() ?? 'Unnamed Course',
            code: row['course_code']?.toString() ?? '',
            semester: row['semester']?.toString() ?? '',
            section: row['section']?.toString() ?? '',
            present: present,
            absent: absent,
            notMarked: notMarked,
          );
        }),
      );
      if (!mounted) return;
      setState(() {
        _classes = items;
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load attendance summary. Please retry.';
          _loading = false;
        });
      }
    }
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(bottom: 22),
    padding: EdgeInsets.all(21),
    decoration: BoxDecoration(
      color: _bg,
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

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild when the app theme changes.
    final present = _classes.fold<int>(
      0,
      (total, item) => total + item.present,
    );
    final absent = _classes.fold<int>(0, (total, item) => total + item.absent);
    final notMarked = _classes.fold<int>(
      0,
      (total, item) => total + item.notMarked,
    );
    final counted = present + absent + notMarked;
    final overall = counted == 0 ? null : present * 100.0 / counted;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text('Overall Attendance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _muted))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                  TextButton(onPressed: _load, child: Text('Retry')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: EdgeInsets.all(24),
                    children: [
                      _card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ALL APPROVED CLASSES',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                letterSpacing: 1.4,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              overall == null
                                  ? 'No finalized lectures yet'
                                  : '${overall.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Present: $present  •  Absent: $absent  •  '
                              'No Mark: $notMarked  •  Counted: $counted',
                              style: TextStyle(color: _muted),
                            ),
                            if (overall != null && overall < _lowThreshold) ...[
                              SizedBox(height: 12),
                              Text(
                                'Below 75% attendance',
                                style: TextStyle(
                                  color: Color(0xFFB45309),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        'Attendance by Course',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      SizedBox(height: 18),
                      if (_classes.isEmpty)
                        _card(
                          Text(
                            'No approved classes yet.',
                            style: TextStyle(color: _muted),
                          ),
                        ),
                      for (final item in _classes)
                        InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StudentAttendanceHistoryScreen(
                                  classId: item.id,
                                  courseName: item.name,
                                ),
                              ),
                            );
                            if (mounted) await _load();
                          },
                          child: _card(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _ink,
                                    fontSize: 17,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '${item.code} • ${item.semester} • '
                                  'Section ${item.section}',
                                  style: TextStyle(color: _muted),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  item.counted == 0
                                      ? 'No finalized lectures'
                                      : '${item.percentage!.toStringAsFixed(1)}% attendance',
                                  style: TextStyle(
                                    color: _ink,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'P: ${item.present}  •  A: ${item.absent}  •  NM: ${item.notMarked}',
                                  style: TextStyle(color: _muted),
                                ),
                                if (item.percentage != null &&
                                    item.percentage! < _lowThreshold) ...[
                                  SizedBox(height: 7),
                                  Text(
                                    'Low attendance',
                                    style: TextStyle(color: Color(0xFFB45309)),
                                  ),
                                ],
                                SizedBox(height: 8),
                                Text(
                                  'Tap for lecture history',
                                  style: TextStyle(color: _muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(height: 12),
                      Text(
                        'Every finalized lecture counts, including NM (No Mark) '
                        'as absent. Draft, open and cancelled sheets are excluded.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ClassAttendance {
  final String id;
  final String name;
  final String code;
  final String semester;
  final String section;
  final int present;
  final int absent;
  final int notMarked;

  const _ClassAttendance({
    required this.id,
    required this.name,
    required this.code,
    required this.semester,
    required this.section,
    required this.present,
    required this.absent,
    required this.notMarked,
  });

  int get counted => present + absent + notMarked;
  double? get percentage => counted == 0 ? null : present * 100.0 / counted;
}
