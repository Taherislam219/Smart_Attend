import '../theme/smartattend_theme.dart';

import 'package:flutter/material.dart';

import 'role_selection_screen.dart';

/// Simple, centered Welcome screen with the updated checklist logo.
/// Keeps the original SmartAttend light Neumorphic style.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static Color get _background => SmartAttendPalette.background;
  static Color get _text => SmartAttendPalette.text;
  static Color get _muted => SmartAttendPalette.muted;
  static Color get _shadow => SmartAttendPalette.shadow;

  void _getStarted(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RoleSelectionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild when the app theme changes.
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // New checklist logo, matching the screenshot.
                      Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          color: _background,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: SmartAttendPalette.highlight,
                              offset: Offset(-8, -8),
                              blurRadius: 18,
                            ),
                            BoxShadow(
                              color: _shadow,
                              offset: Offset(8, 8),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.fact_check_rounded,
                          color: _text,
                          size: 72,
                        ),
                      ),
                      SizedBox(height: 38),
                      Text(
                        'SmartAttend',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: _text,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Smart Attendance Management System',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: _muted,
                        ),
                      ),
                      SizedBox(height: 64),
                      // 400px maximum ONLY on web/large screens.
                      // On phones, retain the existing full available width.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth >= 600
                              ? 400
                              : double.infinity,
                        ),
                        child: Container(
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            color: _background,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: SmartAttendPalette.highlight,
                                offset: Offset(-6, -6),
                                blurRadius: 12,
                              ),
                              BoxShadow(
                                color: _shadow,
                                offset: Offset(6, 6),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _getStarted(context),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Get Started',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _text,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: _text,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
