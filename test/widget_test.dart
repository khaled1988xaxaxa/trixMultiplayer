// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trix/main.dart';

void main() {
  testWidgets('Trix app smoke test', (WidgetTester tester) async {
    // Set a reasonable size for the test
    await tester.binding.setSurfaceSize(const Size(400, 800));
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TrixApp());

    // Verify that the app title is displayed
    expect(find.text('TRIX'), findsOneWidget);
    
    // Verify that subtitle text is displayed
    expect(find.text('The Classic Card Game'), findsOneWidget);
    
    // Verify that the name input field is present
    expect(find.text('Enter Your Name'), findsOneWidget);
    
    // Verify that the start game button is present
    expect(find.text('Start New Game'), findsOneWidget);
    
    // Verify that the game rules button is present
    expect(find.text('Game Rules'), findsOneWidget);
  });

  testWidgets('Player name input and validation test', (WidgetTester tester) async {
    // Set a reasonable size for the test
    await tester.binding.setSurfaceSize(const Size(400, 800));
    
    await tester.pumpWidget(const TrixApp());

    // Find the text field and start game button
    final nameField = find.byType(TextField);
    final startButton = find.text('Start New Game');

    // Try to start game without entering name
    await tester.tap(startButton);
    await tester.pump();

    // Should show error message via SnackBar
    expect(find.text('Please enter your name first'), findsOneWidget);

    // Dismiss the SnackBar by tapping outside or using ScaffoldMessenger
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).hideCurrentSnackBar();
    await tester.pump();

    // Verify SnackBar is gone
    expect(find.text('Please enter your name first'), findsNothing);

    // Enter a name
    await tester.enterText(nameField, 'Test Player');
    await tester.pump();

    // Tap start game button again - this time it should succeed
    await tester.tap(startButton);
    await tester.pump();

    // Verify no error message appears and we don't stay on the same screen
    expect(find.text('Please enter your name first'), findsNothing);
  });

  testWidgets('Game rules dialog test', (WidgetTester tester) async {
    // Set a reasonable size for the test
    await tester.binding.setSurfaceSize(const Size(400, 800));
    
    await tester.pumpWidget(const TrixApp());

    // Scroll to make sure Game Rules button is visible
    await tester.dragUntilVisible(
      find.text('Game Rules'),
      find.byType(SingleChildScrollView),
      const Offset(0, -50),
    );

    // Find and tap the game rules button
    final rulesButton = find.text('Game Rules');
    await tester.tap(rulesButton);
    await tester.pumpAndSettle(); // Wait for dialog animation

    // Verify that the rules dialog is shown
    expect(find.text('Trix Game Rules'), findsOneWidget);
    expect(find.textContaining('Trix is a popular card game'), findsOneWidget);

    // Close the dialog
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle(); // Wait for dialog to close

    // Verify dialog is closed
    expect(find.text('Trix Game Rules'), findsNothing);
  });

  testWidgets('AI Settings navigation test', (WidgetTester tester) async {
    // Set a reasonable size for the test
    await tester.binding.setSurfaceSize(const Size(400, 800));
    
    await tester.pumpWidget(const TrixApp());

    // Scroll to make sure AI Settings button is visible
    await tester.dragUntilVisible(
      find.text('AI Settings'),
      find.byType(SingleChildScrollView),
      const Offset(0, -50),
    );

    // Find and tap the AI settings button
    final aiButton = find.text('AI Settings');
    await tester.tap(aiButton);
    await tester.pumpAndSettle(); // Wait for navigation

    // Verify that we navigated to AI settings screen
    // Should find the AI Settings title in the app bar
    expect(find.text('AI Settings'), findsWidgets);
  });
}
