import 'package:flutter/material.dart';

import 'screens/welcome_screen.dart';

void main() {
  runApp(const SmartAttendApp());
}

class SmartAttendApp extends StatelessWidget {
  const SmartAttendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartAttend',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const WelcomeScreen(),
    );
  }
}
