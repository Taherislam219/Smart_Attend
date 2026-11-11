import '../../theme/smartattend_theme.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Review eligible students, finalize/cancel a lecture, and audit corrections.
/// All sensitive operations use teacher-verified PostgreSQL RPCs.
class ManageAttendanceScreen extends StatefulWidget {
  final String sheetId;
  final String lectureTitle;
  final String initialStatus;
  final String? closesAt;

  const ManageAttendanceScreen({
    super.key,
    required this.sheetId,
    required this.lectureTitle,
    required this.initialStatus,
    this.closesAt,
  });

  @override
  State<ManageAttendanceScreen> createState() => _ManageAttendanceScreenState();
}

class _ManageAttendanceScreenState extends State<ManageAttendanceScreen> {
  static Color get _background => SmartAttendPalette.background;
  static Color get _text => SmartAttendPalette.text;
  static Color get _muted => SmartAttendPalette.muted;
  static Color get _shadow => SmartAttendPalette.shadow;

  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _roster = [];
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _busy = false;
  final Set<String> _selectedStudentIds = <String>{};
  String? _error;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Refresh status because it could have changed in another session.
      final sheet = await _client
          .from('attendance_sheets')
          .select('status')
          .eq('id', widget.sheetId)
          .single();
      final students = await _client.rpc(
        'get_teacher_sheet_roster',
        params: {'p_sheet_id': widget.sheetId},
      );
      final corrections = await _client.rpc(
        'get_teacher_sheet_corrections',
        params: {'p_sheet_id': widget.sheetId},
      );
      if (!mounted) return;
      setState(() {
        _status = sheet['status'].toString();
        _roster = List<Map<String, dynamic>>.from(students as List);
        _history = List<Map<String, dynamic>>.from(corrections as List);
        _selectedStudentIds.clear();
      });
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load attendance details.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _pretty(String status) {
    switch (status) {
      case 'not_submitted':
        return 'Not submitted';
      case 'not_counted':
        return 'Not counted';
      default:
        return status.isEmpty
            ? 'Unknown'
            : '${status[0].toUpperCase()}${status.substring(1)}';
    }
  }

  String _dateLabel(Object? raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return 'Unknown time';
    final bdt = dt.toUtc().add(Duration(hours: 6));
    final hour = bdt.hour % 12 == 0 ? 12 : bdt.hour % 12;
    return '${bdt.day}/${bdt.month}/${bdt.year} '
        '$hour:${bdt.minute.toString().padLeft(2, '0')} '
        '${bdt.hour < 12 ? 'AM' : 'PM'} BDT';
  }

  Future<bool> _confirm(String title, String description, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _background,
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _performAction(
    String functionName,
    String successMessage,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _client.rpc(functionName, params: {'p_sheet_id': widget.sheetId});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
      await _refresh();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action failed. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize() async {
    final yes = await _confirm(
      'Finalize attendance?',
      'After the check-in window closes, students who did not submit will '
          'be marked Absent. Corrections will be recorded with an audit trail.',
      'Finalize',
    );
    if (yes) {
      await _performAction(
        'finalize_attendance_sheet',
        'Attendance finalized.',
      );
    }
  }

  Future<void> _cancel() async {
    final yes = await _confirm(
      'Cancel this lecture?',
      'Cancelled lectures do not count toward attendance percentages. '
          'This cannot be undone.',
      'Cancel lecture',
    );
    if (yes) {
      await _performAction('cancel_attendance_sheet', 'Lecture cancelled.');
    }
  }

  Future<void> _correct(Map<String, dynamic> student) async {
    if (_busy) return;

    final current = student['attendance_status']?.toString() ?? '';
    // The popup manages and disposes its own text controller. This avoids
    // disposing it while the closing dialog is still animating.
    final change = await showDialog<_AttendanceCorrection>(
      context: context,
      builder: (_) => _AttendanceCorrectionDialog(
        studentName: student['full_name']?.toString() ?? 'Student',
        currentStatus: current,
      ),
    );

    // Back, Cancel, outside tap and system back all mean: do nothing.
    if (!mounted || change == null) return;

    setState(() => _busy = true);
    try {
      await _client.rpc(
        'correct_attendance',
        params: {
          'p_sheet_id': widget.sheetId,
          'p_student_id': student['student_id'],
          'p_new_status': change.status,
          'p_reason': change.reason,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Correction saved with audit history.')),
      );
      await _refresh();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save correction.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulkCorrect() async {
    if (_busy || _selectedStudentIds.isEmpty || _status != 'finalized') return;

    final selected = _roster
        .where(
          (student) =>
              _selectedStudentIds.contains(student['student_id'].toString()),
        )
        .toList();
    final result = await showDialog<_AttendanceCorrection>(
      context: context,
      builder: (_) => _AttendanceCorrectionDialog(
        studentName: '${selected.length} selected students',
        currentStatus: '',
        bulkMode: true,
      ),
    );
    if (!mounted || result == null) return;

    // Never send students whose status already matches the chosen target.
    final eligible = selected
        .where(
          (student) =>
              student['attendance_status']?.toString() != result.status,
        )
        .toList();
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No selected students need this change.')),
      );
      return;
    }
    final count = eligible.length;
    final confirmed = await _confirm(
      'Apply to $count students?',
      'Change ${result.status == 'present' ? 'to Present' : 'to Absent'} '
          'for $count students using one reason. Each change is audited.',
      'Apply changes',
    );
    if (!mounted || !confirmed) return;

    setState(() => _busy = true);
    try {
      await _client.rpc(
        'bulk_correct_attendance',
        params: {
          'p_sheet_id': widget.sheetId,
          'p_student_ids': eligible
              .map((s) => s['student_id'].toString())
              .toList(),
          'p_new_status': result.status,
          'p_reason': result.reason,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count attendance records corrected.')),
      );
      await _refresh();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not apply corrections: ${error.message}'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not apply corrections. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: _background,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: SmartAttendPalette.highlight,
          offset: Offset(-5, -5),
          blurRadius: 11,
        ),
        BoxShadow(color: _shadow, offset: Offset(5, 5), blurRadius: 11),
      ],
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild when the app theme changes.
    final present = _roster
        .where((s) => s['attendance_status'] == 'present')
        .length;
    final absent = _roster
        .where((s) => s['attendance_status'] == 'absent')
        .length;
    final pending = _roster
        .where((s) => s['attendance_status'] == 'not_submitted')
        .length;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        title: Text('Manage Attendance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _busy ? null : _refresh,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 800),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.all(24),
              children: [
                Text(
                  widget.lectureTitle,
                  style: TextStyle(
                    fontSize: 24,
                    color: _text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Status: ${_pretty(_status)}',
                  style: TextStyle(color: _muted),
                ),
                if (widget.closesAt != null)
                  Text(
                    'Check-in closes: ${_dateLabel(widget.closesAt)}',
                    style: TextStyle(color: _muted),
                  ),
                SizedBox(height: 22),
                if (_loading)
                  Center(child: CircularProgressIndicator(color: _muted))
                else if (_error != null)
                  _card(
                    Column(
                      children: [
                        Text(_error!, style: TextStyle(color: _text)),
                        TextButton(onPressed: _refresh, child: Text('Retry')),
                      ],
                    ),
                  )
                else ...[
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eligible students: ${_roster.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _text,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Present: $present   Absent: $absent   Not submitted: $pending',
                          style: TextStyle(color: _muted),
                        ),
                        if (_status == 'draft') ...[
                          SizedBox(height: 12),
                          Text(
                            'Open this sheet using GPS before students can submit.',
                            style: TextStyle(color: _muted),
                          ),
                        ],
                        if (_status == 'cancelled') ...[
                          SizedBox(height: 12),
                          Text(
                            'This lecture is cancelled and will not count.',
                            style: TextStyle(color: _muted),
                          ),
                        ],
                        if (_status == 'open') ...[
                          SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _finalize,
                              icon: Icon(Icons.fact_check),
                              label: Text('Finalize Attendance'),
                            ),
                          ),
                          Text(
                            'Finalization is allowed only after the deadline.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                        if (_status == 'open' || _status == 'draft') ...[
                          SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _busy ? null : _cancel,
                            icon: Icon(Icons.cancel_outlined),
                            label: Text('Cancel Lecture'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 28),
                  Text(
                    'Lecture Roster',
                    style: TextStyle(
                      color: _text,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  if (_status == 'finalized' && _roster.isNotEmpty) ...[
                    _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${_selectedStudentIds.length} students selected',
                            style: TextStyle(
                              color: _text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _selectedStudentIds
                                          ..clear()
                                          ..addAll(
                                            _roster
                                                .where(
                                                  (s) =>
                                                      s['attendance_status'] ==
                                                      'absent',
                                                )
                                                .map(
                                                  (s) => s['student_id']
                                                      .toString(),
                                                ),
                                          );
                                      }),
                                child: Text('Select Absent'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _selectedStudentIds
                                          ..clear()
                                          ..addAll(
                                            _roster
                                                .where(
                                                  (s) =>
                                                      s['attendance_status'] ==
                                                      'present',
                                                )
                                                .map(
                                                  (s) => s['student_id']
                                                      .toString(),
                                                ),
                                          );
                                      }),
                                child: Text('Select Present'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(_selectedStudentIds.clear),
                                child: Text('Clear'),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _busy || _selectedStudentIds.isEmpty
                                ? null
                                : _bulkCorrect,
                            icon: Icon(Icons.fact_check_outlined),
                            label: Text('Bulk Correct Selected'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18),
                  ],
                  if (_roster.isEmpty)
                    _card(
                      Text(
                        'No eligible students in this sheet yet.',
                        style: TextStyle(color: _muted),
                      ),
                    )
                  else
                    for (final student in _roster) ...[
                      _card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['full_name']?.toString() ?? 'Student',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: _text,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'ID: ${student['university_student_id'] ?? '—'}',
                              style: TextStyle(color: _muted),
                            ),
                            SizedBox(height: 7),
                            Text(
                              'Status: ${_pretty(student['attendance_status']?.toString() ?? '')}',
                              style: TextStyle(color: _text),
                            ),
                            if (student['checked_in_at'] != null)
                              Text(
                                'GPS check-in: ${_dateLabel(student['checked_in_at'])}',
                                style: TextStyle(color: _muted),
                              ),
                            if (_status == 'finalized')
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Select for bulk correction'),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: _selectedStudentIds.contains(
                                  student['student_id'].toString(),
                                ),
                                onChanged: _busy
                                    ? null
                                    : (checked) => setState(() {
                                        final id = student['student_id']
                                            .toString();
                                        if (checked == true) {
                                          _selectedStudentIds.add(id);
                                        } else {
                                          _selectedStudentIds.remove(id);
                                        }
                                      }),
                              ),
                            if (_status == 'finalized')
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _correct(student),
                                  icon: Icon(Icons.edit_note),
                                  label: Text('Correct Individually'),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 15),
                    ],
                  if (_history.isNotEmpty) ...[
                    SizedBox(height: 18),
                    Text(
                      'Correction History',
                      style: TextStyle(
                        color: _text,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    for (final event in _history) ...[
                      _card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event['student_name']?.toString() ?? 'Student',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _text,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '${_pretty(event['old_status']?.toString() ?? '')} → '
                              '${_pretty(event['new_status']?.toString() ?? '')}',
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Reason: ${event['reason'] ?? ''}',
                              style: TextStyle(color: _text),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '${event['changed_by_name'] ?? 'Teacher'} · '
                              '${_dateLabel(event['changed_at'])}',
                              style: TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 15),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Result returned ONLY when the teacher actively saves a valid correction.
class _AttendanceCorrection {
  final String status;
  final String reason;

  const _AttendanceCorrection({required this.status, required this.reason});
}

class _AttendanceCorrectionDialog extends StatefulWidget {
  final String studentName;
  final String currentStatus;
  final bool bulkMode;

  const _AttendanceCorrectionDialog({
    required this.studentName,
    required this.currentStatus,
    this.bulkMode = false,
  });

  @override
  State<_AttendanceCorrectionDialog> createState() =>
      _AttendanceCorrectionDialogState();
}

class _AttendanceCorrectionDialogState
    extends State<_AttendanceCorrectionDialog> {
  static Color get _background => SmartAttendPalette.background;
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  String _reasonOption = 'GPS accuracy issue';
  late String _selectedStatus;
  static const _reasonOptions = <String>[
    'GPS accuracy issue',
    'Internet connectivity issue',
    'Manually verified in classroom',
    'Attendance entry mistake',
    'Other (write a reason)',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus == 'present' ? 'absent' : 'present';
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild when the app theme changes.
    return AlertDialog(
      backgroundColor: _background,
      title: Text('Correct Attendance'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.studentName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              if (!widget.bulkMode)
                Text(
                  'Current: ${widget.currentStatus == 'present' ? 'Present' : 'Absent'}',
                ),
              SizedBox(height: 16),
              Text('Change attendance to:'),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Present'),
                value: 'present',
                groupValue: _selectedStatus,
                onChanged: (value) => setState(() => _selectedStatus = value!),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Absent'),
                value: 'absent',
                groupValue: _selectedStatus,
                onChanged: (value) => setState(() => _selectedStatus = value!),
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _reasonOption,
                decoration: InputDecoration(
                  labelText: 'Correction reason',
                  border: OutlineInputBorder(),
                ),
                items: _reasonOptions
                    .map(
                      (option) =>
                          DropdownMenuItem(value: option, child: Text(option)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _reasonOption = value);
                },
              ),
              if (_reasonOption == 'Other (write a reason)') ...[
                SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: 'Explain the correction',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().length < 10) {
                      return 'Please enter at least 10 characters.';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!widget.bulkMode && _selectedStatus == widget.currentStatus) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Select a different status.')),
              );
              return;
            }
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _AttendanceCorrection(
                status: _selectedStatus,
                reason: _reasonOption == 'Other (write a reason)'
                    ? _reason.text.trim()
                    : _reasonOption,
              ),
            );
          },
          child: Text('Save Correction'),
        ),
      ],
    );
  }
}
