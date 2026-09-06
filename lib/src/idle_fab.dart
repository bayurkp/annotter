import 'package:flutter/material.dart';
import 'tokens.dart';

/// Draggable Floating Action Button that triggers Annotter activation when idle.
/// Uses isolated internal state for 60fps/120fps zero-lag silky smooth dragging.
class AnnotterIdleFab extends StatefulWidget {
  final Offset initialPosition;
  final ValueChanged<Offset> onPositionChanged;
  final VoidCallback onTap;
  final int badgeCount;

  const AnnotterIdleFab({
    super.key,
    required this.initialPosition,
    required this.onPositionChanged,
    required this.onTap,
    required this.badgeCount,
  });

  @override
  State<AnnotterIdleFab> createState() => _AnnotterIdleFabState();
}

class _AnnotterIdleFabState extends State<AnnotterIdleFab> {
  late Offset _pos;

  @override
  void initState() {
    super.initState();
    _pos = widget.initialPosition;
  }

  @override
  void didUpdateWidget(covariant AnnotterIdleFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPosition != widget.initialPosition) {
      _pos = widget.initialPosition;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;

    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: Material(
        color: AnnotterColors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            final newPos = _pos + details.delta;
            final clamped = Offset(
              newPos.dx.clamp(8.0, size.width - 56.0),
              newPos.dy.clamp(mediaQuery.padding.top + 8, size.height - 56.0),
            );
            setState(() => _pos = clamped);
          },
          onPanEnd: (_) {
            widget.onPositionChanged(_pos);
          },
          child: Material(
            elevation: 8,
            shape: const CircleBorder(),
            color: AnnotterColors.primary,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.edit_note, color: AnnotterColors.white, size: 26),
                    if (widget.badgeCount > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AnnotterColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${widget.badgeCount}',
                            style: const TextStyle(
                              color: AnnotterColors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
