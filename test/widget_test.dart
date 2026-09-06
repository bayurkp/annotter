import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:annotter/annotter.dart';

void main() {
  testWidgets('Annotter works inside MaterialApp.builder and toggles between FAB and Floating Pill Toolbar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Annotter(child: child!),
        home: const Scaffold(body: Text('Hello Annotter')),
      ),
    );

    // Initial state: native full app visible + idle FAB button
    expect(find.text('Hello Annotter'), findsOneWidget);
    expect(find.byIcon(Icons.edit_note), findsOneWidget);

    // Tap FAB to activate Annotter studio mode
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    // Active state: Floating Pill Toolbar appears with modern tools
    expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);
    expect(find.byIcon(Icons.crop_square_rounded), findsOneWidget);
    expect(find.byIcon(Icons.adjust_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Close button returns to idle FAB
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_note), findsOneWidget);
    expect(find.byIcon(Icons.touch_app_outlined), findsNothing);
  });
}
