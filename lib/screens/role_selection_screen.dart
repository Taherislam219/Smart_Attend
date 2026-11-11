import '../theme/smartattend_theme.dart';

import 'package:flutter/material.dart';

import 'auth/login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild when the app theme changes.
    final backgroundColor = SmartAttendPalette.background;
    final textColor = SmartAttendPalette.text;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        // Keep the original automatic AppBar back arrow.
        title: Text('SmartAttend'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 650),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(height: 24),
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: SmartAttendPalette.highlight,
                          offset: Offset(-6, -6),
                          blurRadius: 12,
                        ),
                        BoxShadow(
                          color: SmartAttendPalette.shadow,
                          offset: Offset(6, 6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.fact_check_rounded,
                      size: 52,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 30),
                  Text(
                    'Choose Your Role',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'How will you use SmartAttend?',
                    style: TextStyle(
                      fontSize: 16,
                      color: SmartAttendPalette.muted,
                    ),
                  ),
                  SizedBox(height: 50),
                  _roleCard(
                    context,
                    icon: Icons.co_present_rounded,
                    title: 'Teacher',
                    subtitle: 'Manage classes and attendance',
                  ),
                  SizedBox(height: 25),
                  _roleCard(
                    context,
                    icon: Icons.menu_book_rounded,
                    title: 'Student',
                    subtitle: 'Join classes and mark attendance',
                  ),
                  SizedBox(height: 45),
                  Text(
                    'Select your role to continue',
                    style: TextStyle(
                      fontSize: 13,
                      color: SmartAttendPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
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
        color: SmartAttendPalette.background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: SmartAttendPalette.highlight,
            offset: Offset(-6, -6),
            blurRadius: 12,
          ),
          BoxShadow(
            color: SmartAttendPalette.shadow,
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
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Icon(icon, size: 42, color: SmartAttendPalette.text),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: SmartAttendPalette.text,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: SmartAttendPalette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: SmartAttendPalette.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
