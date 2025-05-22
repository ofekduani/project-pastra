import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kolwrite_voice_agent/main.dart';

void main() {
  testWidgets('App launches and shows main controls', (WidgetTester tester) async {
    // Build the app.
    await tester.pumpWidget(const KolWriteVoiceAgentApp());

    // Expect to find the title.
    expect(find.text('KolWrite Voice Agent'), findsOneWidget);

    // Expect to find a microphone-related button (Icon with mic_outline).
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
  });
} 