import 'package:flutter/material.dart';
import 'tokens.dart';

/// Full-width Bottom Sheet for Annotter Settings.
/// Matches the exact design language, styling tokens, and swipe gestures of AnnotationSheet & AnnotationListSheet.
class AnnotterSettingsDialog extends StatefulWidget {
  final String detailLevel; // 'compact', 'standard', 'detailed', 'forensic'
  final bool includeTree;
  final Color markerColor;
  final bool clearOnCopy;
  final bool blockInteractions;
  final bool replaceServerOnCopy;
  final bool? isServerConnected;
  final String? snapshotDirectory;
  final ValueChanged<String> onDetailLevelChanged;
  final ValueChanged<bool> onIncludeTreeChanged;
  final ValueChanged<Color> onMarkerColorChanged;
  final ValueChanged<bool> onClearOnCopyChanged;
  final ValueChanged<bool> onBlockInteractionsChanged;
  final ValueChanged<bool> onReplaceServerOnCopyChanged;
  final ValueChanged<String?>? onSnapshotDirectoryChanged;
  final Future<int> Function()? onClearSnapshots;
  final VoidCallback onClose;

  const AnnotterSettingsDialog({
    super.key,
    required this.detailLevel,
    required this.includeTree,
    required this.markerColor,
    required this.clearOnCopy,
    required this.blockInteractions,
    this.replaceServerOnCopy = false,
    this.isServerConnected,
    this.snapshotDirectory,
    required this.onDetailLevelChanged,
    required this.onIncludeTreeChanged,
    required this.onMarkerColorChanged,
    required this.onClearOnCopyChanged,
    required this.onBlockInteractionsChanged,
    required this.onReplaceServerOnCopyChanged,
    this.onSnapshotDirectoryChanged,
    this.onClearSnapshots,
    required this.onClose,
  });

  @override
  State<AnnotterSettingsDialog> createState() => _AnnotterSettingsDialogState();
}

class _AnnotterSettingsDialogState extends State<AnnotterSettingsDialog> {
  bool _isClearing = false;
  String? _clearFeedback;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Theme(
      data: ThemeData.dark().copyWith(
        textTheme: const TextTheme().apply(fontFamily: 'sans-serif'),
      ),
      child: Material(
        color: AnnotterColors.transparent,
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
              widget.onClose();
            }
          },
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: mediaQuery.size.height * 0.82,
              ),
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 8,
                bottom: mediaQuery.padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: AnnotterColors.background,
                borderRadius: AnnotterBorders.radiusSheet,
                border: const Border(
                  top: BorderSide(color: AnnotterColors.border, width: 1.0),
                ),
                boxShadow: AnnotterShadows.sheet,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Drag Handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AnnotterColors.handle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tune_rounded,
                                size: 18, color: AnnotterColors.primary),
                            const SizedBox(width: 8),
                            const Text(
                              'Annotter Settings',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AnnotterColors.foreground,
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AnnotterColors.mutedForeground,
                            backgroundColor: AnnotterColors.surfaceElevated.withValues(alpha: 0.35),
                            side: const BorderSide(
                              color: AnnotterColors.border,
                              width: 1.0,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AnnotterBorders.radiusSm,
                            ),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(32, 32),
                            maximumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: widget.onClose,
                          child: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                    const Divider(color: AnnotterColors.borderSubtle, height: 16),

                    // Output Detail: Segmented Control
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Output Detail',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AnnotterColors.foreground,
                          ),
                        ),
                        Text(
                          widget.detailLevel[0].toUpperCase() +
                              widget.detailLevel.substring(1),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AnnotterColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AnnotterColors.input,
                        borderRadius: AnnotterBorders.radiusSm,
                        border: Border.all(color: AnnotterColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          _buildDetailOption('compact', 'Compact'),
                          _buildDetailOption('standard', 'Standard'),
                          _buildDetailOption('detailed', 'Detailed'),
                          _buildDetailOption('forensic', 'Forensic'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Include Widget Tree: Switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Widget Tree',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AnnotterColors.foreground,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Include hierarchy in export',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AnnotterColors.subtleForeground,
                              ),
                            ),
                          ],
                        ),
                        _buildSwitch(
                          value: widget.includeTree,
                          onChanged: widget.onIncludeTreeChanged,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Marker Accent Color: Swatches
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Marker Color',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AnnotterColors.foreground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: AnnotterColors.markerPalette.map((color) {
                        final isSelected = widget.markerColor.toARGB32() == color.toARGB32();
                        return InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => widget.onMarkerColorChanged(color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(
                                color: isSelected
                                    ? AnnotterColors.white
                                    : AnnotterColors.transparent,
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 14, color: AnnotterColors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: AnnotterColors.borderSubtle, height: 1),
                    const SizedBox(height: 12),

                    // Checkboxes: Clear on Copy, Block Interactions, Replace Server on Copy
                    _buildCheckboxRow(
                      label: 'Clear on copy',
                      value: widget.clearOnCopy,
                      onChanged: widget.onClearOnCopyChanged,
                    ),
                    const SizedBox(height: 8),
                    _buildCheckboxRow(
                      label: 'Block app taps when inspecting',
                      value: widget.blockInteractions,
                      onChanged: widget.onBlockInteractionsChanged,
                    ),
                    const SizedBox(height: 8),
                    _buildCheckboxRow(
                      label: 'Replace server annotations on copy',
                      value: widget.replaceServerOnCopy,
                      onChanged: widget.onReplaceServerOnCopyChanged,
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: AnnotterColors.borderSubtle, height: 1),
                    const SizedBox(height: 12),

                    // Clear Snapshots Button
                    if (widget.onClearSnapshots != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Stored Snapshots',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AnnotterColors.foreground,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'Clear cached PNG screenshots',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AnnotterColors.subtleForeground,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AnnotterColors.error,
                              side: const BorderSide(color: AnnotterColors.error),
                              shape: const RoundedRectangleBorder(
                                borderRadius: AnnotterBorders.radiusSm,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                            icon: _isClearing
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AnnotterColors.error,
                                    ),
                                  )
                                : const Icon(Icons.delete_sweep_outlined, size: 16),
                            label: const Text('Clear', style: TextStyle(fontSize: 11)),
                            onPressed: _isClearing
                                ? null
                                : () async {
                                    setState(() {
                                      _isClearing = true;
                                      _clearFeedback = null;
                                    });
                                    final count = await widget.onClearSnapshots!();
                                    if (mounted) {
                                      setState(() {
                                        _isClearing = false;
                                        _clearFeedback = 'Cleared $count files';
                                      });
                                      Future.delayed(const Duration(seconds: 2), () {
                                        if (mounted) {
                                          setState(() => _clearFeedback = null);
                                        }
                                      });
                                    }
                                  },
                          ),
                        ],
                      ),
                      if (_clearFeedback != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _clearFeedback!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AnnotterColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(color: AnnotterColors.borderSubtle, height: 1),
                      const SizedBox(height: 12),
                    ],

                    // Server Connectivity Status
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 9,
                          color: widget.isServerConnected == true
                              ? AnnotterColors.success
                              : AnnotterColors.subtleForeground,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isServerConnected == null
                              ? 'Server: No URL configured'
                              : widget.isServerConnected == true
                                  ? 'Server: Connected & synced'
                                  : 'Server: Disconnected (reconnecting...)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: widget.isServerConnected == true
                                ? AnnotterColors.success
                                : AnnotterColors.subtleForeground,
                          ),
                        ),
                      ],
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

  Widget _buildDetailOption(String key, String label) {
    final isSelected = widget.detailLevel == key;
    return Expanded(
      child: InkWell(
        borderRadius: AnnotterBorders.radiusSm,
        onTap: () => widget.onDetailLevelChanged(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AnnotterColors.primary : AnnotterColors.transparent,
            borderRadius: AnnotterBorders.radiusSm,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AnnotterColors.onPrimary : AnnotterColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      customBorder: const StadiumBorder(),
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 38,
        height: 22,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: value ? AnnotterColors.primary : AnnotterColors.surfaceElevated,
          border: Border.all(
            color: value ? AnnotterColors.blue[400]! : AnnotterColors.borderSubtle,
            width: 1,
          ),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AnnotterColors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      borderRadius: AnnotterBorders.radiusSm,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: value ? AnnotterColors.primary : AnnotterColors.input,
                border: Border.all(
                  color: value ? AnnotterColors.primary : AnnotterColors.borderSubtle,
                  width: 1.2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 12, color: AnnotterColors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AnnotterColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
