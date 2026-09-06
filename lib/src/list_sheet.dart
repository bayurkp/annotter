import 'package:flutter/material.dart';
import 'tokens.dart';
import 'models.dart';

/// Full-width Bottom Sheet displaying the list of all recorded annotations.
/// Matches the exact design language, styling tokens, and swipe gestures of AnnotationSheet.
class AnnotationListSheet extends StatefulWidget {
  final List<AnnotterItem> items;
  final ValueChanged<List<AnnotterItem>> onReorder;
  final ValueChanged<AnnotterItem> onEdit;
  final ValueChanged<AnnotterItem> onDelete;
  final VoidCallback onClearAll;
  final VoidCallback onClose;

  const AnnotationListSheet({
    super.key,
    required this.items,
    required this.onReorder,
    required this.onEdit,
    required this.onDelete,
    required this.onClearAll,
    required this.onClose,
  });

  @override
  State<AnnotationListSheet> createState() => _AnnotationListSheetState();
}

class _AnnotationListSheetState extends State<AnnotationListSheet> {
  late List<AnnotterItem> _localItems;

  @override
  void initState() {
    super.initState();
    _localItems = List.from(widget.items);
  }

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
                maxHeight: mediaQuery.size.height * 0.75,
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      if (details.primaryDelta != null && details.primaryDelta! > 4) {
                        widget.onClose();
                      }
                    },
                    child: Center(
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
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.format_list_numbered_rounded,
                              color: AnnotterColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Annotations (${_localItems.length})',
                            style: const TextStyle(
                              color: AnnotterColors.foreground,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_localItems.isNotEmpty)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AnnotterColors.error,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 32),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                widget.onClearAll();
                                widget.onClose();
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: AnnotterColors.mutedForeground, size: 20),
                            onPressed: widget.onClose,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: AnnotterColors.borderSubtle, height: 16),

                  // Body Items
                  if (_localItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          'No annotations recorded yet.\nTap on any UI element to add feedback.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AnnotterColors.subtleForeground,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        itemCount: _localItems.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _localItems.removeAt(oldIndex);
                            _localItems.insert(newIndex, item);
                            for (int i = 0; i < _localItems.length; i++) {
                              _localItems[i].number = i + 1;
                            }
                          });
                          widget.onReorder(_localItems);
                        },
                        itemBuilder: (context, index) {
                          final item = _localItems[index];
                          return Container(
                            key: ValueKey(item.id),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AnnotterColors.surface,
                              borderRadius: AnnotterBorders.radiusMd,
                              border: Border.all(color: AnnotterColors.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                // Drag handle
                                const Icon(Icons.drag_indicator_rounded,
                                    color: AnnotterColors.subtleForeground, size: 18),
                                const SizedBox(width: 8),

                                // Number badge
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AnnotterColors.primary,
                                  child: Text(
                                    '${item.number}',
                                    style: const TextStyle(
                                      color: AnnotterColors.onPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Title & note preview
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      widget.onClose();
                                      widget.onEdit(item);
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                item.widgetName,
                                                style: const TextStyle(
                                                  color: AnnotterColors.foreground,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AnnotterColors.surfaceElevated,
                                                borderRadius: AnnotterBorders.radiusSm,
                                              ),
                                              child: Text(
                                                item.mode.name.toUpperCase(),
                                                style: const TextStyle(
                                                  color: AnnotterColors.mutedForeground,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.note.isEmpty
                                              ? 'No feedback entered'
                                              : item.note,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: item.note.isEmpty
                                                ? AnnotterColors.subtleForeground
                                                : AnnotterColors.mutedForeground,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Actions
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: AnnotterColors.mutedForeground, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () {
                                    widget.onClose();
                                    widget.onEdit(item);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: AnnotterColors.error, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () {
                                    setState(() {
                                      _localItems.removeAt(index);
                                      for (int i = 0; i < _localItems.length; i++) {
                                        _localItems[i].number = i + 1;
                                      }
                                    });
                                    widget.onDelete(item);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
