import 'package:flutter/services.dart';
import 'models.dart';

class AnnotterExporter {
  // Formats annotations into structured Markdown grouped by screen or view section for AI agents
  static String toMarkdown({
    required List<AnnotterItem> items,
    String? routeName,
    Size? viewportSize,
    String? screenshotPath,
    List<AnnotterViewSection>? sections,
    AnnotterEnvironment? environment,
  }) {
    final buffer = StringBuffer();

    final totalNotes = items.length;
    final totalViews = (sections != null && sections.isNotEmpty) ? sections.length : 1;

    buffer.writeln('## UI Revision Request (Total: $totalNotes notes across $totalViews ${totalViews == 1 ? "view" : "views"})');

    if (environment != null) {
      buffer.writeln('**Environment:** ${environment.platform} • ${environment.theme} • Text Scale: ${environment.textScale} • ${environment.orientation}');
    }

    if (viewportSize != null) {
      final dprString = environment != null ? ' (DPR: ${environment.devicePixelRatio.toStringAsFixed(2)}x)' : '';
      buffer.writeln('**Viewport:** ${viewportSize.width.toInt()}x${viewportSize.height.toInt()}$dprString');
    }

    if (environment?.route != null && environment!.route!.isNotEmpty) {
      buffer.writeln('**Route:** ${environment.route}');
    }

    final dateStr = environment != null
        ? environment.timestamp.toIso8601String().substring(0, 19).replaceFirst('T', ' ')
        : DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ');
    buffer.writeln('**Generated:** $dateStr');

    buffer.writeln();

    if (items.isEmpty) {
      buffer.writeln('*(No annotations recorded yet)*');
      return buffer.toString().trim();
    }

    // 1. Multi-View Section Format (if explicit view sections are provided)
    if (sections != null && sections.isNotEmpty) {
      for (int i = 0; i < sections.length; i++) {
        final sec = sections[i];
        if (sections.length == 1) {
          buffer.writeln('### 📱 Page: ${sec.title}');
        } else {
          buffer.writeln('### 📸 View ${i + 1}: ${sec.title}');
        }

        if (sec.screenshotPath != null && sec.screenshotPath!.isNotEmpty) {
          buffer.writeln('**Screenshot:** `${sec.screenshotPath}`');
        }
        buffer.writeln();

        for (final item in sec.items) {
          _formatItem(buffer, item);
        }
        if (i < sections.length - 1) {
          buffer.writeln('---');
          buffer.writeln();
        }
      }
      return buffer.toString().trim();
    }

    // 2. Standard Screen Grouping (Fallback)
    final Map<String, List<AnnotterItem>> grouped = {};
    for (final item in items) {
      final screen = (item.screenName.isNotEmpty && item.screenName != 'Current Screen')
          ? item.screenName
          : (routeName != null && routeName.isNotEmpty && routeName != '/'
              ? routeName
              : 'Current Screen');
      grouped.putIfAbsent(screen, () => []).add(item);
    }

    if (screenshotPath != null && screenshotPath.isNotEmpty) {
      buffer.writeln('**Screenshot:** `$screenshotPath`');
      buffer.writeln();
    }

    for (final entry in grouped.entries) {
      buffer.writeln('### 📱 Page: ${entry.key}');
      for (final item in entry.value) {
        _formatItem(buffer, item);
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  static void _formatItem(StringBuffer buffer, AnnotterItem item) {
    buffer.writeln('${item.number}. [${item.mode.name.toUpperCase()}] **${item.widgetName}**');
    if (item.hierarchy.isNotEmpty) {
      final breadcrumb = item.hierarchy.reversed.join(' > ');
      buffer.writeln('   - Tree: $breadcrumb');
    }
    buffer.writeln('   - Position: x:${item.rect.left.toInt()}, y:${item.rect.top.toInt()} (w:${item.rect.width.toInt()}, h:${item.rect.height.toInt()})');
    buffer.writeln('   - Note: ${item.note.isEmpty ? "*(No note provided)*" : item.note}');
    buffer.writeln();
  }

  // ponytail: Directly uses Flutter native Clipboard.
  static Future<void> copyToClipboard({
    required List<AnnotterItem> items,
    String? routeName,
    Size? viewportSize,
    String? screenshotPath,
    List<AnnotterViewSection>? sections,
    AnnotterEnvironment? environment,
  }) async {
    final markdown = toMarkdown(
      items: items,
      routeName: routeName,
      viewportSize: viewportSize,
      screenshotPath: screenshotPath,
      sections: sections,
      environment: environment,
    );
    await Clipboard.setData(ClipboardData(text: markdown));
  }
}
