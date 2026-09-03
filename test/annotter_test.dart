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

    expect(md, contains('## UI Revision Request (Total: 2 notes across 1 view)'));
    expect(md, contains('**Viewport:** 390x844'));
    expect(md, contains('### 📱 Page: DashboardScreen'));
    expect(md, contains('1. [WIDGET] **SubmitButton**'));
    expect(md, contains('Tree: DashboardPage > FormCard > ActionRow > SubmitButton'));
    expect(md, contains('Position: x:20, y:100 (w:200, h:50)'));
    expect(md, contains('Note: Change button text to Save'));
    expect(md, contains('2. [AREA] **CustomHeader**'));
    expect(md, contains('Note: Padding is too small'));
  });

  test('AnnotterExporter formats multi-view sections and environment correctly', () {
    final item1 = AnnotterItem(
      id: 1,
      number: 1,
      rect: const Rect.fromLTWH(24, 180, 336, 48),
      widgetName: 'HomeSearchBar',
      hierarchy: ['HomeSearchBar', 'CustomScrollView', 'HomeScreen'],
      note: 'Change placeholder',
      mode: AnnotterMode.widget,
      screenName: 'HomeScreen',
    );
    final item2 = AnnotterItem(
      id: 2,
      number: 2,
      rect: const Rect.fromLTWH(20, 210, 344, 115),
      widgetName: 'MissionCard',
      hierarchy: ['MissionCard', 'MissionSection', 'CustomScrollView', 'HomeScreen'],
      note: 'Margin is too tight',
      mode: AnnotterMode.area,
      screenName: 'HomeScreen',
    );

    final sections = [
      AnnotterViewSection(
        title: 'HomeScreen (Top)',
        screenshotPath: '/sdcard/Download/annotter_view_1.png',
        items: [item1],
      ),
      AnnotterViewSection(
        title: 'HomeScreen (Scrolled to 650px)',
        screenshotPath: '/sdcard/Download/annotter_view_2.png',
        items: [item2],
      ),
    ];

    final env = AnnotterEnvironment(
      platform: 'Android',
      theme: 'Dark Mode',
      textScale: '1.0x',
      orientation: 'Portrait',
      devicePixelRatio: 2.75,
      route: '/home',
      timestamp: DateTime(2026, 9, 3, 20, 10, 42),
    );

    final md = AnnotterExporter.toMarkdown(
      items: [item1, item2],
      viewportSize: const Size(384, 805),
      sections: sections,
      environment: env,
    );

    expect(md, contains('## UI Revision Request (Total: 2 notes across 2 views)'));
    expect(md, contains('**Environment:** Android • Dark Mode • Text Scale: 1.0x • Portrait'));
    expect(md, contains('**Viewport:** 384x805 (DPR: 2.75x)'));
    expect(md, contains('**Route:** /home'));
    expect(md, contains('**Generated:** 2026-09-03 20:10:42'));
    expect(md, contains('### 📸 View 1: HomeScreen (Top)'));
    expect(md, contains('**Screenshot:** `/sdcard/Download/annotter_view_1.png`'));
    expect(md, contains('1. [WIDGET] **HomeSearchBar**'));
    expect(md, contains('Tree: HomeScreen > CustomScrollView > HomeSearchBar'));
    expect(md, contains('Note: Change placeholder'));
    expect(md, contains('### 📸 View 2: HomeScreen (Scrolled to 650px)'));
    expect(md, contains('**Screenshot:** `/sdcard/Download/annotter_view_2.png`'));
    expect(md, contains('2. [AREA] **MissionCard**'));
    expect(md, contains('Note: Margin is too tight'));
  });
}
