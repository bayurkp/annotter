import 'package:flutter/material.dart';
import 'colors.dart';
import 'models.dart';

/// Bottom dock studio toolbar for Annotter.
/// Features tool segmentation (Move, Select, Widget, Area, Point),
/// quick Copy/Sent feedback CTA, undo/redo, hot-reload, pause animation,
/// annotations list, and settings triggers.
class AnnotterBottomBar extends StatelessWidget {
  final AnnotterMode activeMode;
  final ValueChanged<AnnotterMode> onModeChanged;
  final VoidCallback onExit;
  final VoidCallback onCopy;
  final bool isCopiedFeedback;
  final bool isSyncConnected;
  final int itemCount;
  final bool canUndo;
  final VoidCallback? onUndo;
  final bool canRedo;
  final VoidCallback? onRedo;
  final VoidCallback onHotReload;
  final bool isAnimationPaused;
  final VoidCallback onToggleAnimationPause;
  final VoidCallback onOpenListSheet;
  final VoidCallback onOpenSettings;
  final VoidCallback? onClearAll;

  const AnnotterBottomBar({
    super.key,
    required this.activeMode,
    required this.onModeChanged,
    required this.onExit,
    required this.onCopy,
    required this.isCopiedFeedback,
    required this.isSyncConnected,
    required this.itemCount,
    required this.canUndo,
    required this.onUndo,
    required this.canRedo,
    required this.onRedo,
    required this.onHotReload,
    required this.isAnimationPaused,
    required this.onToggleAnimationPause,
    required this.onOpenListSheet,
    required this.onOpenSettings,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF090D16), // Deep Obsidian
      child: SafeArea(
        top: false,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A), // Slate 900
            border: Border(
              top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12), width: 1.0),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Exit Button (Micro-glass rounded square)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onExit,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 18),
                  ),
                ),

                const SizedBox(width: 8),

                // 2. Cohesive Segmented Control Capsule for Tools
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSegmentTool(
                        icon: Icons.pan_tool_outlined,
                        label: 'Move',
                        mode: AnnotterMode.move,
                      ),
                      const SizedBox(width: 2),
                      _buildSegmentTool(
                        icon: Icons.near_me_outlined,
                        label: 'Select',
                        mode: AnnotterMode.select,
                      ),
                      const SizedBox(width: 2),
                      _buildSegmentTool(
                        icon: Icons.widgets_outlined,
                        label: 'Widget',
                        mode: AnnotterMode.widget,
                      ),
                      const SizedBox(width: 2),
                      _buildSegmentTool(
                        icon: Icons.crop_square_rounded,
                        label: 'Area',
                        mode: AnnotterMode.area,
                      ),
                      const SizedBox(width: 2),
                      _buildSegmentTool(
                        icon: Icons.adjust_rounded,
                        label: 'Point',
                        mode: AnnotterMode.point,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // 3. Copy / Sent CTA Button (Placed prominently before Undo for quick access)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onCopy,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      gradient: isCopiedFeedback
                          ? LinearGradient(
                              colors: [
                                AnnotterColors.emerald[600]!,
                                AnnotterColors.emerald[700]!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                AnnotterColors.blue[600]!,
                                AnnotterColors.blue[700]!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCopiedFeedback
                            ? AnnotterColors.emerald[400]!
                                .withValues(alpha: 0.4)
                            : AnnotterColors.blue[400]!.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isCopiedFeedback
                                  ? AnnotterColors.emerald[600]!
                                  : AnnotterColors.blue[600]!)
                              .withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCopiedFeedback
                              ? Icons.check_rounded
                              : Icons.copy_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCopiedFeedback
                              ? (isSyncConnected
                                  ? 'Sent & Copied'
                                  : 'Copied!')
                              : (itemCount == 0
                                  ? 'Copy'
                                  : 'Copy ($itemCount)'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'sans-serif',
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // 4. Action Buttons Group (Undo, Redo, Hot Reload, Pause, List, Settings, Clear)
                _buildActionSquare(
                  icon: Icons.undo_rounded,
                  tooltip: 'Undo',
                  enabled: canUndo,
                  onTap: canUndo ? onUndo : null,
                ),
                const SizedBox(width: 4),

                _buildActionSquare(
                  icon: Icons.redo_rounded,
                  tooltip: 'Redo',
                  enabled: canRedo,
                  onTap: canRedo ? onRedo : null,
                ),
                const SizedBox(width: 4),

                // Hot Reload & Re-render Button
                _buildActionSquare(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Hot Reload & Refresh',
                  enabled: true,
                  onTap: onHotReload,
                ),
                const SizedBox(width: 4),

                // Freeze Animation Button (timeDilation)
                _buildActionSquare(
                  icon: isAnimationPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  tooltip: isAnimationPaused
                      ? 'Resume Animation'
                      : 'Freeze Animation',
                  iconColor:
                      isAnimationPaused ? AnnotterColors.amber[400] : null,
                  enabled: true,
                  onTap: onToggleAnimationPause,
                ),
                const SizedBox(width: 4),

                _buildActionSquare(
                  icon: Icons.format_list_numbered_rounded,
                  tooltip: 'Annotations List',
                  badgeCount: itemCount > 0 ? itemCount : null,
                  enabled: true,
                  onTap: onOpenListSheet,
                ),
                const SizedBox(width: 4),

                // Settings Gear Button
                _buildActionSquare(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  enabled: true,
                  onTap: onOpenSettings,
                ),
                const SizedBox(width: 4),

                if (itemCount > 0 && onClearAll != null) ...[
                  _buildActionSquare(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Clear All',
                    iconColor: Colors.redAccent.shade100,
                    enabled: true,
                    onTap: onClearAll,
                  ),
                  const SizedBox(width: 4),
                ],

                const SizedBox(width: 4),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentTool({
    required IconData icon,
    required String label,
    required AnnotterMode mode,
  }) {
    final isSelected = activeMode == mode;
    final activeColor = mode == AnnotterMode.move
        ? AnnotterColors.emerald[500]!
        : mode == AnnotterMode.select
            ? AnnotterColors.indigo[500]!
            : AnnotterColors.blue[600]!;

    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => onModeChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildActionSquare({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    VoidCallback? onTap,
    Color? iconColor,
    int? badgeCount,
  }) {
    final effectiveColor =
        enabled ? (iconColor ?? Colors.white70) : Colors.white24;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.06 : 0.02),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 17, color: effectiveColor),
              if (badgeCount != null)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AnnotterColors.blue[600],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
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
