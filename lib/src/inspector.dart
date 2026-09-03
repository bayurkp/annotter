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
  // Set of basic framework primitives that are built into Flutter
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
    'Annotter',
    'AnnotterCanvas',
    'AnnotationDialog',
  };

  static String cleanType(String type) {
    final idx = type.indexOf('<');
    return idx != -1 ? type.substring(0, idx) : type;
  }

  static bool _isCustomComponent(Widget widget) {
    if (widget is! StatelessWidget && widget is! StatefulWidget) {
      return false;
    }
    final type = cleanType(widget.runtimeType.toString());
    if (type.startsWith('_')) return false;
    if (type.contains('Annotter')) return false;
    if (type.contains('Builder')) return false;
    if (type.contains('Listener')) return false;
    return !_frameworkPrimitives.contains(type);
  }

  static InspectedWidgetInfo inspectAt(BuildContext context, Offset globalOrLocalOffset) {
    final canvasBox = context.findRenderObject() as RenderBox?;
    Offset localOffset;
    if (canvasBox != null) {
      try {
        localOffset = canvasBox.globalToLocal(globalOrLocalOffset);
        if (!localOffset.dx.isFinite || !localOffset.dy.isFinite) {
          localOffset = globalOrLocalOffset;
        }
      } catch (_) {
        localOffset = globalOrLocalOffset;
      }
    } else {
      localOffset = globalOrLocalOffset;
    }

    final hitResult = HitTestResult();
    bool hitAppDirectly = false;

    // Direct hit-test on child RenderBox in Stack
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
          WidgetsBinding.instance.hitTestInView(hitResult, globalOrLocalOffset, view.viewId);
        }
      } catch (_) {}
    }

    String foundWidgetName = 'CustomElement';
    String? detectedScreen;
    final List<String> hierarchy = [];
    Rect? smallestRect;
    bool detectedScrollable = false;

    for (final entry in hitResult.path) {
      final target = entry.target;
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

                // Find the nearest custom component in the ancestor chain
                Element? customElement;
                element.visitAncestorElements((ancestor) {
                  final aw = ancestor.widget;
                  final type = cleanType(aw.runtimeType.toString());

                  if (aw is Scrollable) {
                    detectedScrollable = true;
                  }

                  if ((type.endsWith('Screen') || type.endsWith('Page')) &&
                      type != 'RawView' &&
                      !type.startsWith('_')) {
                    detectedScreen ??= type;
                  }

                  if (customElement == null && _isCustomComponent(aw)) {
                    customElement = ancestor;
                  }

                  if (!hierarchy.contains(type) && !type.startsWith('_') && !type.contains('Annotter')) {
                    hierarchy.add(type);
                  }
                  return hierarchy.length < 8;
                });

                if (customElement != null) {
                  final customType = cleanType(customElement!.widget.runtimeType.toString());
                  // Use bounding box of target or custom element
                  if (smallestRect == null || area < (smallestRect.width * smallestRect.height)) {
                    smallestRect = boxRect;
                    foundWidgetName = customType;
                  }
                } else if (smallestRect == null) {
                  smallestRect = boxRect;
                  final rawType = cleanType(element.widget.runtimeType.toString());
                  if (foundWidgetName == 'CustomElement' && !rawType.startsWith('_')) {
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
