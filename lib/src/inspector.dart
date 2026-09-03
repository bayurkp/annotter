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

  // ponytail: HitTest scan that chooses the smallest non-noise widget (leaf-first precision).
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
    Rect? smallestRect;

    for (final entry in hitResult.path) {
      final target = entry.target;
      if (target is RenderObject) {
        if (target is RenderBox && target.hasSize) {
          try {
            final origin = target.localToGlobal(Offset.zero);
            final size = target.size;
            if (origin.isFinite && size.isFinite && size.width > 2 && size.height > 2) {
              final boxRect = origin & size;
              final area = boxRect.width * boxRect.height;

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

                // Traverse ancestors to discover Screen/Page name and hierarchy
                element.visitAncestorElements((ancestor) {
                  final type = ancestor.widget.runtimeType.toString();
                  if ((type.endsWith('Screen') || type.endsWith('Page')) &&
                      type != 'RawView' &&
                      !type.startsWith('_')) {
                    detectedScreen ??= type;
                  }

                  if (!_isNoise(type) && !hierarchy.contains(type)) {
                    hierarchy.add(type);
                  }
                  return hierarchy.length < 8;
                });
              }
            }
          } catch (_) {}
        }
      }
    }

    return InspectedWidgetInfo(
      name: foundWidgetName,
      hierarchy: hierarchy,
      rect: smallestRect ?? Rect.fromCenter(center: globalOffset, width: 40, height: 40),
      screenName: detectedScreen,
    );
  }

  static bool _isNoise(String type) {
    if (type.startsWith('_')) return true;
    if (type.contains('Annotter')) return true;
    return _frameworkNoise.contains(type);
  }
}
