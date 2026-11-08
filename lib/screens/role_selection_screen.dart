import 'package:flutter/material.dart';

import 'auth/login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFE8EEF3);
    const textColor = Color(0xFF263238);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: const Text('SmartAttend'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 65),
              const Icon(Icons.school_rounded, size: 75, color: textColor),
              const SizedBox(height: 30),
              const Text(
                'Choose Your Role',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'How will you use SmartAttend?',
                style: TextStyle(fontSize: 16, color: Color(0xFF607D8B)),
              ),
              const SizedBox(height: 50),
              _roleCard(
                context,
                icon: Icons.co_present_rounded,
                title: 'Teacher',
                subtitle: 'Manage classes and attendance',
              ),
              const SizedBox(height: 25),
              _roleCard(
                context,
                icon: Icons.menu_book_rounded,
                title: 'Student',
                subtitle: 'Join classes and mark attendance',
              ),
              const SizedBox(height: 45),
              const Text(
                'Select your role to continue',
                style: TextStyle(fontSize: 13, color: Color(0xFF607D8B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF3),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-6, -6),
            blurRadius: 12,
          ),
          BoxShadow(
            color: Color(0xFFB8C4CE),
            offset: Offset(6, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen(role: title)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Icon(icon, size: 42, color: const Color(0xFF263238)),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF263238),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF607D8B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Color(0xFF607D8B),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
