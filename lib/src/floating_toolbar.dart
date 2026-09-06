import 'package:flutter/material.dart';
import 'tokens.dart';
import 'models.dart';

/// Floating Toolbar inspired by Agentations.
/// Vertical pill design with scrollable actions, clamped height (max 60% viewport),
/// perfectly round tool buttons (CircleBorder), and draggable across the screen.
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
    final maxToolbarHeight = size.height * 0.65; // Batasi panjang vertikal

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        color: AnnotterColors.transparent,
        child: Container(
          width: 48,
          constraints: BoxConstraints(maxHeight: maxToolbarHeight),
          decoration: BoxDecoration(
            color: AnnotterColors.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AnnotterColors.border,
              width: 1.0,
            ),
            boxShadow: AnnotterShadows.pill,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Dedicated Drag Handle at the Top
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  final newPos = position + details.delta;
                  final clamped = Offset(
                    newPos.dx.clamp(8.0, size.width - 56.0),
                    newPos.dy.clamp(mediaQuery.padding.top + 8, size.height - 120.0),
                  );
                  onPositionChanged(clamped);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Center(
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 16,
                      color: AnnotterColors.subtleForeground,
                    ),
                  ),
                ),
              ),

              // 2. Scrollable Action Buttons Group (Never overflow or cut off)
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tools Segment (Bulat Sempurna 34x34)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        decoration: BoxDecoration(
                          color: AnnotterColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AnnotterColors.borderSubtle),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildRoundTool(
                              icon: Icons.pan_tool_outlined,
                              tooltip: 'Move',
                              mode: AnnotterMode.move,
                            ),
                            const SizedBox(height: 3),
                            _buildRoundTool(
                              icon: Icons.near_me_outlined,
                              tooltip: 'Select',
                              mode: AnnotterMode.select,
                            ),
                            const SizedBox(height: 3),
                            _buildRoundTool(
                              icon: Icons.touch_app_outlined,
                              tooltip: 'Widget Inspect',
                              mode: AnnotterMode.widget,
                            ),
                            const SizedBox(height: 3),
                            _buildRoundTool(
                              icon: Icons.crop_square_rounded,
                              tooltip: 'Area Box',
                              mode: AnnotterMode.area,
                            ),
                            const SizedBox(height: 3),
                            _buildRoundTool(
                              icon: Icons.adjust_rounded,
                              tooltip: 'Point Pin',
                              mode: AnnotterMode.point,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Prominent Copy Button (Bulat Sempurna 36x36)
                      Tooltip(
                        message: isCopied
                            ? (isServerConnected ? 'Sent to AI Agent' : 'Copied to Clipboard')
                            : (itemCount == 0 ? 'Copy Markdown' : 'Copy ($itemCount notes)'),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onCopy,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCopied ? AnnotterColors.success : AnnotterColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: (isCopied ? AnnotterColors.success : AnnotterColors.primary)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  isCopied ? Icons.check_rounded : Icons.copy_rounded,
                                  color: AnnotterColors.white,
                                  size: 16,
                                ),
                                if (itemCount > 0 && !isCopied)
                                  Positioned(
                                    top: 1,
                                    right: 1,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                                      child: Text(
                                        '$itemCount',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
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
                      ),

                      const SizedBox(height: 6),

                      // Secondary Quick Actions
                      _buildActionCircle(
                        icon: Icons.undo_rounded,
                        tooltip: 'Undo',
                        enabled: canUndo,
                        onTap: canUndo ? onUndo : null,
                      ),
                      const SizedBox(height: 3),
                      _buildActionCircle(
                        icon: Icons.redo_rounded,
                        tooltip: 'Redo',
                        enabled: canRedo,
                        onTap: canRedo ? onRedo : null,
                      ),
                      const SizedBox(height: 3),
                      _buildActionCircle(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Hot Reload & Refresh',
                        enabled: true,
                        onTap: onHotReload,
                      ),
                      const SizedBox(height: 3),
                      _buildActionCircle(
                        icon: isAnimationPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        tooltip: isAnimationPaused ? 'Resume Animation' : 'Freeze Animation',
                        iconColor: isAnimationPaused ? AnnotterColors.amber : null,
                        enabled: true,
                        onTap: onToggleAnimationPause,
                      ),
                      const SizedBox(height: 3),
                      _buildActionCircle(
                        icon: Icons.format_list_numbered_rounded,
                        tooltip: 'Annotation List',
                        badgeCount: itemCount > 0 ? itemCount : null,
                        enabled: true,
                        onTap: onOpenList,
                      ),
                      const SizedBox(height: 3),
                      _buildActionCircle(
                        icon: Icons.settings_outlined,
                        tooltip: 'Settings',
                        enabled: true,
                        onTap: onOpenSettings,
                      ),
                      if (itemCount > 0 && onClearAll != null) ...[
                        const SizedBox(height: 3),
                        _buildActionCircle(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Clear All',
                          iconColor: AnnotterColors.red[300],
                          enabled: true,
                          onTap: onClearAll,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 3. Bottom Divider & Close Button
              Container(
                width: 20,
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AnnotterColors.border,
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Tooltip(
                  message: 'Close Studio',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onExit,
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
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
    final isSelected = this.mode == mode;
    final activeColor = mode == AnnotterMode.move
        ? AnnotterColors.emerald
        : mode == AnnotterMode.select
            ? AnnotterColors.indigo
            : AnnotterColors.primary;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onModeChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? activeColor : AnnotterColors.transparent,
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
        child: Container(
          width: 32,
          height: 32,
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
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AnnotterColors.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                    child: Text(
                      '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AnnotterColors.white,
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
    );
  }
}
