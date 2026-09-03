import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class InspectedWidgetInfo {
  final String name;
  final List<String> hierarchy;
  final Rect rect;
  final String? screenName;

  const InspectedWidgetInfo({
    required this.name,
    required this.hierarchy,
    required this.rect,
    this.screenName,
  });
}

class WidgetInspectorHelper {
  // Set of basic framework composition primitives that are built into Flutter
  static const Set<String> _frameworkPrimitives = {
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
    'InkWell',
    'SafeArea',
    'Stack',
    'Column',
    'Row',
    'Flex',
    'Expanded',
    'Flexible',
    'DecoratedBox',
    'ConstrainedBox',
    'Offstage',
    'Visibility',
    'FittedBox',
    'AspectRatio',
    'CustomPaint',
    'SingleChildScrollView',
    'Hero',
    'DefaultTextStyle',
    'Annotter',
    'AnnotterCanvas',
    'AnnotationDialog',
  };

  // ponytail: Strips generic type parameters e.g. ValueListenableBuilder<bool> -> ValueListenableBuilder
  static String cleanType(String type) {
    final idx = type.indexOf('<');
    return idx != -1 ? type.substring(0, idx) : type;
  }

  // ponytail: Architectural validation: checks if a widget is a true user component.
  // In Flutter, user components always extend StatelessWidget or StatefulWidget.
  // Internal framework wrappers (InheritedWidget, RenderObjectWidget, etc.) are excluded.
  static bool _isNoise(Widget widget) {
    if (widget is! StatelessWidget && widget is! StatefulWidget) {
      return true;
    }

    final rawType = widget.runtimeType.toString();
    final type = cleanType(rawType);

    if (type.startsWith('_')) return true;
    if (type.contains('Annotter')) return true;
    if (type.contains('Builder')) return true;
    if (type.contains('Listener')) return true;

    return _frameworkPrimitives.contains(type);
  }

  // ponytail: Direct hit-test and architectural component resolution.
  static InspectedWidgetInfo inspectAt(BuildContext context, Offset globalOffset) {
    final canvasBox = context.findRenderObject() as RenderBox?;
    final localOffset = canvasBox?.globalToLocal(globalOffset) ?? globalOffset;

    final hitResult = HitTestResult();
    bool hitAppDirectly = false;

    // Direct app hit-test: bypasses outer studio and root window plumbing
    final parent = canvasBox?.parent;
    if (parent is ContainerRenderObjectMixin<RenderBox, StackParentData>) {
      final appBox = parent.firstChild;
      if (appBox != null && appBox != canvasBox) {
        final boxResult = BoxHitTestResult();
        if (appBox.hitTest(boxResult, position: localOffset)) {
          for (final entry in boxResult.path) {
            hitResult.add(entry);
          }
          hitAppDirectly = true;
        }
      }
    }

    if (!hitAppDirectly) {
      try {
        final view = View.maybeOf(context);
        if (view != null) {
          WidgetsBinding.instance.hitTestInView(hitResult, globalOffset, view.viewId);
        }
      } catch (_) {}
    }

    String foundWidgetName = 'CustomElement';
    String? detectedScreen;
    final List<String> hierarchy = [];
    Rect? smallestRect;

    for (final entry in hitResult.path) {
      final target = entry.target;
      if (target is RenderObject) {
        if (target is RenderBox && target.hasSize && canvasBox != null) {
          try {
            final globalTopLeft = target.localToGlobal(Offset.zero);
            final globalBottomRight = target.localToGlobal(Offset(target.size.width, target.size.height));
            final localTopLeft = canvasBox.globalToLocal(globalTopLeft);
            final localBottomRight = canvasBox.globalToLocal(globalBottomRight);

            if (localTopLeft.isFinite && localBottomRight.isFinite) {
              final boxRect = Rect.fromPoints(localTopLeft, localBottomRight);
              final area = boxRect.width * boxRect.height;

              if (boxRect.width > 2 && boxRect.height > 2) {
                if (kDebugMode && target.debugCreator is DebugCreator) {
                  final element = (target.debugCreator as DebugCreator).element;
                  final widget = element.widget;

                  if (!_isNoise(widget)) {
                    final widgetType = cleanType(widget.runtimeType.toString());
                    if (smallestRect == null || area < (smallestRect.width * smallestRect.height)) {
                      smallestRect = boxRect;
                      foundWidgetName = widgetType;
                    }
                    if (!hierarchy.contains(widgetType)) {
                      hierarchy.add(widgetType);
                    }
                  }

                  // Walk ancestor elements to discover active Screen and user custom components
                  element.visitAncestorElements((ancestor) {
                    final ancestorWidget = ancestor.widget;
                    final type = cleanType(ancestorWidget.runtimeType.toString());

                    if ((type.endsWith('Screen') || type.endsWith('Page')) &&
                        type != 'RawView' &&
                        !type.startsWith('_')) {
                      detectedScreen ??= type;
                    }

                    if (!_isNoise(ancestorWidget)) {
                      if (foundWidgetName == 'CustomElement') {
                        foundWidgetName = type;
                      }
                      if (!hierarchy.contains(type)) {
                        hierarchy.add(type);
                      }
                    }
                    return hierarchy.length < 8;
                  });
                }
              }
            }
          } catch (_) {}
        }
      }
    }

    return InspectedWidgetInfo(
      name: foundWidgetName,
      hierarchy: hierarchy,
      rect: smallestRect ?? Rect.fromCenter(center: localOffset, width: 40, height: 40),
      screenName: detectedScreen,
    );
  }

  /// Traverses the mounted element tree to find the currently active/visible Screen or Page.
  /// Automatically skips inactive Offstage branches (such as tabs in IndexedStack).
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
