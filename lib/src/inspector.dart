import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class InspectedWidgetInfo {
  final String name;
  final List<String> hierarchy;
  final Rect rect;
  final String? screenName;
  final bool isScrollable;

  const InspectedWidgetInfo({
    required this.name,
    required this.hierarchy,
    required this.rect,
    this.screenName,
    this.isScrollable = false,
  });
}

class WidgetInspectorHelper {
  static const Set<String> _frameworkPrimitives = {
    // Focus, shortcuts & actions
    'Focus',
    'FocusScope',
    'Actions',
    'Shortcuts',
    'CallbackShortcuts',
    'PrimaryScrollController',
    'ScrollConfiguration',
    'Scrollable',
    'Scrollbar',
    'RawScrollbar',

    // Primitives & layout
    'Container',
    'Card',
    'Material',
    'Scaffold',
    'Center',
    'Align',
    'SizedBox',
    'Padding',
    'ColoredBox',
    'GestureDetector',
    'RawGestureDetector',
    'Listener',
    'MouseRegion',
    'TapRegion',
    'Semantics',
    'InkWell',
    'InkResponse',
    'SafeArea',
    'Stack',
    'Column',
    'Row',
    'Flex',
    'Expanded',
    'Flexible',
    'DecoratedBox',
    'ConstrainedBox',
    'UnconstrainedBox',
    'FractionallySizedBox',
    'LimitedBox',
    'OverflowBox',
    'SizedOverflowBox',
    'Offstage',
    'Visibility',
    'FittedBox',
    'AspectRatio',
    'CustomPaint',
    'SingleChildScrollView',
    'Hero',
    'DefaultTextStyle',
    'Text',
    'RichText',
    'Icon',
    'Image',
    'RawImage',
    'KeyedSubtree',
    'RepaintBoundary',
    'ClipRect',
    'ClipRRect',
    'ClipOval',
    'Transform',
    'Opacity',
    'BackdropFilter',
    'Positioned',

    // Annotter Studio internals
    'Annotter',
    'AnnotterCanvas',
    'AnnotationDialog',
    'AnnotationListSheet',
  };

  static String cleanType(String type) {
    final idx = type.indexOf('<');
    return idx != -1 ? type.substring(0, idx) : type;
  }

  static bool _isMeaningfulWidget(String type) {
    if (_frameworkPrimitives.contains(type)) return false;
    if (type.startsWith('_')) return false;
    if (type.contains('Annotter')) return false;
    if (type.contains('Builder')) return false;
    if (type.contains('Listener')) return false;
    if (type.contains('Transition')) return false;
    if (type.startsWith('Animated')) return false;
    if (type.startsWith('Default')) return false;
    if (type.startsWith('Raw')) return false;
    if (type.startsWith('Focus')) return false;
    if (type.startsWith('Action')) return false;
    if (type.startsWith('Shortcut')) return false;
    if (type.startsWith('Scroll')) return false;
    if (type.startsWith('Sliver')) return false;
    return true;
  }

  static bool _isCustomComponent(Widget widget) {
    if (widget is! StatelessWidget && widget is! StatefulWidget) {
      return false;
    }
    final type = cleanType(widget.runtimeType.toString());
    return _isMeaningfulWidget(type);
  }

  // ponytail: Hit-tests the app sibling RenderBox directly using local coordinates.
  static InspectedWidgetInfo inspectAt(BuildContext context, Offset localOffset) {
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

    String foundWidgetName = 'CustomElement';
    String? detectedScreen;
    final List<String> hierarchy = [];
    Rect? smallestRect;
    bool detectedScrollable = false;

    for (final entry in boxResult.path) {
      final target = entry.target;

      // Direct RenderSliver / Viewport check
      final targetType = target.runtimeType.toString();
      if (target is RenderSliver || targetType.contains('Sliver') || targetType.contains('Viewport')) {
        detectedScrollable = true;
      }

      if (target is RenderBox && target.hasSize && canvasBox != null) {
        try {
          final globalTopLeft = target.localToGlobal(Offset.zero);
          final globalBottomRight = target.localToGlobal(Offset(target.size.width, target.size.height));
          final targetLocalTopLeft = canvasBox.globalToLocal(globalTopLeft);
          final targetLocalBottomRight = canvasBox.globalToLocal(globalBottomRight);

          if (targetLocalTopLeft.isFinite && targetLocalBottomRight.isFinite) {
            final boxRect = Rect.fromPoints(targetLocalTopLeft, targetLocalBottomRight);
            final area = boxRect.width * boxRect.height;

            if (boxRect.width > 2 && boxRect.height > 2) {
              if (kDebugMode && target.debugCreator is DebugCreator) {
                final element = (target.debugCreator as DebugCreator).element;

                // Discover custom component and scrollable ancestors (up to 80 levels)
                Element? customElement;
                Element? firstMeaningfulElement;
                int depth = 0;
                element.visitAncestorElements((ancestor) {
                  depth++;
                  final aw = ancestor.widget;
                  final type = cleanType(aw.runtimeType.toString());

                  if (aw is Scrollable ||
                      type == 'CustomScrollView' ||
                      type == 'ListView' ||
                      type == 'SingleChildScrollView' ||
                      type == 'GridView' ||
                      type.contains('Scrollable') ||
                      type.contains('ScrollView') ||
                      type.startsWith('Sliver')) {
                    detectedScrollable = true;
                  }

                  if ((type.endsWith('Screen') || type.endsWith('Page')) &&
                      type != 'RawView' &&
                      !type.startsWith('_')) {
                    detectedScreen ??= type;
                  }

                  if (_isMeaningfulWidget(type)) {
                    firstMeaningfulElement ??= ancestor;
                    if (!hierarchy.contains(type) && hierarchy.length < 8) {
                      hierarchy.add(type);
                    }
                  }

                  if (customElement == null && _isCustomComponent(aw)) {
                    customElement = ancestor;
                  }

                  return depth < 80;
                });

                final chosenElement = customElement ?? firstMeaningfulElement;
                if (chosenElement != null) {
                  final chosenType = cleanType(chosenElement.widget.runtimeType.toString());
                  if (smallestRect == null || area < (smallestRect.width * smallestRect.height)) {
                    smallestRect = boxRect;
                    foundWidgetName = chosenType;
                  }
                } else if (smallestRect == null) {
                  smallestRect = boxRect;
                  final rawType = cleanType(element.widget.runtimeType.toString());
                  if (foundWidgetName == 'CustomElement' && _isMeaningfulWidget(rawType)) {
                    foundWidgetName = rawType;
                  }
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    return InspectedWidgetInfo(
      name: foundWidgetName,
      hierarchy: hierarchy,
      rect: smallestRect ?? Rect.fromCenter(center: localOffset, width: 40, height: 40),
      screenName: detectedScreen,
      isScrollable: detectedScrollable,
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
