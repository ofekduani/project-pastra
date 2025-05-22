import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kolwrite_voice_agent/main.dart';

void main() {
  testWidgets('App launches and shows main controls', (WidgetTester tester) async {
    // Build the app.
    await tester.pumpWidget(const MyApp());

    // Expect to find the title.
    expect(find.text('Google Sign-In'), findsOneWidget);

    // Expect to find the sign-in button.
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
} 