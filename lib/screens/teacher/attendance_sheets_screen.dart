import '../../theme/smartattend_theme.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'manage_attendance_screen.dart';

/// Lesson 14B: create and list DRAFT attendance sheets for one teacher-owned class.
/// Teachers can open a draft with their current location; student GPS check-in comes later.
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
  static Color get _background => SmartAttendPalette.background;
  static Color get _text => SmartAttendPalette.text;
  static Color get _muted => SmartAttendPalette.muted;
  static Color get _shadow => SmartAttendPalette.shadow;

  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _opening = false;
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
          .select(
            'id, lecture_title, status, created_at, radius_meters, opened_at, closes_at',
          )
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

  // Open attendance management for this lecture, then refresh its status.
  Future<void> _openManageAttendance(Map<String, dynamic> sheet) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManageAttendanceScreen(
          sheetId: sheet['id'].toString(),
          lectureTitle: sheet['lecture_title']?.toString() ?? 'Lecture',
          initialStatus: sheet['status']?.toString() ?? 'draft',
          closesAt: sheet['closes_at']?.toString(),
        ),
      ),
    );
    if (mounted) {
      await _loadSheets();
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
        SnackBar(content: Text('Draft attendance sheet created.')),
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
        SnackBar(content: Text('Could not create sheet. Please retry.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Only draft sheets may be opened. The SECURITY DEFINER RPC independently
  // checks ownership, allowed settings, and the draft -> open transition.
  Future<void> _showOpenDialog(String sheetId, String lectureTitle) async {
    if (_opening) return;
    int radius = 20;
    int duration = 5;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          backgroundColor: _background,
          title: Text('Open GPS Attendance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lectureTitle, style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 12),
              Text('Classroom radius'),
              DropdownButton<int>(
                isExpanded: true,
                value: radius,
                items: [20, 30, 50]
                    .map(
                      (m) =>
                          DropdownMenuItem(value: m, child: Text('$m meters')),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) updateDialog(() => radius = value);
                },
              ),
              SizedBox(height: 12),
              Text('Check-in window'),
              DropdownButton<int>(
                isExpanded: true,
                value: duration,
                items: [5, 10]
                    .map(
                      (m) =>
                          DropdownMenuItem(value: m, child: Text('$m minutes')),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) updateDialog(() => duration = value);
                },
              ),
              SizedBox(height: 10),
              Text(
                'Stand at the classroom location. GPS may be inaccurate indoors. '
                'Opening a sheet cannot be undone in this lesson.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Get GPS and Open'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _openSheet(sheetId, radius, duration);
  }

  Future<void> _openSheet(String sheetId, int radius, int duration) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(
          'Location services are disabled. Turn on GPS/location.',
        );
      }

      // Some browsers do not fully support the Permissions API; requesting
      // the position itself will still prompt the browser when supported.
      if (!kIsWeb) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw Exception('Location permission denied. Enable it in settings.');
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted) return;
      if (!position.accuracy.isFinite || position.accuracy > 30) {
        throw Exception(
          'GPS accuracy is ${position.accuracy.toStringAsFixed(0)} meters. '
          'Move near a window or use a phone and try again.',
        );
      }

      await _supabase.rpc(
        'open_attendance_sheet',
        params: {
          'p_sheet_id': sheetId,
          'p_latitude': position.latitude,
          'p_longitude': position.longitude,
          'p_radius_meters': radius,
          'p_duration_minutes': duration,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance opened for $duration minutes ($radius m radius).',
          ),
        ),
      );
      await _loadSheets();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open attendance: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open attendance: $message')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(20),
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

  // Supabase stores TIMESTAMPTZ. Display in Bangladesh time (UTC+6)
  // regardless of the simulator or browser's configured time zone.
  String _dateLabel(Object? raw) {
    final timestamp = DateTime.tryParse(raw?.toString() ?? '');
    if (timestamp == null) return 'Date unavailable';

    final bdt = timestamp.toUtc().add(Duration(hours: 6));
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour12 = bdt.hour % 12 == 0 ? 12 : bdt.hour % 12;
    final minute = bdt.minute.toString().padLeft(2, '0');
    final period = bdt.hour < 12 ? 'AM' : 'PM';
    return '${bdt.day} ${months[bdt.month - 1]} ${bdt.year}, '
        '$hour12:$minute $period BDT';
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild when the app theme changes.
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        title: Text('Attendance Sheets'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadSheets,
            icon: Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800),
            child: RefreshIndicator(
              onRefresh: _loadSheets,
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                children: [
                  Text(
                    widget.courseName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Section ${widget.section}',
                    style: TextStyle(fontSize: 15, color: _muted),
                  ),
                  SizedBox(height: 30),
                  _card(
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Prepare a lecture',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: _text,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create a draft first. Students cannot check in until '
                            'the teacher opens it using classroom GPS.',
                            style: TextStyle(color: _muted),
                          ),
                          SizedBox(height: 18),
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
                              prefixIcon: Icon(Icons.menu_book_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _saving ? null : _createSheet,
                            icon: _saving
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(Icons.add_rounded),
                            label: Text('Create Draft Sheet'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _text,
                              foregroundColor: SmartAttendPalette.background,
                              minimumSize: Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 34),
                  Text(
                    'Lectures',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  SizedBox(height: 18),
                  if (_loading)
                    Center(child: CircularProgressIndicator(color: _muted))
                  else if (_error != null)
                    _card(
                      Column(
                        children: [
                          Text(_error!, style: TextStyle(color: _text)),
                          TextButton(
                            onPressed: _loadSheets,
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (_sheets.isEmpty)
                    _card(
                      Text(
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
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _text,
                              ),
                            ),
                            SizedBox(height: 9),
                            Text(
                              'Status: ${sheet['status']}',
                              style: TextStyle(color: _muted),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Created: ${_dateLabel(sheet['created_at'])}',
                              style: TextStyle(color: _muted),
                            ),
                            if (sheet['closes_at'] != null) ...[
                              SizedBox(height: 5),
                              Text(
                                'Check-in closes: ${_dateLabel(sheet['closes_at'])}',
                                style: TextStyle(color: _muted),
                              ),
                            ],
                            // Available for draft, open, finalized and cancelled
                            // sheets. Finalize appears inside for open sheets.
                            SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _openManageAttendance(sheet),
                                icon: Icon(Icons.fact_check_outlined),
                                label: Text('Manage Attendance'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _text,
                                  side: BorderSide(color: _muted),
                                  minimumSize: Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            if (sheet['status'] == 'draft') ...[
                              SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _opening
                                      ? null
                                      : () => _showOpenDialog(
                                          sheet['id'].toString(),
                                          sheet['lecture_title']?.toString() ??
                                              'Lecture',
                                        ),
                                  icon: _opening
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(Icons.location_on_outlined),
                                  label: Text('Open GPS Attendance'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _text,
                                    foregroundColor:
                                        SmartAttendPalette.background,
                                    minimumSize: Size.fromHeight(48),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 18),
                    ],
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
