import '../../theme/smartattend_theme.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnrollmentRequestsScreen extends StatefulWidget {
  final String classId;
  final String courseName;
  final String section;

  const EnrollmentRequestsScreen({
    super.key,
    required this.classId,
    required this.courseName,
    required this.section,
  });

  @override
  State<EnrollmentRequestsScreen> createState() =>
      _EnrollmentRequestsScreenState();
}

class _EnrollmentRequestsScreenState extends State<EnrollmentRequestsScreen> {
  static Color get _background => SmartAttendPalette.background;
  static Color get _text => SmartAttendPalette.text;
  static Color get _muted => SmartAttendPalette.muted;
  static Color get _shadow => SmartAttendPalette.shadow;

  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;
  String? _processingId;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _supabase.rpc(
        'get_teacher_enrollment_requests',
        params: {'p_class_id': widget.classId},
      );
      if (!mounted) return;
      setState(() => _requests = List<Map<String, dynamic>>.from(result));
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load enrollment requests.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(Map<String, dynamic> request, String decision) async {
    final studentName = request['student_name']?.toString() ?? 'this student';
    final approved = decision == 'approved';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approved ? 'Approve student?' : 'Reject request?'),
        content: Text(
          '${approved ? 'Approve' : 'Reject'} $studentName for ${widget.courseName}, '
          'Section ${widget.section}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approved ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _processingId != null) return;

    final requestId = request['enrollment_id'].toString();
    setState(() => _processingId = requestId);
    try {
      // Teacher UPDATE RLS checks class ownership. Database triggers
      // enforce pending -> approved/rejected and record the reviewer/time.
      final updated = await _supabase
          .from('class_enrollments')
          .update({'status': decision})
          .eq('id', requestId)
          .eq('status', 'pending')
          .select('id');
      if (!mounted) return;
      if (updated.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request already reviewed or not authorized.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved ? 'Student approved!' : 'Request rejected.'),
          ),
        );
      }
      await _loadRequests();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update request: ${error.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update request. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(20),
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

  Widget _requestCard(Map<String, dynamic> request) {
    final status = request['status']?.toString() ?? 'pending';
    final requestId = request['enrollment_id']?.toString() ?? '';
    final busy = _processingId != null;
    return Padding(
      padding: EdgeInsets.only(bottom: 18),
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request['student_name']?.toString() ?? 'Student',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Student ID: ${request['student_university_id'] ?? ''}',
              style: TextStyle(color: _muted),
            ),
            SizedBox(height: 10),
            Text(
              'Status: ${status == 'pending'
                  ? 'Pending approval'
                  : status == 'approved'
                  ? 'Approved'
                  : 'Rejected'}',
              style: TextStyle(color: _text, fontWeight: FontWeight.w600),
            ),
            if (status == 'pending') ...[
              SizedBox(height: 15),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: busy || requestId.isEmpty
                        ? null
                        : () => _review(request, 'approved'),
                    icon: Icon(Icons.check_rounded),
                    label: Text(
                      busy && _processingId == requestId
                          ? 'Saving...'
                          : 'Approve',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _text,
                      foregroundColor: SmartAttendPalette.background,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || requestId.isEmpty
                        ? null
                        : () => _review(request, 'rejected'),
                    icon: Icon(Icons.close_rounded),
                    label: Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: _text),
                  ),
                ],
              ),
            ],
          ],
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
        title: Text('Enrollment Requests'),
        backgroundColor: _background,
        foregroundColor: _text,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView(
                padding: EdgeInsets.all(26),
                children: [
                  Text(
                    widget.courseName,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Section ${widget.section}',
                    style: TextStyle(color: _muted),
                  ),
                  SizedBox(height: 26),
                  if (_loading)
                    Center(child: CircularProgressIndicator(color: _text))
                  else if (_error != null)
                    _card(
                      Column(
                        children: [
                          Text(_error!, style: TextStyle(color: _text)),
                          TextButton(
                            onPressed: _loadRequests,
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (_requests.isEmpty)
                    _card(
                      Text(
                        'No enrollment requests yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted),
                      ),
                    )
                  else
                    for (final request in _requests) _requestCard(request),
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
