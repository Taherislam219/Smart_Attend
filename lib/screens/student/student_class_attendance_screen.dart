import '../../theme/smartattend_theme.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'student_attendance_history_screen.dart';

/// Shows active lectures for one approved class and submits a server-verified
/// GPS check-in. No attendance is decided solely by this screen.
class StudentClassAttendanceScreen extends StatefulWidget {
  final String classId;
  final String courseName;

  const StudentClassAttendanceScreen({
    super.key,
    required this.classId,
    required this.courseName,
  });

  @override
  State<StudentClassAttendanceScreen> createState() =>
      _StudentClassAttendanceScreenState();
}

class _StudentClassAttendanceScreenState
    extends State<StudentClassAttendanceScreen> {
  static Color get _background => SmartAttendPalette.background;
  static Color get _text => SmartAttendPalette.text;
  static Color get _muted => SmartAttendPalette.muted;
  static Color get _shadow => SmartAttendPalette.shadow;
  bool _loading = true;
  String? _error;
  String? _busySheet;
  List<Map<String, dynamic>> _sheets = [];

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
      final result = await Supabase.instance.client.rpc(
        'get_my_class_attendance',
        params: {'p_class_id': widget.classId},
      );
      if (!mounted) return;
      setState(() {
        _sheets = List<Map<String, dynamic>>.from(result);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load attendance: $e';
        _loading = false;
      });
    }
  }

  Future<Position> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Enable Location Services in device settings.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Allow precise location access for SmartAttend.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(Duration(seconds: 30));
  }

  Future<void> _checkIn(Map<String, dynamic> sheet) async {
    if (_busySheet != null) return;
    setState(() => _busySheet = sheet['sheet_id'].toString());
    try {
      final position = await _getLocation();
      if (position.accuracy > 50) {
        throw Exception(
          'GPS accuracy is ${position.accuracy.toStringAsFixed(0)}m. '
          'Try moving near a window or use a phone with precise location.',
        );
      }
      await Supabase.instance.client.rpc(
        'mark_my_attendance',
        params: {
          'p_sheet_id': sheet['sheet_id'],
          'p_latitude': position.latitude,
          'p_longitude': position.longitude,
          'p_accuracy_meters': position.accuracy,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance recorded successfully.')),
      );
      await _load();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not mark attendance: $e')));
    } finally {
      if (mounted) setState(() => _busySheet = null);
    }
  }

  Widget _sheetCard(Map<String, dynamic> sheet) {
    final closes = DateTime.tryParse(sheet['closes_at']?.toString() ?? '');
    final checked = sheet['checked_in_at'] != null;
    final expired = closes == null || DateTime.now().isAfter(closes.toLocal());
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(22),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sheet['lecture_title']?.toString() ?? 'Lecture',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
          SizedBox(height: 12),
          Text(
            checked
                ? 'Present — checked in'
                : expired
                ? 'Check-in closed'
                : 'Open for check-in',
            style: TextStyle(color: _muted),
          ),
          if (closes != null) ...[
            SizedBox(height: 6),
            Text(
              'Closes: ${_formatBDT(closes)}',
              style: TextStyle(color: _muted),
            ),
          ],
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: checked || expired || _busySheet != null
                  ? null
                  : () => _checkIn(sheet),
              icon: _busySheet == sheet['sheet_id'].toString()
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.location_on_outlined),
              label: Text(
                checked
                    ? 'Already Marked Present'
                    : expired
                    ? 'Check-in Closed'
                    : 'Mark Attendance',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _text,
                foregroundColor: SmartAttendPalette.background,
                padding: EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBDT(DateTime value) {
    final bdt = value.toUtc().add(Duration(hours: 6));
    final hour = bdt.hour % 12 == 0 ? 12 : bdt.hour % 12;
    final minute = bdt.minute.toString().padLeft(2, '0');
    return '${bdt.day}/${bdt.month}/${bdt.year} $hour:$minute ${bdt.hour >= 12 ? 'PM' : 'AM'} BDT';
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild when the app theme changes.
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text('Class Attendance'),
        centerTitle: true,
        backgroundColor: _background,
        foregroundColor: _text,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: Text('Retry')),
                  ],
                ),
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
                      Text(
                        widget.courseName,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Only eligible, open attendance sheets appear here.',
                        style: TextStyle(color: _muted),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudentAttendanceHistoryScreen(
                                classId: widget.classId,
                                courseName: widget.courseName,
                              ),
                            ),
                          ),
                          icon: Icon(Icons.history_rounded),
                          label: Text('My Finalized Attendance'),
                        ),
                      ),
                      SizedBox(height: 28),
                      if (_sheets.isEmpty)
                        Text(
                          'No active attendance sheets. Ask your teacher to open a new lecture.',
                          style: TextStyle(color: _muted),
                        )
                      else
                        for (final sheet in _sheets) _sheetCard(sheet),
                      SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
