import 'package:flutter/material.dart';

/// One in-memory theme setting shared by both user roles.
/// It resets to Light Mode on a full app restart.
class SmartAttendTheme {
  static final ValueNotifier<bool> darkMode = ValueNotifier<bool>(false);
  static bool get isDark => darkMode.value;
  static void toggle() => darkMode.value = !darkMode.value;
}

/// SmartAttend's original Neumorphic palette, with a dark counterpart.
/// Bright white upper-left highlights are retained in dark mode.
class SmartAttendPalette {
  static Color get background => SmartAttendTheme.isDark
      ? const Color(0xFF20272D)
      : const Color(0xFFE8EEF3);
  static Color get text => SmartAttendTheme.isDark
      ? const Color(0xFFE8EEF3)
      : const Color(0xFF263238);
  static Color get muted => SmartAttendTheme.isDark
      ? const Color(0xFFA7BBC8)
      : const Color(0xFF607D8B);
  static Color get shadow => SmartAttendTheme.isDark
      ? const Color(0xFF0F151B)
      : const Color(0xFFB8C4CE);
  static Color get highlight =>
      SmartAttendTheme.isDark ? const Color(0x90FFFFFF) : Colors.white;
}
