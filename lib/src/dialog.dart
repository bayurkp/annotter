import 'package:flutter/material.dart';
import 'colors.dart';
import 'models.dart';

class AnnotationDialog extends StatefulWidget {
  final AnnotterItem item;
  final bool isNew;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final void Function(String note, String? intent, String? severity) onSave;

  const AnnotationDialog({
    super.key,
    required this.item,
    this.isNew = false,
    required this.onDelete,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<AnnotationDialog> createState() => _AnnotationDialogState();
}

class _AnnotationDialogState extends State<AnnotationDialog> {
  late final TextEditingController _controller;
  String? _selectedIntent;
  String? _selectedSeverity;

  static const _intents = [
    ('fix', 'Fix', AnnotterColors.rose),
    ('style', 'Style', AnnotterColors.sky),
    ('change', 'Change', AnnotterColors.amber),
    ('question', 'Question', AnnotterColors.indigo),
  ];

  static const _severities = [
    ('blocking', 'Blocking', AnnotterColors.red),
    ('important', 'Important', AnnotterColors.orange),
    ('suggestion', 'Suggestion', AnnotterColors.slate),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.note);
    _selectedIntent = widget.item.intent;
    _selectedSeverity = widget.item.severity;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            width: 360,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AnnotterColors.slate[900],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AnnotterColors.black.withValues(alpha: 0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: AnnotterColors.sky[600]!.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: AnnotterColors.sky[600],
                      child: Text(
                        '${widget.item.number}',
                        style: const TextStyle(
                          color: AnnotterColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.item.widgetName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AnnotterColors.white,
                          fontFamily: 'sans-serif',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!widget.isNew)
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: AnnotterColors.rose[400], size: 20),
                        onPressed: widget.onDelete,
                      ),
                  ],
                ),
                if (widget.item.hierarchy.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.item.hierarchy.reversed.take(3).map((w) => '<$w>').join(' '),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AnnotterColors.slate[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),

                // Intent Pills
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _intents.map((intent) {
                    final isSelected = _selectedIntent == intent.$1;
                    return InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        setState(() {
                          _selectedIntent = isSelected ? null : intent.$1;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? intent.$3[600] : AnnotterColors.slate[800],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? intent.$3[400]! : AnnotterColors.slate[700]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          intent.$2,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AnnotterColors.white : AnnotterColors.slate[300],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 8),

                // Severity Pills
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _severities.map((sev) {
                    final isSelected = _selectedSeverity == sev.$1;
                    return InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        setState(() {
                          _selectedSeverity = isSelected ? null : sev.$1;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected ? sev.$3[600] : AnnotterColors.slate[800],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? sev.$3[400]! : AnnotterColors.slate[700]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          sev.$2,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AnnotterColors.white : AnnotterColors.slate[400],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, color: AnnotterColors.white, fontFamily: 'sans-serif'),
                  decoration: InputDecoration(
                    hintText: 'What needs to be fixed here?',
                    hintStyle: TextStyle(fontSize: 12, color: AnnotterColors.slate[500], fontFamily: 'sans-serif'),
                    filled: true,
                    fillColor: AnnotterColors.slate[950],
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AnnotterColors.sky[500]!, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AnnotterColors.slate[300],
                        backgroundColor: AnnotterColors.white.withValues(alpha: 0.06),
                        side: BorderSide(color: AnnotterColors.white.withValues(alpha: 0.12)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: widget.onCancel,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'sans-serif'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AnnotterColors.sky[600],
                        foregroundColor: AnnotterColors.white,
                        elevation: 0,
                        side: BorderSide(color: AnnotterColors.sky[400]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text(
                        'Save Note',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'sans-serif'),
                      ),
                      onPressed: () {
                        widget.onSave(_controller.text.trim(), _selectedIntent, _selectedSeverity);
                      },
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
}
