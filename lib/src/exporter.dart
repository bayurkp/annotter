import 'package:flutter/services.dart';
import 'models.dart';

class AnnotterExporter {
  // Formats annotations into structured Markdown grouped by screen for AI agents
  static String toMarkdown({
    required List<AnnotterItem> items,
    String? routeName,
    Size? viewportSize,
    String? screenshotPath,
  }) {
    final buffer = StringBuffer();

    // Group items by screen name
    final Map<String, List<AnnotterItem>> grouped = {};
    for (final item in items) {
      final screen = (item.screenName.isNotEmpty && item.screenName != 'Current Screen')
          ? item.screenName
          : (routeName != null && routeName.isNotEmpty && routeName != '/'
              ? routeName
              : 'Current Screen');
      grouped.putIfAbsent(screen, () => []).add(item);
    }

    final totalPages = grouped.isEmpty ? 1 : grouped.keys.length;
    buffer.writeln('## UI Revision Request (Total: ${items.length} notes across $totalPages ${totalPages == 1 ? "page" : "pages"})');
    if (viewportSize != null) {
      buffer.writeln('**Viewport:** ${viewportSize.width.toInt()}x${viewportSize.height.toInt()}');
    }
    if (screenshotPath != null && screenshotPath.isNotEmpty) {
      buffer.writeln('**Screenshot:** `$screenshotPath`');
    }
    buffer.writeln();

    if (items.isEmpty) {
      buffer.writeln('*(No annotations recorded yet)*');
      return buffer.toString().trim();
    }

    for (final entry in grouped.entries) {
      buffer.writeln('### 📱 Page: ${entry.key}');
      for (final item in entry.value) {
        buffer.writeln('${item.number}. [${item.mode.name.toUpperCase()}] **${item.widgetName}**');
        if (item.hierarchy.isNotEmpty) {
          final hierarchyPath = item.hierarchy.reversed.map((w) => '<$w>').join(' ');
          buffer.writeln('   - **Hierarchy:** $hierarchyPath');
        }
        buffer.writeln('   - **Position:** x:${item.rect.left.toInt()}, y:${item.rect.top.toInt()} (w:${item.rect.width.toInt()}, h:${item.rect.height.toInt()})');
        buffer.writeln('   - **Feedback:** ${item.note.isEmpty ? "*(No comment provided)*" : item.note}');
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  // ponytail: Directly uses Flutter native Clipboard.
  static Future<void> copyToClipboard({
    required List<AnnotterItem> items,
    String? routeName,
    Size? viewportSize,
    String? screenshotPath,
  }) async {
    final markdown = toMarkdown(
      items: items,
      routeName: routeName,
      viewportSize: viewportSize,
      screenshotPath: screenshotPath,
    );
    await Clipboard.setData(ClipboardData(text: markdown));
  }
}
