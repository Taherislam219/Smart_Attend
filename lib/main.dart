import 'theme/smartattend_theme.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/welcome_screen.dart';
import 'screens/auth/reset_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );
  runApp(const SmartAttendApp());
}

class SmartAttendApp extends StatefulWidget {
  const SmartAttendApp({super.key});
  @override
  State<SmartAttendApp> createState() => _SmartAttendAppState();
}

class _SmartAttendAppState extends State<SmartAttendApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
              (route) => route.isFirst,
            );
          });
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        // Avoid crashing the app on temporary network / token refresh errors.
        debugPrint('Auth event error: $error');
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SmartAttendTheme.darkMode,
      builder: (context, dark, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'SmartAttend',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: dark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: SmartAttendPalette.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: dark
                  ? const Color(0xFFB8CFDA)
                  : const Color(0xFF607D8B),
              brightness: dark ? Brightness.dark : Brightness.light,
              surface: SmartAttendPalette.background,
            ),
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: TextStyle(color: SmartAttendPalette.muted),
              hintStyle: TextStyle(color: SmartAttendPalette.muted),
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: SmartAttendPalette.background,
              foregroundColor: SmartAttendPalette.text,
              surfaceTintColor: Colors.transparent,
              elevation: 4,
              scrolledUnderElevation: 4,
              shadowColor: SmartAttendPalette.shadow,
            ),
          ),
          home: const WelcomeScreen(),
        );
      },
    );
  }
}
