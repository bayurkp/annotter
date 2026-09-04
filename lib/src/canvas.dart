import 'package:flutter/material.dart';
import 'models.dart';
import 'inspector.dart';

class AnnotterCanvas extends StatefulWidget {
  final List<AnnotterItem> items;
  final AnnotterMode activeMode;
  final double currentScrollOffset;
  final Color? markerColor;
  final void Function(AnnotterItem item, String? screenName) onRequestCreate;
  final ValueChanged<AnnotterItem> onRequestEdit;

  const AnnotterCanvas({
    super.key,
    required this.items,
    required this.activeMode,
    this.currentScrollOffset = 0.0,
    this.markerColor,
    required this.onRequestCreate,
    required this.onRequestEdit,
  });

  @override
  State<AnnotterCanvas> createState() => _AnnotterCanvasState();
}

class _AnnotterCanvasState extends State<AnnotterCanvas> {
  Offset? _dragStart;
  Offset? _dragCurrent;
  InspectedWidgetInfo? _hoveredWidget;

  @override
  Widget build(BuildContext context) {
    final isNavigating = widget.activeMode == AnnotterMode.move;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: isNavigating,
        child: MouseRegion(
          onHover: (event) => _updateHover(event.localPosition),
          onExit: (_) {
            if (_hoveredWidget != null) setState(() => _hoveredWidget = null);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _handleTapDown,
            onPanStart:
                widget.activeMode == AnnotterMode.area ? _handlePanStart : null,
            onPanUpdate: widget.activeMode == AnnotterMode.area
                ? _handlePanUpdate
                : null,
            onPanEnd:
                widget.activeMode == AnnotterMode.area ? _handlePanEnd : null,
            child: CustomPaint(
              painter: _AnnotterPainter(
                items: widget.items,
                dragStart: _dragStart,
                dragCurrent: _dragCurrent,
                hoveredWidget: _hoveredWidget,
                currentScrollOffset: widget.currentScrollOffset,
                markerColor: widget.markerColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateHover(Offset localPos) {
    if (widget.activeMode != AnnotterMode.widget) {
      if (_hoveredWidget != null) setState(() => _hoveredWidget = null);
      return;
    }
    final info = WidgetInspectorHelper.inspectAt(context, localPos);
    if (_hoveredWidget?.rect != info.rect ||
        _hoveredWidget?.name != info.name) {
      setState(() => _hoveredWidget = info);
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.activeMode == AnnotterMode.move) return;

    // 1. Dedicated Select Mode: tap anywhere on annotation box or badge opens edit
    if (widget.activeMode == AnnotterMode.select) {
      final selectedItem =
          _findItemAt(details.localPosition, allowEntireRect: true);
      if (selectedItem != null) {
        widget.onRequestEdit(selectedItem);
      }
      return;
    }

    // 2. In other modes: direct tap on numbered badge edits the item
    final tappedItem =
        _findItemAt(details.localPosition, allowEntireRect: false);
    if (tappedItem != null) {
      widget.onRequestEdit(tappedItem);
      return;
    }

    // 2. Create new annotation based on active tool
    if (widget.activeMode == AnnotterMode.widget) {
      final info =
          WidgetInspectorHelper.inspectAt(context, details.localPosition);
      final newItem = AnnotterItem(
        id: DateTime.now().millisecondsSinceEpoch,
        number: widget.items.length + 1,
        rect: info.rect,
        widgetName: info.name,
        hierarchy: info.hierarchy,
        mode: AnnotterMode.widget,
        isScrollable: info.isScrollable,
        scrollOffsetAtCreation: widget.currentScrollOffset,
        selectedText: info.selectedText,
      );
      setState(() => _hoveredWidget = null);
      widget.onRequestCreate(newItem, info.screenName);
    } else if (widget.activeMode == AnnotterMode.point) {
      final pos = details.localPosition;
      final info = WidgetInspectorHelper.inspectAt(context, pos);
      final newItem = AnnotterItem(
        id: DateTime.now().millisecondsSinceEpoch,
        number: widget.items.length + 1,
        rect: Rect.fromCenter(center: pos, width: 32, height: 32),
        widgetName: info.name != 'Element' ? info.name : 'PointLocation',
        hierarchy: info.hierarchy,
        mode: AnnotterMode.point,
        isScrollable: info.isScrollable,
        scrollOffsetAtCreation: widget.currentScrollOffset,
        selectedText: info.selectedText,
      );
      widget.onRequestCreate(newItem, info.screenName);
    }
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _dragStart = details.localPosition;
      _dragCurrent = details.localPosition;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragCurrent = details.localPosition;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_dragStart != null && _dragCurrent != null) {
      final rect = Rect.fromPoints(_dragStart!, _dragCurrent!);
      if (rect.width > 12 && rect.height > 12) {
        final info = WidgetInspectorHelper.inspectAt(context, rect.center);
        final newItem = AnnotterItem(
          id: DateTime.now().millisecondsSinceEpoch,
          number: widget.items.length + 1,
          rect: rect,
          widgetName: (info.name != 'Element' &&
                  !info.name.contains('Gesture') &&
                  !info.name.contains('Detector'))
              ? info.name
              : 'SelectionArea',
          hierarchy: info.hierarchy,
          mode: AnnotterMode.area,
          isScrollable: info.isScrollable,
          scrollOffsetAtCreation: widget.currentScrollOffset,
          selectedText: info.selectedText,
        );
        widget.onRequestCreate(newItem, info.screenName);
      }
    }
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  AnnotterItem? _findItemAt(Offset pos, {bool allowEntireRect = false}) {
    for (final item in widget.items.reversed) {
      final dy = item.isScrollable
          ? (item.scrollOffsetAtCreation - widget.currentScrollOffset)
          : 0.0;
      final displayRect = item.rect.translate(0, dy);

      final badgeCenter = item.mode == AnnotterMode.point
          ? displayRect.center
          : Offset(displayRect.left + 12, displayRect.top + 12);

      // Direct hit on the circular numbered badge
      if ((pos - badgeCenter).distance <= 22) {
        return item;
      }

      // Hit anywhere inside the bounding rectangle (for Select tool)
      if (allowEntireRect && displayRect.contains(pos)) {
        return item;
      }
    }
    return null;
  }
}

class _AnnotterPainter extends CustomPainter {
  final List<AnnotterItem> items;
  final Offset? dragStart;
  final Offset? dragCurrent;
  final InspectedWidgetInfo? hoveredWidget;
  final double currentScrollOffset;
  final Color? markerColor;

  _AnnotterPainter({
    required this.items,
    this.dragStart,
    this.dragCurrent,
    this.hoveredWidget,
    this.currentScrollOffset = 0.0,
    this.markerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Live DevTools Inspector Highlight Box
    if (hoveredWidget != null) {
      final rect = hoveredWidget!.rect;
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

      // Translucent Blue Fill
      final hoverFill = Paint()
        ..color = const Color(0x330284C7)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, hoverFill);

      // Cyan Border
      final hoverBorder = Paint()
        ..color = const Color(0xFF0284C7)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(rrect, hoverBorder);

      // Floating DevTools Tag Banner
      final labelText =
          '${hoveredWidget!.name} ${rect.width.toInt()}×${rect.height.toInt()}';
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            decoration: TextDecoration.none,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final tagWidth = textPainter.width + 12;
      final tagHeight = 18.0;
      final tagTop = (rect.top - tagHeight >= 4)
          ? (rect.top - tagHeight)
          : rect.bottom + 2;
      final tagRect = Rect.fromLTWH(
          rect.left.clamp(4.0, size.width - tagWidth - 4),
          tagTop,
          tagWidth,
          tagHeight);

      final tagPaint = Paint()..color = const Color(0xFF0284C7);
      canvas.drawRRect(
          RRect.fromRectAndRadius(tagRect, const Radius.circular(4)), tagPaint);

      textPainter.paint(
        canvas,
        Offset(tagRect.left + 6, tagRect.top + 2),
      );
    }

    // 2. Existing Annotations (Transformed by Scroll Offset)
    for (final item in items) {
      final dy = item.isScrollable
          ? (item.scrollOffsetAtCreation - currentScrollOffset)
          : 0.0;
      final displayRect = item.rect.translate(0, dy);

      // Skip painting if scrolled completely off-screen
      if (displayRect.bottom < 0 || displayRect.top > size.height) {
        continue;
      }

      final color = _getColor(item.mode);

      if (item.mode != AnnotterMode.point) {
        final rrect =
            RRect.fromRectAndRadius(displayRect, const Radius.circular(8));
        final fillPaint = Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(rrect, fillPaint);

        final borderPaint = Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(rrect, borderPaint);
      }

      final badgeCenter = item.mode == AnnotterMode.point
          ? displayRect.center
          : Offset(displayRect.left + 12, displayRect.top + 12);

      final isResolved = item.status == 'resolved';
      final badgePaint = Paint()
        ..color = isResolved ? const Color(0xFF10B981) : color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(badgeCenter, 14, badgePaint);

      final badgeBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(badgeCenter, 14, badgeBorder);

      final textPainter = TextPainter(
        text: TextSpan(
          text: isResolved ? '✓' : '${item.number}',
          style: TextStyle(
            color: Colors.white,
            fontSize: isResolved ? 13 : 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'sans-serif',
            decoration: TextDecoration.none,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        badgeCenter - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    // 3. Active Drag Rectangle
    if (dragStart != null && dragCurrent != null) {
      final rect = Rect.fromPoints(dragStart!, dragCurrent!);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

      final activeFill = Paint()
        ..color = const Color(0xFF0284C7).withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, activeFill);

      final activeBorder = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(rrect, activeBorder);
    }
  }

  Color _getColor(AnnotterMode mode) {
    if (markerColor != null) return markerColor!;
    switch (mode) {
      case AnnotterMode.move:
        return const Color(0xFF10B981); // Emerald Green
      case AnnotterMode.select:
        return const Color(0xFF6366F1); // Indigo / Violet
      case AnnotterMode.widget:
        return const Color(0xFF0284C7); // DevTools Cyan/Blue
      case AnnotterMode.area:
        return const Color(0xFF38BDF8); // Sky blue
      case AnnotterMode.point:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotterPainter oldDelegate) => true;
}
