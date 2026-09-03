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
  // Set of internal framework, layout primitives, and wrapper widgets to ignore
  static const Set<String> _frameworkNoise = {
    // Layout Primitives
    'Stack',
    'Positioned',
    'Row',
    'Column',
    'Flex',
    'Expanded',
    'Flexible',
    'Align',
    'Center',
    'Container',
    'ClipRRect',
    'ClipRect',
    'ClipOval',
    'DecoratedBox',
    'ConstrainedBox',
    'Padding',
    'ColoredBox',
    'SizedBox',
    'Transform',
    'Opacity',
    'Offstage',
    'CustomPaint',
    'FittedBox',
    'AspectRatio',
    'LimitedBox',
    'FractionallySizedBox',
    // Pointer, Gesture & Touch Handlers
    'IgnorePointer',
    'AbsorbPointer',
    'GestureDetector',
    'RawGestureDetector',
    'Listener',
    'MouseRegion',
    'InkWell',
    'InkResponse',
    'TapRegionSurface',
    'TapRegion',
    'NotificationListener',
    // Internal Framework & Structural Wrappers
    'Semantics',
    'RepaintBoundary',
    'KeyedSubtree',
    'Builder',
    'StatefulBuilder',
    'LayoutBuilder',
    'MetaData',
    'DefaultTextStyle',
    'AnimatedDefaultTextStyle',
    'DefaultSelectionStyle',
    'MediaQuery',
    'Directionality',
    'Localizations',
    'TickerMode',
    'AnimatedTheme',
    'Theme',
    'IconTheme',
    'ScaffoldMessenger',
    'Scaffold',
    'Focus',
    'FocusScope',
    'Actions',
    'Shortcuts',
    'RawView',
    'View',
    'Overlay',
    'OverlayEntry',
    'Navigator',
    'HeroControllerScope',
    'PrimaryScrollController',
    'Scrollable',
    'Viewport',
    'CustomScrollView',
    'SliverToBoxAdapter',
    'SliverPadding',
    'SliverList',
    'SingleChildScrollView',
    'Material',
    'SafeArea',
    'ModalBarrier',
    'BackdropFilter',
    // Annotter Internal Widgets
    'Annotter',
    'AnnotterOverlay',
    'AnnotterCanvas',
    'AnnotationDialog',
    '_RenderInkFeatures',
  };

  // ponytail: Converts target coordinates to local canvas space to ensure 1:1 pixel accuracy under FittedBox scaling.
  static InspectedWidgetInfo inspectAt(BuildContext context, Offset globalOffset) {
    final canvasBox = context.findRenderObject() as RenderBox?;
    final localFallback = canvasBox?.globalToLocal(globalOffset) ?? globalOffset;

    final hitResult = HitTestResult();
    try {
      final view = View.maybeOf(context);
      if (view != null) {
        WidgetsBinding.instance.hitTestInView(hitResult, globalOffset, view.viewId);
      }
    } catch (_) {}

    String foundWidgetName = 'CustomElement';
    String? detectedScreen;
    final List<String> hierarchy = [];
    Rect? smallestRect;

    for (final entry in hitResult.path) {
      final target = entry.target;
      if (target is RenderObject) {
        if (target is RenderBox && target.hasSize && canvasBox != null) {
          try {
            // Convert target bounding box from global screen coordinates into canvas local space
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
                  final widgetType = element.widget.runtimeType.toString();

                  if (!_isNoise(widgetType)) {
                    // Prefer the smallest enclosing non-noise widget
                    if (smallestRect == null || area < (smallestRect.width * smallestRect.height)) {
                      smallestRect = boxRect;
                      foundWidgetName = widgetType;
                    }
                    if (!hierarchy.contains(widgetType)) {
                      hierarchy.add(widgetType);
                    }
                  }

                  // Traverse ancestors to discover Screen/Page name and meaningful hierarchy
                  element.visitAncestorElements((ancestor) {
                    final type = ancestor.widget.runtimeType.toString();
                    if ((type.endsWith('Screen') || type.endsWith('Page')) &&
                        type != 'RawView' &&
                        !type.startsWith('_')) {
                      detectedScreen ??= type;
                    }

                    if (!_isNoise(type)) {
                      if (foundWidgetName == 'CustomElement' || foundWidgetName == 'RichText') {
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
      rect: smallestRect ?? Rect.fromCenter(center: localFallback, width: 40, height: 40),
      screenName: detectedScreen,
    );
  }

  /// Traverses the mounted element tree to find the currently active/visible Screen or Page.
  /// Automatically skips inactive Offstage branches (such as tabs in IndexedStack).
  static String? detectActiveScreen(BuildContext context) {
    String? activeScreen;

    void visitor(Element element) {
      final widget = element.widget;

      // Skip inactive/hidden tabs in IndexedStack or Offstage trees
      if (widget is Offstage && widget.offstage) {
        return;
      }
      if (widget is Visibility && !widget.visible) {
        return;
      }

      final type = widget.runtimeType.toString();
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

  static bool _isNoise(String type) {
    if (type.startsWith('_')) return true;
    if (type.contains('Annotter')) return true;
    return _frameworkNoise.contains(type);
  }
}

