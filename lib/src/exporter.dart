import 'package:flutter/services.dart';
import 'models.dart';

class AnnotterExporter {
  /// Formats annotations into structured Markdown grouped by screen or view section for AI agents.
  static String toMarkdown({
    required List<AnnotterItem> items,
    String? routeName,
    Size? viewportSize,
    String? screenshotPath,
    List<AnnotterViewSection>? sections,
    AnnotterEnvironment? environment,
    String detailLevel = 'detailed',
    bool includeTree = true,
  }) {
    final buffer = StringBuffer();

    final totalNotes = items.length;
    final totalViews =
        (sections != null && sections.isNotEmpty) ? sections.length : 1;

    buffer.writeln(
        '## UI Revision Request (Total: $totalNotes notes across $totalViews ${totalViews == 1 ? "view" : "views"})');

    if (environment != null && detailLevel != 'compact') {
      buffer.writeln(
          '**Environment:** ${environment.platform} • ${environment.theme} • Text Scale: ${environment.textScale} • ${environment.orientation}');
    }

    if (viewportSize != null && detailLevel != 'compact') {
      final dprString = environment != null
          ? ' (DPR: ${environment.devicePixelRatio.toStringAsFixed(2)}x)'
          : '';
      buffer.writeln(
          '**Viewport:** ${viewportSize.width.toInt()}x${viewportSize.height.toInt()}$dprString');
    }

    if (environment?.route != null && environment!.route!.isNotEmpty) {
      buffer.writeln('**Route:** ${environment.route}');
    }

    final dateStr = environment != null
        ? environment.timestamp
            .toIso8601String()
            .substring(0, 19)
            .replaceFirst('T', ' ')
        : DateTime.now()
            .toIso8601String()
            .substring(0, 19)
            .replaceFirst('T', ' ');
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
          buffer.writeln('### Page: ${sec.title}');
        } else {
          buffer.writeln('### View ${i + 1}: ${sec.title}');
        }

        if (sec.screenshotPath != null && sec.screenshotPath!.isNotEmpty) {
          _formatScreenshotLine(buffer, sec.screenshotPath!, environment);
        }
        buffer.writeln();

        for (final item in sec.items) {
          _formatItem(buffer, item,
              detailLevel: detailLevel,
              includeTree: includeTree,
              viewportSize: viewportSize);
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
      final screen =
          (item.screenName.isNotEmpty && item.screenName != 'Current Screen')
              ? item.screenName
              : (routeName != null && routeName.isNotEmpty && routeName != '/'
                  ? routeName
                  : 'Current Screen');
      grouped.putIfAbsent(screen, () => []).add(item);
    }

    if (screenshotPath != null && screenshotPath.isNotEmpty) {
      _formatScreenshotLine(buffer, screenshotPath, environment);
      buffer.writeln();
    }

    for (final entry in grouped.entries) {
      buffer.writeln('### Page: ${entry.key}');
      for (final item in entry.value) {
        _formatItem(buffer, item,
            detailLevel: detailLevel,
            includeTree: includeTree,
            viewportSize: viewportSize);
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  static void _formatScreenshotLine(
    StringBuffer buffer,
    String path,
    AnnotterEnvironment? environment,
  ) {
    buffer.writeln('**Snapshot:** `$path`');

    final platform = environment?.platform;
    final isAndroid = platform == 'Android' ||
        path.startsWith('/sdcard') ||
        path.startsWith('/storage/emulated');
    final isIos = platform == 'iOS';

    if (isAndroid) {
      buffer.writeln('  > *Fetch via ADB:* `adb pull $path ./`');
    } else if (isIos) {
      buffer.writeln(
          '  > *iOS Sandbox:* Sandboxed in app documents. Connect via Wi-Fi/MCP bridge to sync directly.');
    }
  }

  static void _formatItem(
    StringBuffer buffer,
    AnnotterItem item, {
    String detailLevel = 'detailed',
    bool includeTree = true,
    Size? viewportSize,
  }) {
    final tags = <String>[item.mode.name.toUpperCase()];
    if (item.intent != null && item.intent!.isNotEmpty) {
      tags.add(item.intent!.toUpperCase());
    }
    if (item.severity != null && item.severity!.isNotEmpty) {
      tags.add(item.severity!.toUpperCase());
    }

    final tagString = tags.map((t) => '[$t]').join('');

    // --- 1. FORENSIC TIER ---
    if (detailLevel == 'forensic') {
      buffer.writeln('${item.number}. $tagString **${item.widgetName}**');
      if (includeTree && item.hierarchy.isNotEmpty) {
        final breadcrumb = item.hierarchy.reversed.join(' > ');
        buffer.writeln('   - Tree: $breadcrumb');
      }
      buffer.writeln(
          '   - Position: x:${item.rect.left.toInt()}, y:${item.rect.top.toInt()} (w:${item.rect.width.toInt()}, h:${item.rect.height.toInt()})');

      if (viewportSize != null &&
          viewportSize.width > 0 &&
          viewportSize.height > 0) {
        final pctLeft =
            ((item.rect.left / viewportSize.width) * 100).toStringAsFixed(1);
        final pctTop =
            ((item.rect.top / viewportSize.height) * 100).toStringAsFixed(1);
        buffer.writeln('   - Relative: $pctLeft% from left, $pctTop% from top');
      }

      if (item.selectedText != null && item.selectedText!.isNotEmpty) {
        buffer.writeln('   - Content: "${item.selectedText}"');
      }

      if (item.sourceLocation != null && item.sourceLocation!.isNotEmpty) {
        buffer.writeln('   - Source: `${item.sourceLocation}`');
      }

      if (item.properties != null && item.properties!.isNotEmpty) {
        final formattedProps = item.properties!.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
        buffer.writeln('   - Properties: {$formattedProps}');
      }

      final primarySearchWidget = item.widgetName.contains(' > ')
          ? item.widgetName.split(' > ').first
          : item.widgetName;
      buffer.writeln(
          '   - Search tips: Try `grep -r "$primarySearchWidget" lib/`');

      buffer.writeln(
          '   - Note: ${item.note.isEmpty ? "*(No note provided)*" : item.note}');
      buffer.writeln();
      return;
    }

    // --- 2. DETAILED TIER (Default) ---
    if (detailLevel == 'detailed') {
      buffer.writeln('${item.number}. $tagString **${item.widgetName}**');
      if (item.sourceLocation != null && item.sourceLocation!.isNotEmpty) {
        buffer.writeln('   - Source: `${item.sourceLocation}`');
      }
      if (includeTree && item.hierarchy.isNotEmpty) {
        final breadcrumb = item.hierarchy.reversed.join(' > ');
        buffer.writeln('   - Tree: $breadcrumb');
      }
      buffer.writeln(
          '   - Position: x:${item.rect.left.toInt()}, y:${item.rect.top.toInt()} (w:${item.rect.width.toInt()}, h:${item.rect.height.toInt()})');

      if (item.selectedText != null && item.selectedText!.isNotEmpty) {
        buffer.writeln('   - Content: "${item.selectedText}"');
      }

      if (item.properties != null && item.properties!.isNotEmpty) {
        final formattedProps = item.properties!.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
        buffer.writeln('   - Properties: {$formattedProps}');
      }

      buffer.writeln(
          '   - Note: ${item.note.isEmpty ? "*(No note provided)*" : item.note}');
      buffer.writeln();
      return;
    }

    // --- 3. STANDARD TIER ---
    if (detailLevel == 'standard') {
      buffer.writeln('${item.number}. $tagString **${item.widgetName}**');
      if (item.sourceLocation != null && item.sourceLocation!.isNotEmpty) {
        buffer.writeln('   - Source: `${item.sourceLocation}`');
      }
      if (includeTree && item.hierarchy.isNotEmpty) {
        final breadcrumb = item.hierarchy.reversed.join(' > ');
        buffer.writeln('   - Tree: $breadcrumb');
      }
      buffer.writeln(
          '   - Position: x:${item.rect.left.toInt()}, y:${item.rect.top.toInt()} (w:${item.rect.width.toInt()}, h:${item.rect.height.toInt()})');

      if (item.selectedText != null && item.selectedText!.isNotEmpty) {
        buffer.writeln('   - Content: "${item.selectedText}"');
      }

      buffer.writeln(
          '   - Note: ${item.note.isEmpty ? "*(No note provided)*" : item.note}');
      buffer.writeln();
      return;
    }

    // --- 4. COMPACT TIER (One-liner summary) ---
    buffer.writeln('${item.number}. $tagString **${item.widgetName}**');
    if (includeTree && item.hierarchy.isNotEmpty) {
      final breadcrumb = item.hierarchy.reversed.join(' > ');
      buffer.writeln('   - Tree: $breadcrumb');
    }
    buffer.writeln(
        '   - Note: ${item.note.isEmpty ? "*(No note provided)*" : item.note}');
    buffer.writeln();
  }

  /// Copies formatted markdown annotations to the system clipboard.
  static Future<void> copyToClipboard({
    required List<AnnotterItem> items,
    String? routeName,
    Size? viewportSize,
    String? screenshotPath,
    List<AnnotterViewSection>? sections,
    AnnotterEnvironment? environment,
    String detailLevel = 'detailed',
    bool includeTree = true,
  }) async {
    final markdown = toMarkdown(
      items: items,
      routeName: routeName,
      viewportSize: viewportSize,
      screenshotPath: screenshotPath,
      sections: sections,
      environment: environment,
      detailLevel: detailLevel,
      includeTree: includeTree,
    );
    await Clipboard.setData(ClipboardData(text: markdown));
  }
}
