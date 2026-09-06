import 'package:flutter/material.dart';
import 'tokens.dart';
import 'models.dart';

/// Compact Floating Toolbar inspired by Agentations.
/// Ultra-responsive, fixed-height vertical capsule (all essential tools visible without scrolling),
/// isolated ValueNotifier/Stateful drag for 60fps zero-lag movement, and perfectly round buttons.
class AnnotterFloatingToolbar extends StatefulWidget {
  final Offset initialPosition;
  final ValueChanged<Offset> onPositionChanged;
  final AnnotterMode mode;
  final ValueChanged<AnnotterMode> onModeChanged;
  final VoidCallback onExit;
  final VoidCallback onCopy;
  final bool isCopied;
  final bool isServerConnected;
  final int itemCount;
  final bool canUndo;
  final VoidCallback? onUndo;
  final bool canRedo;
  final VoidCallback? onRedo;
  final VoidCallback onHotReload;
  final bool isAnimationPaused;
  final VoidCallback onToggleAnimationPause;
  final VoidCallback onOpenList;
  final VoidCallback onOpenSettings;
  final VoidCallback? onClearAll;

  const AnnotterFloatingToolbar({
    super.key,
    required this.initialPosition,
    required this.onPositionChanged,
    required this.mode,
    required this.onModeChanged,
    required this.onExit,
    required this.onCopy,
    required this.isCopied,
    required this.isServerConnected,
    required this.itemCount,
    required this.canUndo,
    required this.onUndo,
    required this.canRedo,
    required this.onRedo,
    required this.onHotReload,
    required this.isAnimationPaused,
    required this.onToggleAnimationPause,
    required this.onOpenList,
    required this.onOpenSettings,
    this.onClearAll,
  });

  @override
  State<AnnotterFloatingToolbar> createState() => _AnnotterFloatingToolbarState();
}

class _AnnotterFloatingToolbarState extends State<AnnotterFloatingToolbar> {
  late Offset _pos;

  @override
  void initState() {
    super.initState();
    _pos = widget.initialPosition;
  }

  @override
  void didUpdateWidget(covariant AnnotterFloatingToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external position changes if necessary
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
        child: Container(
          width: 44,
          decoration: BoxDecoration(
            color: AnnotterColors.background,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AnnotterColors.border,
              width: 1.0,
            ),
            boxShadow: AnnotterShadows.pill,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag Handle Header (High-performance 60fps dragging)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  final nextPos = _pos + details.delta;
                  final clamped = Offset(
                    nextPos.dx.clamp(6.0, size.width - 50.0),
                    nextPos.dy.clamp(mediaQuery.padding.top + 6, size.height - 360.0),
                  );
                  setState(() => _pos = clamped);
                },
                onPanEnd: (_) {
                  widget.onPositionChanged(_pos);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: const Center(
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 15,
                      color: AnnotterColors.subtleForeground,
                    ),
                  ),
                ),
              ),

              // 2. Selection Tools Capsule (Sleek, Compact & Complete)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: AnnotterColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AnnotterColors.borderSubtle),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Play / Pause Animation (Warna konsisten netral)
                    Tooltip(
                      message: widget.isAnimationPaused ? 'Resume Animation' : 'Freeze Animation',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: widget.onToggleAnimationPause,
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: Icon(
                            widget.isAnimationPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 17,
                            color: AnnotterColors.foreground,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildRoundTool(
                      icon: Icons.pan_tool_outlined,
                      tooltip: 'Move',
                      mode: AnnotterMode.move,
                    ),
                    const SizedBox(height: 2),
                    _buildRoundTool(
                      icon: Icons.near_me_outlined,
                      tooltip: 'Select',
                      mode: AnnotterMode.select,
                    ),
                    const SizedBox(height: 2),
                    _buildRoundTool(
                      icon: Icons.touch_app_outlined,
                      tooltip: 'Widget Inspect',
                      mode: AnnotterMode.widget,
                    ),
                    const SizedBox(height: 2),
                    _buildRoundTool(
                      icon: Icons.crop_square_rounded,
                      tooltip: 'Area Box',
                      mode: AnnotterMode.area,
                    ),
                    const SizedBox(height: 2),
                    _buildRoundTool(
                      icon: Icons.adjust_rounded,
                      tooltip: 'Point Pin',
                      mode: AnnotterMode.point,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 5),

              // 3. Prominent Copy CTA Button (32x32 circle)
              Tooltip(
                message: widget.isCopied
                    ? (widget.isServerConnected ? 'Sent to AI Agent' : 'Copied to Clipboard')
                    : (widget.itemCount == 0 ? 'Copy Markdown' : 'Copy (${widget.itemCount} notes)'),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onCopy,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isCopied ? AnnotterColors.success : AnnotterColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isCopied ? AnnotterColors.success : AnnotterColors.primary)
                              .withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          widget.isCopied ? Icons.check_rounded : Icons.copy_rounded,
                          color: AnnotterColors.white,
                          size: 15,
                        ),
                        if (widget.itemCount > 0 && !widget.isCopied)
                          Positioned(
                            top: 1,
                            right: 1,
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 11, minHeight: 11),
                              child: Text(
                                '${widget.itemCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
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

              const SizedBox(height: 4),

              // 4. Quick Actions Group (Undo, List, Settings, Clear)
              _buildActionCircle(
                icon: Icons.undo_rounded,
                tooltip: 'Undo',
                enabled: widget.canUndo,
                onTap: widget.canUndo ? widget.onUndo : null,
              ),
              const SizedBox(height: 2),
              _buildActionCircle(
                icon: Icons.format_list_numbered_rounded,
                tooltip: 'Annotation List',
                badgeCount: widget.itemCount > 0 ? widget.itemCount : null,
                enabled: true,
                onTap: widget.onOpenList,
              ),
              const SizedBox(height: 2),
              _buildActionCircle(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                enabled: true,
                onTap: widget.onOpenSettings,
              ),
              if (widget.itemCount > 0 && widget.onClearAll != null) ...[
                const SizedBox(height: 2),
                _buildActionCircle(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Clear All',
                  iconColor: AnnotterColors.red[300],
                  enabled: true,
                  onTap: widget.onClearAll,
                ),
              ],

              // 5. Bottom Divider & Close Button
              Container(
                width: 18,
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AnnotterColors.border,
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Tooltip(
                  message: 'Close Studio',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onExit,
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: AnnotterColors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundTool({
    required IconData icon,
    required String tooltip,
    required AnnotterMode mode,
  }) {
    final isSelected = widget.mode == mode;
    final activeColor = mode == AnnotterMode.move
        ? AnnotterColors.emerald
        : mode == AnnotterMode.select
            ? AnnotterColors.indigo
            : AnnotterColors.primary;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => widget.onModeChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? activeColor : AnnotterColors.transparent,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 15,
            color: isSelected ? AnnotterColors.white : AnnotterColors.mutedForeground,
          ),
        ),
      ),
    );
  }

  Widget _buildActionCircle({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    VoidCallback? onTap,
    Color? iconColor,
    int? badgeCount,
  }) {
    final effectiveColor = enabled
        ? (iconColor ?? AnnotterColors.foreground)
        : AnnotterColors.subtleForeground.withValues(alpha: 0.4);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 15, color: effectiveColor),
              if (badgeCount != null)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AnnotterColors.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 9, minHeight: 9),
                    child: Text(
                      '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AnnotterColors.white,
                        fontSize: 6.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
