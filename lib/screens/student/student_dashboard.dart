import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _loadStudentProfile();
  }

  // Load the currently authenticated student's profile.
  Future<void> _loadStudentProfile() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('You are not logged in.');
      }

      final profile = await _supabase
          .from('profiles')
          .select('full_name, university_student_id, role')
          .eq('id', user.id)
          .single();

      // Never display the student dashboard
      // for a teacher account.
      if (profile['role'] != 'student') {
        throw Exception('Student access only.');
      }

      if (!mounted) return;

      setState(() {
        _fullName = profile['full_name'] as String? ?? '';
        _studentId = profile['university_student_id'] as String? ?? '';
        _email = user.email ?? '';

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unable to load your student profile.';
        _isLoading = false;
      });
    }
  }

  // End the Supabase session.
  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();

      if (!mounted) return;

      // Return to the first screen.
      // Later we can use a centralized auth router.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  // Reusable raised Neumorphic container.
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
  }) {
    return Expanded(
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
            Text(title, style: const TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadStudentProfile,
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

          // Student identity card.
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

          // These values will come from real
          // enrollment and attendance tables later.
          Row(
            children: [
              _statCard(
                icon: Icons.menu_book_rounded,
                title: 'Enrolled Classes',
                value: '—',
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

          const Text(
            'My Semester Classes',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),

          const SizedBox(height: 18),

          _neumorphicCard(
            child: const Column(
              children: [
                Icon(Icons.calendar_month_rounded, size: 42, color: _muted),
                SizedBox(height: 14),
                Text(
                  'No classes to display yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your approved semester classes '
                  'will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Logout button.
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
