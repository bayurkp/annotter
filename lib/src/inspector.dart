import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class InspectedWidgetInfo {
  final String widgetName;
  final List<String> hierarchy;
  final Rect rect;
  final String? screenName;
  final bool isScrollable;
  final String? selectedText;
  final String? sourceLocation;
  final Map<String, String>? properties;

  const InspectedWidgetInfo({
    required this.widgetName,
    required this.hierarchy,
    required this.rect,
    this.screenName,
    this.isScrollable = false,
    this.selectedText,
    this.sourceLocation,
    this.properties,
  });
}

class _TargetCandidate {
  final Widget widget;
  final String name;
  final int priority;

  const _TargetCandidate(this.widget, this.name, this.priority);
}

class WidgetInspectorHelper {
  /// Layout primitives: structural vocabulary of Flutter, equivalent to
  /// HTML's <div>, <span>, <section>. Never a semantic component name.
  /// Stable since Flutter 1.0, will never change.
  static const _layoutPrimitives = {
    'Container',
    'SizedBox',
    'Padding',
    'Center',
    'Align',
    'Row',
    'Column',
    'Stack',
    'Flex',
    'Wrap',
    'Expanded',
    'Flexible',
    'Spacer',
  };

  /// Determines whether a widget is a component-level candidate for the
  /// Annotter UI Tree. Uses an architectural heuristic, not a name blacklist.
  ///
  /// Pipeline:
  ///   Element traversal
  ///     → Stateless / Stateful boundary
  ///     → Private / Annotter filter
  ///     → Layout primitive filter
  ///     → Semantic Component Tree
  ///
  /// Principles:
  ///   ❌ Don't filter based on "looks unimportant"
  ///   ❌ Don't blacklist Builder/Focus/GestureDetector
  ///   ❌ Don't blacklist based on contains()
  ///   ✅ Filter by architectural type
  ///   ✅ Filter private/internal
  ///   ✅ Filter Annotter infrastructure
  ///   ✅ Filter layout primitives (structural vocabulary)
  static bool _isComponentCandidate(Widget widget) {
    // 1. Component boundary: StatelessWidget / StatefulWidget
    //    (includes ConsumerWidget, HookWidget, BlocBuilder, etc.)
    //    RenderObjectWidget, InheritedWidget, ParentDataWidget are not components.
    if (widget is! StatelessWidget && widget is! StatefulWidget) {
      return false;
    }

    // 2. Private/internal Flutter widgets (unreachable by developer code)
    final type = cleanType(widget.runtimeType.toString());
    if (type.startsWith('_')) return false;

    // 3. Annotter's own overlay infrastructure
    if (type.contains('Annotter')) return false;

    // 4. Layout primitives (structural vocabulary, not semantic components)
    if (_layoutPrimitives.contains(type)) return false;

    return true;
  }

  /// Framework plumbing and theme wrappers that should never be selected as the main target
  static const _frameworkPlumbing = {
    // Layout primitives
    'Container', 'SizedBox', 'Padding', 'Center', 'Align',
    'Row', 'Column', 'Stack', 'Flex', 'Wrap',
    'Expanded', 'Flexible', 'Spacer', 'SafeArea', 'Scaffold',
    // Theme & canvas infrastructure
    'Material', 'Theme', 'CupertinoTheme', 'AnimatedTheme',
    'DefaultTextStyle', 'AnimatedDefaultTextStyle',
    'AnimatedPhysicalModel', 'ScrollNotificationObserver',
    'KeyedSubtree', 'AutomaticKeepAlive', 'StretchEffect',
    'StretchingOverscrollIndicator', 'RefreshIndicator',
  };

  /// Priority scoring for target resolution:
  ///   100: Developer Custom Component (AppButton, HomeActivityStatsCard, HomeMenuSearchBar, etc.)
  ///    90: Semantic Interactive (ElevatedButton, TextField, etc.)
  ///    80: Semantic Content (Icon, Text, Image)
  ///    50: Screen / Page container (HomeScreen, etc.)
  ///    30: Layout primitive / Framework plumbing (SafeArea, Material, Theme, etc.)
  ///    10: Behavioral wrapper (RawGestureDetector, Focus, Builder, InkResponse, etc.)
  static int _calculatePriority(Widget widget, String name) {
    // 1. Behavioral wrappers (plumbing)
    if (widget is RawGestureDetector ||
        widget is GestureDetector ||
        widget is Focus ||
        widget is Actions ||
        widget is Shortcuts ||
        widget is Builder ||
        widget is StatefulBuilder ||
        widget is ImplicitlyAnimatedWidget ||
        widget is AnimatedWidget ||
        widget is InkResponse) {
      return 10;
    }

    // 2. Framework plumbing & layout primitives
    if (_frameworkPlumbing.contains(name) || _layoutPrimitives.contains(name)) {
      return 30;
    }

    // 3. Screen / Page containers (should not override child components)
    if (name.endsWith('Screen') ||
        name.endsWith('Page') ||
        name.endsWith('View')) {
      return 50;
    }

    // 4. Semantic Content
    if (name == 'Icon' ||
        name == 'Text' ||
        name == 'Image' ||
        name == 'RichText' ||
        name == 'CircleAvatar') {
      return 80;
    }

    // 5. Semantic Interactive standard Flutter
    if (name == 'ElevatedButton' ||
        name == 'TextButton' ||
        name == 'FilledButton' ||
        name == 'OutlinedButton' ||
        name == 'IconButton' ||
        name == 'FloatingActionButton' ||
        name == 'TextField' ||
        name == 'Checkbox' ||
        name == 'Switch' ||
        name == 'Radio' ||
        name == 'Slider') {
      return 90;
    }

    // 6. Developer Custom Component (AppButton, MissionCard, etc.)
    return 100;
  }

  /// Resolves the primary semantic target name from the candidate chain.
  /// Uses the composite format: [OuterComponent > InnerElement]
  /// e.g. AppButton > Text, AppBottomNavigationBar > Icon, HomeActivityStatsCard > Text.
  static String _resolveTarget(List<_TargetCandidate> candidates) {
    if (candidates.isEmpty) return 'Element';

    // 1. Find the innermost semantic element (priority 80 or 90) climbing bottom-up
    String? innerElement;
    for (final c in candidates) {
      if (c.priority == 80 || c.priority == 90) {
        innerElement = c.name;
        break;
      }
    }

    // 2. Find the nearest enclosing developer custom component (priority 100)
    String? outerComponent;
    for (final c in candidates) {
      if (c.priority == 100) {
        outerComponent = c.name;
        break;
      }
    }

    // 3. Composite logic:
    if (outerComponent != null &&
        innerElement != null &&
        outerComponent != innerElement) {
      return '$outerComponent > $innerElement';
    }

    if (outerComponent != null) {
      return outerComponent;
    }

    if (innerElement != null) {
      return innerElement;
    }

    final sorted = List.of(candidates)
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return sorted.first.name;
  }

  static String cleanType(String type) {
    final idx = type.indexOf('<');
    return idx != -1 ? type.substring(0, idx) : type;
  }

  /// Hit-tests the application RenderBox directly using local coordinates.
  static InspectedWidgetInfo inspectAt(
    BuildContext context,
    Offset localOffset, {
    bool fastPreview = false,
  }) {
    final canvasBox = context.findRenderObject() as RenderBox?;
    final parent = canvasBox?.parent;

    RenderBox? appBox;
    if (parent is ContainerRenderObjectMixin<RenderBox, StackParentData>) {
      final first = parent.firstChild;
      if (first != null && first != canvasBox) {
        appBox = first;
      }
    }

    final boxResult = BoxHitTestResult();
    if (appBox != null) {
      appBox.hitTest(boxResult, position: localOffset);
    }

    RenderBox? bestTarget;
    Rect? smallestRect;
    double smallestArea = double.infinity;
    bool detectedScrollable = false;

    // Pass 1: Quick geometric scan to find smallest RenderBox without heavy tree walks
    for (final entry in boxResult.path) {
      final target = entry.target;

      final targetType = target.runtimeType.toString();
      if (target is RenderSliver ||
          targetType.contains('Sliver') ||
          targetType.contains('Viewport')) {
        detectedScrollable = true;
      }

      if (target is RenderBox && target.hasSize && canvasBox != null) {
        try {
          final globalTopLeft = target.localToGlobal(Offset.zero);
          final globalBottomRight = target
              .localToGlobal(Offset(target.size.width, target.size.height));
          final targetLocalTopLeft = canvasBox.globalToLocal(globalTopLeft);
          final targetLocalBottomRight =
              canvasBox.globalToLocal(globalBottomRight);

          if (targetLocalTopLeft.isFinite && targetLocalBottomRight.isFinite) {
            final boxRect =
                Rect.fromPoints(targetLocalTopLeft, targetLocalBottomRight);
            final area = boxRect.width * boxRect.height;

            if (boxRect.width >= 4 &&
                boxRect.height >= 4 &&
                area < smallestArea) {
              smallestArea = area;
              smallestRect = boxRect;
              bestTarget = target;
            }
          }
        } catch (_) {}
      }
    }

    String foundWidgetName = 'Element';
    String? detectedScreen;
    List<String> bestHierarchy = [];
    String? extractedText;
    String? detectedSourceLocation;
    Map<String, String>? detectedProperties;

    // Pass 2: Inspect ONLY the single best RenderBox (0ms overhead)
    if (bestTarget != null &&
        kDebugMode &&
        bestTarget.debugCreator is DebugCreator) {
      final element = (bestTarget.debugCreator as DebugCreator).element;
      final List<String> chain = [];
      final List<_TargetCandidate> candidates = [];

      // Helper to extract Flutter source location (file and line) from Diagnostics
      String? extractSource(Element el) {
        if (fastPreview || detectedSourceLocation != null) return detectedSourceLocation;
        try {
          final info = el.toDiagnosticsNode();
          final desc = info.toString();
          final match = RegExp(r'(package:[^\s)]+|lib/[^\s)]+):(\d+)(?::(\d+))?')
              .firstMatch(desc);
          if (match != null) {
            return match.group(0);
          }
        } catch (_) {}
        return null;
      }

      // Helper to extract Flutter native widget properties (DiagnosticsNode)
      Map<String, String> extractProperties(Element el) {
        if (fastPreview) return const {};
        final Map<String, String> props = {};
        try {
          final node = el.toDiagnosticsNode();
          for (final prop in node.getProperties()) {
            final name = prop.name;
            if (name == null || name.startsWith('_')) continue;
            // Relevant Flutter UI styling and layout properties
            const relevantProps = {
              'data', 'fontSize', 'fontWeight', 'fontStyle', 'color', 'textAlign',
              'padding', 'margin', 'alignment', 'width', 'height',
              'mainAxisAlignment', 'crossAxisAlignment', 'mainAxisSize',
              'elevation', 'borderRadius', 'decoration', 'flex', 'fit',
              'icon', 'size', 'enabled', 'selected', 'value', 'crossAxisCount',
            };
            if (relevantProps.contains(name)) {
              final val = prop.toDescription();
              if (val.isNotEmpty && val != 'null') {
                props[name] = val;
              }
            }
          }
        } catch (_) {}
        return props;
      }

      void checkWidgetForText(Widget w) {
        if (extractedText != null) return;
        if (w is Text && w.data != null && w.data!.trim().isNotEmpty) {
          extractedText = w.data!.trim();
        } else if (w is SelectableText &&
            w.data != null &&
            w.data!.trim().isNotEmpty) {
          extractedText = w.data!.trim();
        } else if (w is RichText) {
          final plain = w.text.toPlainText().trim();
          if (plain.isNotEmpty) extractedText = plain;
        }
      }

      checkWidgetForText(element.widget);
      if (!fastPreview) {
        detectedSourceLocation = extractSource(element);
        final initialProps = extractProperties(element);
        if (initialProps.isNotEmpty) {
          detectedProperties = initialProps;
        }
      }

      if (_isComponentCandidate(element.widget)) {
        final rawType = cleanType(element.widget.runtimeType.toString());
        chain.add(rawType);
        candidates.add(_TargetCandidate(element.widget, rawType,
            _calculatePriority(element.widget, rawType)));
      }

      element.visitAncestorElements((ancestor) {
        final aw = ancestor.widget;
        checkWidgetForText(aw);
        if (!fastPreview) {
          if (detectedSourceLocation == null) {
            detectedSourceLocation = extractSource(ancestor);
          }
          if (detectedProperties == null || detectedProperties!.isEmpty) {
            final p = extractProperties(ancestor);
            if (p.isNotEmpty) detectedProperties = p;
          }
        }

        final type = cleanType(aw.runtimeType.toString());

        if (aw is Scrollable ||
            type == 'CustomScrollView' ||
            type == 'ListView' ||
            type == 'SingleChildScrollView' ||
            type == 'GridView' ||
            type.contains('Scrollable') ||
            type.contains('ScrollView')) {
          detectedScrollable = true;
        }

        if ((type.endsWith('Screen') || type.endsWith('Page')) &&
            type != 'RawView' &&
            !type.startsWith('_')) {
          detectedScreen ??= type;
        }

        if (_isComponentCandidate(aw)) {
          if (chain.isEmpty || chain.last != type) {
            chain.add(type);
            candidates
                .add(_TargetCandidate(aw, type, _calculatePriority(aw, type)));
          }
        }

        return chain.length < 15;
      });

      if (chain.isNotEmpty) {
        foundWidgetName = _resolveTarget(candidates);
        bestHierarchy = List.from(chain);
      }

      if (extractedText != null) {
        final truncated = extractedText!.length > 30
            ? '${extractedText!.substring(0, 27)}...'
            : extractedText!;
        if (foundWidgetName.endsWith('Text')) {
          foundWidgetName = '$foundWidgetName ("$truncated")';
        }
      }
    }

    return InspectedWidgetInfo(
      widgetName: foundWidgetName,
      hierarchy: bestHierarchy,
      rect: smallestRect ??
          Rect.fromCenter(center: localOffset, width: 40, height: 40),
      screenName: detectedScreen,
      isScrollable: detectedScrollable,
      selectedText: extractedText,
      sourceLocation: detectedSourceLocation,
      properties: detectedProperties,
    );
  }

  /// Traverses the mounted element tree to find the currently active/visible Screen or Page.
  static String? detectActiveScreen(BuildContext context) {
    String? activeScreen;

    void visitor(Element element) {
      final widget = element.widget;

      if (widget is Offstage && widget.offstage) {
        return;
      }
      if (widget is Visibility && !widget.visible) {
        return;
      }

      final rawType = widget.runtimeType.toString();
      final type = cleanType(rawType);
      if ((type.endsWith('Screen') || type.endsWith('Page')) &&
          type != 'RawView' &&
          !type.startsWith('_')) {
        activeScreen = type;
      }

      element.visitChildren(visitor);
    }

    try {
      (context as Element).visitChildren(visitor);
    } catch (_) {}

    return activeScreen;
  }
}
