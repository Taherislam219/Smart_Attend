import 'package:flutter_test/flutter_test.dart';

import 'package:smart_attend/main.dart';

void main() {
  testWidgets('SmartAttend navigation test', (tester) async {
    await tester.pumpWidget(const SmartAttendApp());

    // Welcome screen appears.
    expect(find.text('SmartAttend'), findsOneWidget);

    // Open role selection.
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Your Role'), findsOneWidget);

    // Open Teacher Login.
    await tester.tap(find.text('Teacher'));
    await tester.pumpAndSettle();

    expect(find.text('Teacher Login'), findsOneWidget);
  });
}
