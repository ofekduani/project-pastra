import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audio_app/main.dart'; // Adjust import if your main page is elsewhere

void main() {
  testWidgets('AudioInteractionPage renders basic UI', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp()); // Assuming MyApp is your root widget

    // Verify that the initial status message is present.
    expect(find.text('Press Start to begin'), findsOneWidget);

    // Verify that the "Start Recording" button is present.
    expect(find.widgetWithText(ElevatedButton, 'Start Recording'), findsOneWidget);
    // expect(find.byIcon(Icons.mic), findsOneWidget); // Check for the mic icon too
    // The initial icon is Icons.mic_outlined, not Icons.mic
    expect(find.byIcon(Icons.mic_outlined), findsOneWidget);


    // You could also tap the button and verify state changes if services were mocked,
    // but for a basic test, just finding initial elements is okay.
  });
}
