import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lists only classes with an approved enrollment for the signed-in student.
/// Course details come from the existing secure Student RPC.
class EnrolledClassesScreen extends StatefulWidget {
  const EnrolledClassesScreen({super.key});

  @override
  State<EnrolledClassesScreen> createState() => _EnrolledClassesScreenState();
}

class _EnrolledClassesScreenState extends State<EnrolledClassesScreen> {
  static const _background = Color(0xFFE8EEF3);
  static const _text = Color(0xFF263238);
  static const _muted = Color(0xFF607D8B);
  static const _shadow = Color(0xFFB8C4CE);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        throw StateError('Not signed in');
      }
      final rows = await client.rpc('get_my_class_enrollments');
      final all = List<Map<String, dynamic>>.from(rows);
      if (!mounted) return;
      setState(() {
        _classes = all.where((row) => row['status'] == 'approved').toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load enrolled classes. Please retry.';
        _loading = false;
      });
    }
  }

  Widget _card(Map<String, dynamic> classroom) {
    final name = classroom['course_name']?.toString() ?? 'Unnamed course';
    final code = classroom['course_code']?.toString() ?? '';
    final semester = classroom['semester']?.toString() ?? '';
    final section = classroom['section']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(22),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: _muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Course code: $code', style: const TextStyle(color: _muted)),
          const SizedBox(height: 6),
          Text('Semester: $semester', style: const TextStyle(color: _muted)),
          const SizedBox(height: 6),
          Text('Section: $section', style: const TextStyle(color: _muted)),
          const SizedBox(height: 15),
          const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 18, color: _muted),
              SizedBox(width: 7),
              Text(
                'Enrolled',
                style: TextStyle(color: _text, fontWeight: FontWeight.w600),
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
        title: const Text('Enrolled Classes'),
        centerTitle: true,
        backgroundColor: _background,
        foregroundColor: _text,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _muted))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: _text)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loadClasses,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadClasses,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        '${_classes.length} approved class${_classes.length == 1 ? '' : 'es'}',
                        style: const TextStyle(color: _muted, fontSize: 15),
                      ),
                      const SizedBox(height: 24),
                      if (_classes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 65),
                          child: Column(
                            children: [
                              Icon(
                                Icons.menu_book_outlined,
                                size: 52,
                                color: _muted,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'No enrolled classes yet',
                                style: TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Approved classes will appear here.',
                                style: TextStyle(color: _muted),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final classroom in _classes) _card(classroom),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
