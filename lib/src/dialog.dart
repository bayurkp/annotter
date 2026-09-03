import 'package:flutter/material.dart';
import 'models.dart';

class AnnotationDialog extends StatefulWidget {
  final AnnotterItem item;
  final bool isNew;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final ValueChanged<String> onSave;

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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.note);
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
              color: const Color(0xFF1E293B), // Slate 800
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: const Color(0xFF0284C7).withValues(alpha: 0.4),
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
                      backgroundColor: const Color(0xFF0284C7), // DevTools Blue
                      child: Text(
                        '${widget.item.number}',
                        style: const TextStyle(
                          color: Colors.white,
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
                          color: Colors.white,
                          fontFamily: 'sans-serif',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!widget.isNew)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
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
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, color: Colors.white, fontFamily: 'sans-serif'),
                  decoration: InputDecoration(
                    hintText: 'What needs to be fixed here?',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), fontFamily: 'sans-serif'),
                    filled: true,
                    fillColor: const Color(0xFF0F172A), // Slate 900
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
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
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        side: const BorderSide(color: Color(0x6638BDF8)),
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
                        widget.onSave(_controller.text.trim());
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
