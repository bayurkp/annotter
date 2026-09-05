import 'package:flutter/material.dart';
import 'colors.dart';

/// Draggable Floating Action Button that triggers Annotter activation when idle.
class AnnotterIdleFab extends StatelessWidget {
  final Offset position;
  final ValueChanged<Offset> onPositionChanged;
  final VoidCallback onTap;
  final int badgeCount;

  const AnnotterIdleFab({
    super.key,
    required this.position,
    required this.onPositionChanged,
    required this.onTap,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onPanUpdate: (details) {
            final newPos = position + details.delta;
            final clamped = Offset(
              newPos.dx.clamp(10.0, size.width - 60.0),
              newPos.dy.clamp(mediaQuery.padding.top + 10, size.height - 70.0),
            );
            onPositionChanged(clamped);
          },
          child: Material(
            elevation: 8,
            shape: const CircleBorder(),
            color: AnnotterColors.blue[600], // Royal Blue
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.edit_note, color: Colors.white, size: 26),
                    if (badgeCount > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'sans-serif',
                              decoration: TextDecoration.none,
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
