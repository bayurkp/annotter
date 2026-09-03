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
  /// Determines whether a widget is a component-level candidate for the
  /// Annotter UI Tree. Uses an architectural heuristic, not a name blacklist.
  ///
  /// Principles:
  ///   Element           = traversal mechanism
  ///   Stateless/Stateful = component boundary
  ///   _                 = internal / private
  ///   Annotter          = infrastructure owned by Annotter
  ///   No widget-name blacklists
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

    return true;
  }

  static String cleanType(String type) {
    final idx = type.indexOf('<');
    return idx != -1 ? type.substring(0, idx) : type;
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

    String foundWidgetName = 'Element';
    String? detectedScreen;
    List<String> bestHierarchy = [];
    Rect? smallestRect;
    double smallestArea = double.infinity;
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

            if (boxRect.width >= 4 && boxRect.height >= 4) {
              if (kDebugMode && target.debugCreator is DebugCreator) {
                final element = (target.debugCreator as DebugCreator).element;
                final List<String> chain = [];

                if (_isComponentCandidate(element.widget)) {
                  final rawType = cleanType(element.widget.runtimeType.toString());
                  chain.add(rawType);
                }

                element.visitAncestorElements((ancestor) {
                  final aw = ancestor.widget;
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
                    }
                  }

                  return chain.length < 15;
                });

                if (chain.isNotEmpty && area < smallestArea) {
                  smallestArea = area;
                  smallestRect = boxRect;
                  foundWidgetName = chain.first;
                  bestHierarchy = List.from(chain);
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    return InspectedWidgetInfo(
      name: foundWidgetName,
      hierarchy: bestHierarchy,
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
