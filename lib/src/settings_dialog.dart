import 'package:flutter/material.dart';
import 'colors.dart';

class AnnotterSettingsDialog extends StatefulWidget {
  final String detailLevel; // 'compact', 'standard', 'detailed'
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
    return Theme(
      data: ThemeData.dark().copyWith(
        textTheme: const TextTheme().apply(fontFamily: 'sans-serif'),
      ),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 330,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AnnotterColors.slate[900],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AnnotterColors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: AnnotterColors.slate[700]!,
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header with Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded,
                            size: 18, color: AnnotterColors.blue[400]),
                        const SizedBox(width: 8),
                        Text(
                          'Annotter Settings',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AnnotterColors.white,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: widget.onClose,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: AnnotterColors.slate[400]),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Output Detail: Segmented Control
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Output Detail',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AnnotterColors.slate[200],
                      ),
                    ),
                    Text(
                      widget.detailLevel[0].toUpperCase() + widget.detailLevel.substring(1),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AnnotterColors.blue[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AnnotterColors.slate[950],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AnnotterColors.slate[800]!),
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

                // 3. Include Widget Tree: Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Widget Tree',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AnnotterColors.slate[200],
                      ),
                    ),
                    _buildCustomSwitch(
                      value: widget.includeTree,
                      onChanged: widget.onIncludeTreeChanged,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 4. Marker Colour
                Text(
                  'Marker Colour',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AnnotterColors.slate[200],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: AnnotterColors.markerPalette.map((color) {
                    final isSelected =
                        widget.markerColor.toARGB32() == color.toARGB32();
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => widget.onMarkerColorChanged(color),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: isSelected
                              ? Border.all(
                                  color: AnnotterColors.white, width: 2.5)
                              : Border.all(
                                  color: AnnotterColors.slate[700]!, width: 1),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                Divider(color: AnnotterColors.slate[800], height: 1),
                const SizedBox(height: 12),

                // 5. Checkboxes: Clear on Copy, Block Interactions, Replace MCP on Copy
                _buildCheckboxRow(
                  label: 'Clear on copy',
                  value: widget.clearOnCopy,
                  onChanged: widget.onClearOnCopyChanged,
                ),
                const SizedBox(height: 8),
                _buildCheckboxRow(
                  label: 'Block page interactions',
                  value: widget.blockInteractions,
                  onChanged: widget.onBlockInteractionsChanged,
                ),
                const SizedBox(height: 8),
                _buildCheckboxRow(
                  label: 'Replace server notes on copy',
                  value: widget.replaceServerOnCopy,
                  onChanged: widget.onReplaceServerOnCopyChanged,
                ),

                const SizedBox(height: 12),
                Divider(color: AnnotterColors.slate[800], height: 1),
                const SizedBox(height: 12),

                // Snapshot Directory setting
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Snapshot Folder',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AnnotterColors.slate[200],
                      ),
                    ),
                    Text(
                      widget.snapshotDirectory == null || widget.snapshotDirectory!.trim().isEmpty
                          ? 'Default (Downloads)'
                          : 'Custom',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AnnotterColors.blue[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AnnotterColors.slate[950],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AnnotterColors.slate[800]!),
                  ),
                  child: TextFormField(
                    initialValue: widget.snapshotDirectory ?? '',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AnnotterColors.white,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. D:/Projects/snapshots',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: AnnotterColors.slate[500],
                        fontFamily: 'sans-serif',
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      suffixIcon:
                          (widget.snapshotDirectory != null && widget.snapshotDirectory!.trim().isNotEmpty)
                              ? InkWell(
                                  onTap: () => widget.onSnapshotDirectoryChanged?.call(null),
                                  child: Icon(
                                    Icons.clear_rounded,
                                    size: 14,
                                    color: AnnotterColors.slate[400],
                                  ),
                                )
                              : null,
                      suffixIconConstraints:
                          const BoxConstraints(minWidth: 20, minHeight: 20),
                    ),
                    onChanged: (val) {
                      final trimmed = val.trim();
                      widget.onSnapshotDirectoryChanged?.call(trimmed.isEmpty ? null : trimmed);
                    },
                  ),
                ),

                if (widget.onClearSnapshots != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: _isClearing
                        ? null
                        : () async {
                            setState(() {
                              _isClearing = true;
                              _clearFeedback = null;
                            });
                            try {
                              final count = await widget.onClearSnapshots!();
                              if (mounted) {
                                setState(() {
                                  _clearFeedback = 'Cleared $count snapshot(s)';
                                });
                                Future.delayed(const Duration(seconds: 2), () {
                                  if (mounted) {
                                    setState(() => _clearFeedback = null);
                                  }
                                });
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isClearing = false);
                              }
                            }
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _clearFeedback != null
                            ? AnnotterColors.emerald[950]!.withValues(alpha: 0.4)
                            : AnnotterColors.rose[950]!.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _clearFeedback != null
                              ? AnnotterColors.emerald[600]!.withValues(alpha: 0.5)
                              : AnnotterColors.rose[800]!.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _clearFeedback != null
                                ? Icons.check_circle_outline_rounded
                                : Icons.delete_sweep_outlined,
                            size: 14,
                            color: _clearFeedback != null
                                ? AnnotterColors.emerald[300]
                                : AnnotterColors.rose[300],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _clearFeedback ?? (_isClearing ? 'Clearing...' : 'Clear All Snapshots'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _clearFeedback != null
                                  ? AnnotterColors.emerald[300]
                                  : AnnotterColors.rose[300],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                Divider(color: AnnotterColors.slate[800], height: 1),
                const SizedBox(height: 10),

                // 6. Server Connection Status Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Server Connection',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AnnotterColors.slate[300],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isServerConnected == true
                                ? AnnotterColors.emerald[400]
                                : widget.isServerConnected == false
                                    ? AnnotterColors.rose[400]
                                    : AnnotterColors.slate[500],
                            boxShadow: widget.isServerConnected == true
                                ? [
                                    BoxShadow(
                                      color: AnnotterColors.emerald[400]!
                                          .withValues(alpha: 0.6),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isServerConnected == true
                              ? 'Connected'
                              : widget.isServerConnected == false
                                  ? 'Disconnected'
                                  : 'Not Configured',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: widget.isServerConnected == true
                                ? AnnotterColors.emerald[400]
                                : widget.isServerConnected == false
                                    ? AnnotterColors.rose[400]
                                    : AnnotterColors.slate[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailOption(String value, String label) {
    final isSelected = widget.detailLevel == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => widget.onDetailLevelChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AnnotterColors.slate[800] : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color:
                  isSelected ? AnnotterColors.white : AnnotterColors.slate[400],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomSwitch(
      {required bool value, required ValueChanged<bool> onChanged}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? AnnotterColors.blue[600] : AnnotterColors.slate[800],
          border: Border.all(
            color:
                value ? AnnotterColors.blue[400]! : AnnotterColors.slate[700]!,
            width: 1,
          ),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
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
      borderRadius: BorderRadius.circular(6),
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
                color: value
                    ? AnnotterColors.blue[600]
                    : AnnotterColors.slate[950],
                border: Border.all(
                  color: value
                      ? AnnotterColors.blue[400]!
                      : AnnotterColors.slate[700]!,
                  width: 1.2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check,
                      size: 12, color: AnnotterColors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AnnotterColors.slate[300],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
