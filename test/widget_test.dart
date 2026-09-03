import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:annotter/annotter.dart';

void main() {
  testWidgets('Annotter works inside MaterialApp.builder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Annotter(child: child!),
        home: const Scaffold(body: Text('Hello')),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
  });
}
