import 'package:flutter/material.dart';
import 'models.dart';

class AnnotationListSheet extends StatefulWidget {
  final List<AnnotterItem> items;
  final ValueChanged<List<AnnotterItem>> onReorder;
  final ValueChanged<AnnotterItem> onEdit;
  final ValueChanged<AnnotterItem> onDelete;
  final VoidCallback onClearAll;

  const AnnotationListSheet({
    super.key,
    required this.items,
    required this.onReorder,
    required this.onEdit,
    required this.onDelete,
    required this.onClearAll,
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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B), // Slate 800
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
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
                  const Icon(Icons.format_list_numbered, color: Color(0xFF0284C7), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Annotations (${_localItems.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_localItems.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        widget.onClearAll();
                        Navigator.of(context).pop();
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),

          // Body
          if (_localItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text(
                  'No annotations recorded yet.\nUse Inspect, Area, or Pin to add notes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
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
                    // Renumber
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
                      color: const Color(0xFF0F172A), // Slate 900
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        // Drag handle
                        const Icon(Icons.drag_indicator, color: Colors.white38, size: 20),
                        const SizedBox(width: 8),

                        // Number badge
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFF0284C7),
                          child: Text(
                            '${item.number}',
                            style: const TextStyle(
                              color: Colors.white,
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
                              Navigator.of(context).pop();
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
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.mode.name.toUpperCase(),
                                        style: const TextStyle(color: Colors.white54, fontSize: 9),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.note.isEmpty ? 'No feedback entered' : item.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: item.note.isEmpty ? Colors.white30 : Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Actions
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white60, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onEdit(item);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
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
    );
  }
}
