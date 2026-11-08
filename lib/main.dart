import 'package:flutter/material.dart';

import 'screens/welcome_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

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
