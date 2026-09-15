import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:annotter/annotter.dart';
import 'package:annotter/src/list_sheet.dart';
import 'package:annotter/src/sheet.dart';

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

  testWidgets('AnnotationListSheet renders OutlinedButtons and reorderable drag handles', (tester) async {
    final items = [
      AnnotterItem(
        id: 1,
        number: 1,
        rect: const Rect.fromLTWH(0, 0, 100, 50),
        widgetName: 'Widget Alpha',
        note: 'First note',
      ),
      AnnotterItem(
        id: 2,
        number: 2,
        rect: const Rect.fromLTWH(0, 50, 100, 50),
        widgetName: 'Widget Beta',
        note: 'Second note',
      ),
    ];

    List<AnnotterItem>? reorderedResult;
    bool clearAllCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnotationListSheet(
            items: items,
            onClose: () {},
            onEdit: (_) {},
            onDelete: (_) {},
            onClearAll: () => clearAllCalled = true,
            onReorder: (newList) => reorderedResult = newList,
          ),
        ),
      ),
    );

    // Verify OutlinedButtons are used
    expect(find.byType(OutlinedButton), findsNWidgets(6)); // Clear All, Close X, 2x Edit, 2x Delete
    expect(find.text('Clear All'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(3)); // 1 in Clear All, 2 in items

    // Verify ReorderableDragStartListener is present for each item
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));

    // Drag first item handle downwards
    final firstHandle = find.byType(ReorderableDragStartListener).first;
    await tester.timedDrag(firstHandle, const Offset(0, 100), const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(reorderedResult, isNotNull);

    // Tap Clear All
    await tester.tap(find.text('Clear All'));
    expect(clearAllCalled, isTrue);
  });

  testWidgets('AnnotationSheet saves note on Enter and inserts newline on Shift+Enter', (tester) async {
    final item = AnnotterItem(
      id: 1,
      number: 1,
      rect: const Rect.fromLTWH(0, 0, 100, 50),
      widgetName: 'SubmitButton',
      note: 'Initial text',
    );

    String? savedNote;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnotationSheet(
            item: item,
            onCancel: () {},
            onDelete: () {},
            onSave: (note, intent, severity) => savedNote = note,
          ),
        ),
      ),
    );

    // Verify Save button has 'Save' text and '↵' kbd symbol
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('↵'), findsOneWidget);

    // Focus TextField and type
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    // Simulate Shift + Enter
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    // Verify newline was inserted and onSave was NOT called yet
    expect(savedNote, isNull);
    final textField = tester.widget<TextField>(textFieldFinder);
    expect(textField.controller!.text, equals('Initial text\n'));

    // Simulate plain Enter
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // Verify onSave was called with trimmed text
    expect(savedNote, equals('Initial text'));
  });

  testWidgets('AnnotationSheet and AnnotationListSheet display sourceLocation', (tester) async {
    final item = AnnotterItem(
      id: 1,
      number: 1,
      rect: const Rect.fromLTWH(0, 0, 100, 50),
      widgetName: 'AppButton',
      note: 'Needs bigger padding',
      sourceLocation: 'lib/widgets/app_button.dart:42',
    );

    // Test AnnotationSheet
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnotationSheet(
            item: item,
            onCancel: () {},
            onDelete: () {},
            onSave: (_, __, ___) {},
          ),
        ),
      ),
    );

    expect(find.text('lib/widgets/app_button.dart:42'), findsOneWidget);
    expect(find.byIcon(Icons.code_rounded), findsOneWidget);

    // Test AnnotationListSheet
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnotationListSheet(
            items: [item],
            onClose: () {},
            onEdit: (_) {},
            onDelete: (_) {},
            onClearAll: () {},
            onReorder: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('lib/widgets/app_button.dart:42'), findsOneWidget);
    expect(find.byIcon(Icons.code_rounded), findsOneWidget);
  });

  testWidgets('AnnotationSheet and AnnotationListSheet display caller hierarchy when callStack is provided', (tester) async {
    final item = AnnotterItem(
      id: 1,
      number: 1,
      rect: const Rect.fromLTWH(0, 0, 100, 50),
      widgetName: 'AppContainer',
      note: 'Primitive used in activity strip',
      sourceLocation: 'lib/src/core/widgets/primitives/app_container.dart:226',
      callStack: const [
        SourceCallSite(
          widgetName: 'AppContainer',
          location: 'lib/src/core/widgets/primitives/app_container.dart:226',
        ),
        SourceCallSite(
          widgetName: 'ActivityMetricStrip',
          location: 'lib/src/features/activity_metric_strip.dart:48',
        ),
      ],
    );

    // Test AnnotationSheet displays caller
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnotationSheet(
            item: item,
            onCancel: () {},
            onDelete: () {},
            onSave: (_, __, ___) {},
          ),
        ),
      ),
    );

    expect(find.text('lib/src/core/widgets/primitives/app_container.dart:226'), findsOneWidget);
    expect(find.text('↳ in ActivityMetricStrip (lib/src/features/activity_metric_strip.dart:48)'), findsOneWidget);

    // Test AnnotationListSheet displays caller
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnotationListSheet(
            items: [item],
            onClose: () {},
            onEdit: (_) {},
            onDelete: (_) {},
            onClearAll: () {},
            onReorder: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('lib/src/core/widgets/primitives/app_container.dart:226'), findsOneWidget);
    expect(find.text('↳ in ActivityMetricStrip'), findsOneWidget);
  });
}
