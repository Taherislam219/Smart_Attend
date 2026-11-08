import 'package:flutter/material.dart';

import 'role_selection_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFE8EEF3);
    const textColor = Color(0xFF263238);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Neumorphic logo container
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-8, -8),
                      blurRadius: 16,
                    ),
                    BoxShadow(
                      color: Color(0xFFB8C4CE),
                      offset: Offset(8, 8),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 70,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 45),

              const Text(
                'SmartAttend',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                'Smart Classroom Attendance\nMade Simple',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF607D8B),
                ),
              ),

              const Spacer(),

              //  Get Started button
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-5, -5),
                      blurRadius: 10,
                    ),
                    BoxShadow(
                      color: Color(0xFFB8C4CE),
                      offset: Offset(5, 5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RoleSelectionScreen(),
                        ),
                      );
                    },
                    child: const Center(
                      child: Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 35),
            ],
          ),
        ),
      ),
    );
  }
}
