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
  static const _background = Color(0xFFE8EEF3);
  static const _text = Color(0xFF263238);
  static const _muted = Color(0xFF607D8B);
  static const _shadow = Color(0xFFB8C4CE);

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
            child: const Text('Cancel'),
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
          const SnackBar(
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
        const SnackBar(content: Text('Could not update request. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _background,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(color: Colors.white, offset: Offset(-5, -5), blurRadius: 12),
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
      padding: const EdgeInsets.only(bottom: 18),
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request['student_name']?.toString() ?? 'Student',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Student ID: ${request['student_university_id'] ?? ''}',
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 10),
            Text(
              'Status: ${status == 'pending'
                  ? 'Pending approval'
                  : status == 'approved'
                  ? 'Approved'
                  : 'Rejected'}',
              style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 15),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: busy || requestId.isEmpty
                        ? null
                        : () => _review(request, 'approved'),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      busy && _processingId == requestId
                          ? 'Saving...'
                          : 'Approve',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _text,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || requestId.isEmpty
                        ? null
                        : () => _review(request, 'rejected'),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
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
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Enrollment Requests'),
        backgroundColor: _background,
        foregroundColor: _text,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView(
                padding: const EdgeInsets.all(26),
                children: [
                  Text(
                    widget.courseName,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Section ${widget.section}',
                    style: const TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 26),
                  if (_loading)
                    const Center(child: CircularProgressIndicator(color: _text))
                  else if (_error != null)
                    _card(
                      Column(
                        children: [
                          Text(_error!, style: const TextStyle(color: _text)),
                          TextButton(
                            onPressed: _loadRequests,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (_requests.isEmpty)
                    _card(
                      const Text(
                        'No enrollment requests yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted),
                      ),
                    )
                  else
                    for (final request in _requests) _requestCard(request),
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
