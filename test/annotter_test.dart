import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:annotter/annotter.dart';

void main() {
  test('AnnotterExporter formats markdown correctly', () {
    final items = [
      AnnotterItem(
        id: 1,
        number: 1,
        rect: const Rect.fromLTWH(20, 100, 200, 50),
        widgetName: 'SubmitButton',
        hierarchy: ['SubmitButton', 'ActionRow', 'FormCard', 'DashboardPage'],
        note: 'Change button text to Save',
        mode: AnnotterMode.widget,
        screenName: 'DashboardScreen',
      ),
      AnnotterItem(
        id: 2,
        number: 2,
        rect: const Rect.fromLTWH(0, 0, 390, 80),
        widgetName: 'CustomHeader',
        hierarchy: ['CustomHeader', 'DashboardPage'],
        note: 'Padding is too small',
        mode: AnnotterMode.area,
        screenName: 'DashboardScreen',
      ),
    ];

    final md = AnnotterExporter.toMarkdown(
      items: items,
      routeName: 'DashboardScreen',
      viewportSize: const Size(390, 844),
    );

    expect(md, contains('## UI Revision Request (Total: 2 notes across 1 page)'));
    expect(md, contains('**Viewport:** 390x844'));
    expect(md, contains('### 📱 Page: DashboardScreen'));
    expect(md, contains('1. [WIDGET] **SubmitButton**'));
    expect(md, contains('Change button text to Save'));
    expect(md, contains('<DashboardPage> <FormCard> <ActionRow> <SubmitButton>'));
    expect(md, contains('2. [AREA] **CustomHeader**'));
    expect(md, contains('Padding is too small'));
  });
}
