import 'package:flutter/material.dart';
import 'tokens.dart';
import 'models.dart';

/// Bottom Sheet modal for creating and editing annotations.
/// Automatically glides smoothly above the virtual keyboard via [MediaQuery.viewInsets.bottom].
class AnnotationSheet extends StatefulWidget {
  final AnnotterItem item;
  final bool isNew;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final void Function(String note, String? intent, String? severity) onSave;

  const AnnotationSheet({
    super.key,
    required this.item,
    this.isNew = false,
    required this.onDelete,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<AnnotationSheet> createState() => _AnnotationSheetState();
}

class _AnnotationSheetState extends State<AnnotationSheet> {
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
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Theme(
      data: ThemeData.dark().copyWith(
        textTheme: const TextTheme().apply(fontFamily: 'sans-serif'),
      ),
      child: Material(
        color: AnnotterColors.transparent,
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            // Swipe down gesture to dismiss
            if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
              widget.onCancel();
            }
          },
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 540),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: bottomInset > 0 ? bottomInset + 12 : mediaQuery.padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: AnnotterColors.background,
                borderRadius: AnnotterBorders.radiusSheet,
                border: Border.all(
                  color: AnnotterColors.border,
                  width: 1.0,
                ),
                boxShadow: AnnotterShadows.sheet,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Drag Handle (Swipe to dismiss indicator)
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

                    // Header: Number Badge, Widget Name, Mode Tag, and Delete button
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AnnotterColors.primary,
                          child: Text(
                            '${widget.item.number}',
                            style: const TextStyle(
                              color: AnnotterColors.onPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.item.widgetName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AnnotterColors.foreground,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AnnotterColors.surfaceElevated,
                                      borderRadius: AnnotterBorders.radiusSm,
                                    ),
                                    child: Text(
                                      widget.item.mode.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AnnotterColors.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.item.screenName.isNotEmpty)
                                Text(
                                  widget.item.screenName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AnnotterColors.subtleForeground,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!widget.isNew)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AnnotterColors.error, size: 20),
                            tooltip: 'Delete annotation',
                            onPressed: widget.onDelete,
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AnnotterColors.mutedForeground, size: 20),
                          tooltip: 'Close',
                          onPressed: widget.onCancel,
                        ),
                      ],
                    ),

                    // Context preview (Selected Text or Source File Location)
                    if (widget.item.selectedText != null &&
                        widget.item.selectedText!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AnnotterColors.surface,
                          borderRadius: AnnotterBorders.radiusSm,
                        ),
                        child: Text(
                          '"${widget.item.selectedText}"',
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AnnotterColors.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Intent Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _intents.map((intent) {
                        final isSelected = _selectedIntent == intent.$1;
                        return InkWell(
                          borderRadius: AnnotterBorders.radiusSm,
                          onTap: () {
                            setState(() {
                              _selectedIntent = isSelected ? null : intent.$1;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? intent.$3[600] : AnnotterColors.surface,
                              borderRadius: AnnotterBorders.radiusSm,
                              border: Border.all(
                                color: isSelected ? intent.$3[400]! : AnnotterColors.borderSubtle,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              intent.$2,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AnnotterColors.white : AnnotterColors.mutedForeground,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 8),

                    // Severity Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _severities.map((sev) {
                        final isSelected = _selectedSeverity == sev.$1;
                        return InkWell(
                          borderRadius: AnnotterBorders.radiusSm,
                          onTap: () {
                            setState(() {
                              _selectedSeverity = isSelected ? null : sev.$1;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelected ? sev.$3[600] : AnnotterColors.surface,
                              borderRadius: AnnotterBorders.radiusSm,
                              border: Border.all(
                                color: isSelected ? sev.$3[400]! : AnnotterColors.borderSubtle,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              sev.$2,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AnnotterColors.white : AnnotterColors.subtleForeground,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 10),

                    // Feedback Note Input TextField
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      maxLines: bottomInset > 0 ? 2 : 3,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AnnotterColors.foreground,
                      ),
                      decoration: InputDecoration(
                        hintText: 'What needs to be fixed or modified here?',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: AnnotterColors.subtleForeground,
                        ),
                        filled: true,
                        fillColor: AnnotterColors.input,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: AnnotterBorders.radiusMd,
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AnnotterBorders.radiusMd,
                          borderSide: const BorderSide(
                            color: AnnotterColors.ring,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Action Buttons Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AnnotterColors.mutedForeground,
                            backgroundColor: AnnotterColors.surface,
                            side: const BorderSide(color: AnnotterColors.borderSubtle),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AnnotterBorders.radiusSm,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: widget.onCancel,
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AnnotterColors.primary,
                            foregroundColor: AnnotterColors.onPrimary,
                            elevation: 0,
                            side: BorderSide(color: AnnotterColors.blue[400]!),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AnnotterBorders.radiusSm,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text(
                            'Save Note',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            widget.onSave(
                              _controller.text.trim(),
                              _selectedIntent,
                              _selectedSeverity,
                            );
                          },
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
}
