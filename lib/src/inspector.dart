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
  // Set of internal framework and layout primitives to ignore
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
    'DecoratedBox',
    'ConstrainedBox',
    'Padding',
    'ColoredBox',
    'SizedBox',
    'Transform',
    'Opacity',
    'Offstage',
    'CustomPaint',
    // Gestures & Events
    'GestureDetector',
    'RawGestureDetector',
    'Listener',
    'MouseRegion',
    'InkWell',
    'InkResponse',
    'TapRegionSurface',
    'TapRegion',
    'NotificationListener',
    // Internal Framework & State
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
    // Annotter widgets
    'Annotter',
    'AnnotterOverlay',
    'AnnotterCanvas',
    'AnnotationDialog',
    '_RenderInkFeatures',
  };

  // ponytail: HitTest scan with aggressive framework noise filtering to pinpoint custom widgets.
  static InspectedWidgetInfo inspectAt(BuildContext context, Offset globalOffset) {
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
    Rect detectedRect = Rect.fromCenter(center: globalOffset, width: 40, height: 40);

    for (final entry in hitResult.path) {
      final target = entry.target;
      if (target is RenderObject) {
        if (target is RenderBox && target.hasSize && detectedRect.width <= 40) {
          try {
            final origin = target.localToGlobal(Offset.zero);
            if (origin.isFinite && target.size.isFinite && target.size.width > 0 && target.size.height > 0) {
              detectedRect = origin & target.size;
            }
          } catch (_) {}
        }

        if (kDebugMode) {
          final creator = target.debugCreator;
          if (creator is DebugCreator) {
            final element = creator.element;
            final widgetType = element.widget.runtimeType.toString();

            if (!_isNoise(widgetType)) {
              if (foundWidgetName == 'CustomElement') {
                foundWidgetName = widgetType;
              }
              if (!hierarchy.contains(widgetType)) {
                hierarchy.add(widgetType);
              }
            }

            // Traverse ancestors to find user custom widgets and screen name
            element.visitAncestorElements((ancestor) {
              final type = ancestor.widget.runtimeType.toString();
              if (type.endsWith('Screen') || type.endsWith('Page') || type.endsWith('View')) {
                detectedScreen ??= type;
              }

              if (!_isNoise(type) && !hierarchy.contains(type)) {
                if (foundWidgetName == 'CustomElement') {
                  foundWidgetName = type;
                }
                hierarchy.add(type);
              }
              return hierarchy.length < 8;
            });
          }
        }
      }
    }

    return InspectedWidgetInfo(
      name: foundWidgetName,
      hierarchy: hierarchy,
      rect: detectedRect,
      screenName: detectedScreen,
    );
  }

  static bool _isNoise(String type) {
    if (type.startsWith('_')) return true;
    return _frameworkNoise.contains(type);
  }
}
