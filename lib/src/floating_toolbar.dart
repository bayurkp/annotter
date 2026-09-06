import 'package:flutter/material.dart';
import 'tokens.dart';
import 'models.dart';

/// Floating Pill Toolbar inspired by Agentations.
/// Ultra-compact, rounded capsule (44px height), draggable across the screen,
/// featuring modern inspection iconography, action tools, and quick close.
class AnnotterFloatingToolbar extends StatelessWidget {
  final Offset position;
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
    required this.position,
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
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        color: AnnotterColors.transparent,
        child: GestureDetector(
          onPanUpdate: (details) {
            final newPos = position + details.delta;
            final clamped = Offset(
              newPos.dx.clamp(8.0, (size.width - 240.0).clamp(8.0, size.width)),
              newPos.dy.clamp(mediaQuery.padding.top + 8, size.height - 56.0),
            );
            onPositionChanged(clamped);
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              color: AnnotterColors.background,
              borderRadius: AnnotterBorders.radiusPill,
              border: Border.all(
                color: AnnotterColors.border,
                width: 1.0,
              ),
              boxShadow: AnnotterShadows.pill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Drag Handle Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Icon(
                    Icons.drag_indicator_rounded,
                    size: 16,
                    color: AnnotterColors.subtleForeground,
                  ),
                ),

                // 2. Tools Segmented Capsule
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AnnotterColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AnnotterColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSegmentTool(
                        icon: Icons.pan_tool_outlined,
                        tooltip: 'Move',
                        mode: AnnotterMode.move,
                      ),
                      const SizedBox(width: 2),
                      _buildSegmentTool(
                        icon: Icons.near_me_outlined,
                        tooltip: 'Select',
                        mode: AnnotterMode.select,
                      ),
                      const SizedBox(width: 2),
                      _buildSegmentTool(
                        icon: Icons.touch_app_outlined,
                        tooltip: 'Widget Inspect',
                        mode: AnnotterMode.widget,
                      ),
                      const SizedBox(width: 2),
                      _buildSegmentTool(
                        icon: Icons.crop_square_rounded,
                        tooltip: 'Area Box',
                        mode: AnnotterMode.area,
                      ),
                      const SizedBox(width: 2),
                      _buildSegmentTool(
                        icon: Icons.adjust_rounded,
                        tooltip: 'Point Pin',
                        mode: AnnotterMode.point,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                // 3. Prominent Copy/Sent Action CTA
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onCopy,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: isCopied ? AnnotterColors.success : AnnotterColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isCopied ? AnnotterColors.success : AnnotterColors.primary)
                              .withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCopied ? Icons.check_rounded : Icons.copy_rounded,
                          color: AnnotterColors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCopied
                              ? (isServerConnected ? 'Sent' : 'Copied!')
                              : (itemCount == 0 ? 'Copy' : 'Copy ($itemCount)'),
                          style: const TextStyle(
                            color: AnnotterColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // 4. Quick Actions Group
                _buildActionItem(
                  icon: Icons.undo_rounded,
                  tooltip: 'Undo',
                  enabled: canUndo,
                  onTap: canUndo ? onUndo : null,
                ),
                _buildActionItem(
                  icon: Icons.redo_rounded,
                  tooltip: 'Redo',
                  enabled: canRedo,
                  onTap: canRedo ? onRedo : null,
                ),
                _buildActionItem(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Hot Reload & Refresh',
                  enabled: true,
                  onTap: onHotReload,
                ),
                _buildActionItem(
                  icon: isAnimationPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  tooltip: isAnimationPaused ? 'Resume Animation' : 'Freeze Animation',
                  iconColor: isAnimationPaused ? AnnotterColors.amber : null,
                  enabled: true,
                  onTap: onToggleAnimationPause,
                ),
                _buildActionItem(
                  icon: Icons.format_list_numbered_rounded,
                  tooltip: 'Annotation List',
                  badgeCount: itemCount > 0 ? itemCount : null,
                  enabled: true,
                  onTap: onOpenList,
                ),
                _buildActionItem(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  enabled: true,
                  onTap: onOpenSettings,
                ),
                if (itemCount > 0 && onClearAll != null)
                  _buildActionItem(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Clear All',
                    iconColor: AnnotterColors.red[300],
                    enabled: true,
                    onTap: onClearAll,
                  ),

                // 5. Vertical Divider
                Container(
                  height: 18,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: AnnotterColors.border,
                ),

                // 6. Close / Collapse Button (back to idle FAB)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onExit,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 17,
                      color: AnnotterColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentTool({
    required IconData icon,
    required String tooltip,
    required AnnotterMode mode,
  }) {
    final isSelected = this.mode == mode;
    final activeColor = mode == AnnotterMode.move
        ? AnnotterColors.emerald
        : mode == AnnotterMode.select
            ? AnnotterColors.indigo
            : AnnotterColors.primary;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onModeChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : AnnotterColors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? AnnotterColors.white : AnnotterColors.mutedForeground,
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem({
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
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 16, color: effectiveColor),
              if (badgeCount != null)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: AnnotterColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: AnnotterColors.white,
                        fontSize: 7.5,
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
