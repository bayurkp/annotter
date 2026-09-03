import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'models.dart';
import 'canvas.dart';
import 'dialog.dart';
import 'exporter.dart';
import 'inspector.dart';
import 'list_sheet.dart';

/// The root wrapper for Annotter.
/// Wraps your application to provide in-app UI inspection and annotation.
class Annotter extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const Annotter({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<Annotter> createState() => _AnnotterState();
}

class _AnnotterState extends State<Annotter> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final GlobalKey _appChildKey = GlobalKey();

  bool _isActive = false;
  AnnotterMode _activeMode = AnnotterMode.inspect;
  List<AnnotterItem> _items = [];

  // Undo / Redo History Stacks
  final List<List<AnnotterItem>> _undoStack = [];
  final List<List<AnnotterItem>> _redoStack = [];

  Offset _fabPosition = const Offset(20, 120);
  double _currentScrollOffset = 0.0;

  AnnotterItem? _activeDialogItem;
  bool _isCreatingItem = false;
  bool _showListSheet = false;
  String _currentScreenName = 'HomeScreen';

  String get _activeScreenName {
    final appElement = _appChildKey.currentContext as Element?;
    if (appElement != null) {
      final detected = WidgetInspectorHelper.detectActiveScreen(appElement);
      if (detected != null && detected.isNotEmpty) {
        return detected;
      }
    }
    return _currentScreenName;
  }

  void _saveSnapshot() {
    _undoStack.add(_items.map((i) => i.copy()).toList());
    _redoStack.clear();
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0);
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_items.map((i) => i.copy()).toList());
    setState(() {
      _items = _undoStack.removeLast();
      _renumberItems();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_items.map((i) => i.copy()).toList());
    setState(() {
      _items = _redoStack.removeLast();
      _renumberItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || !widget.enabled) {
      return widget.child;
    }

    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) {
              if (!_isActive) {
                // Inactive: Fullscreen app + Draggable FAB
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    KeyedSubtree(key: _appChildKey, child: widget.child),
                    _buildIdleFab(mediaQuery, size),
                  ],
                );
              }

              // Active: Full-width Ultra-Thin Bottom Dock Studio
              return Material(
                color: Colors.transparent,
                textStyle: const TextStyle(decoration: TextDecoration.none, fontFamily: 'sans-serif'),
                child: Container(
                  color: const Color(0xFF0B0F19), // Deep studio backdrop
                  child: SafeArea(
                    top: true,
                    bottom: false,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            // Proportional Scaled App Viewport
                            Expanded(
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: Container(
                                    width: size.width,
                                    height: size.height,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _activeMode == AnnotterMode.navigate
                                            ? const Color(0xFF10B981) // Green in navigate
                                            : const Color(0xFF0284C7), // DevTools Blue in annotate
                                        width: 2.0,
                                      ),
                                    ),
                                    child: RepaintBoundary(
                                      key: _repaintBoundaryKey,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Reactive Scroll & Navigation Listener
                                          NotificationListener<Notification>(
                                            onNotification: (notification) {
                                              if (notification is ScrollNotification) {
                                                if (notification.metrics.axis == Axis.vertical) {
                                                  setState(() {
                                                    _currentScrollOffset = notification.metrics.pixels;
                                                  });
                                                }
                                              } else if (notification is NavigationNotification) {
                                                setState(() {});
                                              }
                                              return false;
                                            },
                                            child: KeyedSubtree(key: _appChildKey, child: widget.child),
                                          ),

                                          AnnotterCanvas(
                                            items: _items,
                                            activeMode: _activeMode,
                                            currentScrollOffset: _currentScrollOffset,
                                            onRequestCreate: (item, screenName) {
                                              _saveSnapshot();
                                              setState(() {
                                                if (screenName != null) _currentScreenName = screenName;
                                                _activeDialogItem = item;
                                                _isCreatingItem = true;
                                              });
                                            },
                                            onRequestEdit: (item) {
                                              setState(() {
                                                _activeDialogItem = item;
                                                _isCreatingItem = false;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Ultra-Thin Full-Width Bottom Bar
                            _buildSlimBottomBar(context),
                          ],
                        ),

                        // Inline Modal Note Dialog
                        if (_activeDialogItem != null)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.65),
                              alignment: Alignment.center,
                              child: SingleChildScrollView(
                                child: AnnotationDialog(
                                  item: _activeDialogItem!,
                                  isNew: _isCreatingItem,
                                  onCancel: () => setState(() => _activeDialogItem = null),
                                  onDelete: () {
                                    _saveSnapshot();
                                    setState(() {
                                      final deleteId = _activeDialogItem!.id;
                                      _items.removeWhere((i) => i.id == deleteId);
                                      _renumberItems();
                                      _activeDialogItem = null;
                                    });
                                  },
                                  onSave: (note) {
                                    _saveSnapshot();
                                    setState(() {
                                      _activeDialogItem!.note = note;
                                      if (_isCreatingItem) {
                                        _items.add(_activeDialogItem!);
                                      }
                                      _activeDialogItem = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),

                        // Inline Modal Annotation List Sheet
                        if (_showListSheet)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.65),
                              alignment: Alignment.bottomCenter,
                              child: AnnotationListSheet(
                                items: _items,
                                onClose: () => setState(() => _showListSheet = false),
                                onReorder: (newItems) {
                                  _saveSnapshot();
                                  setState(() {
                                    _items = newItems;
                                    _renumberItems();
                                  });
                                },
                                onEdit: (item) {
                                  setState(() {
                                    _showListSheet = false;
                                    _activeDialogItem = item;
                                    _isCreatingItem = false;
                                  });
                                },
                                onDelete: (item) {
                                  _saveSnapshot();
                                  setState(() {
                                    final deleteId = item.id;
                                    _items.removeWhere((i) => i.id == deleteId);
                                    _renumberItems();
                                  });
                                },
                                onClearAll: () {
                                  _saveSnapshot();
                                  setState(() => _items.clear());
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Ultra-Thin Full-Width Bottom Bar Dock (No rounded corners, exactly 46px)
  Widget _buildSlimBottomBar(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A), // Slate 900
      child: SafeArea(
        top: false,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Exit Studio
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                  tooltip: 'Exit Studio',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 46),
                  onPressed: () => setState(() => _isActive = false),
                ),

                const SizedBox(
                  height: 20,
                  child: VerticalDivider(color: Colors.white12, width: 8),
                ),

                // Navigate Tool
                _buildCompactTool(
                  icon: Icons.pan_tool_outlined,
                  label: 'Nav',
                  mode: AnnotterMode.navigate,
                ),

                // Inspect Tool
                _buildCompactTool(
                  icon: Icons.touch_app_outlined,
                  label: 'Inspect',
                  mode: AnnotterMode.inspect,
                ),

                // Area Tool
                _buildCompactTool(
                  icon: Icons.crop_square_outlined,
                  label: 'Area',
                  mode: AnnotterMode.rectangle,
                ),

                // Pin Tool
                _buildCompactTool(
                  icon: Icons.pin_drop_outlined,
                  label: 'Pin',
                  mode: AnnotterMode.pin,
                ),

                const SizedBox(
                  height: 20,
                  child: VerticalDivider(color: Colors.white12, width: 8),
                ),

                // Undo
                IconButton(
                  icon: Icon(
                    Icons.undo,
                    size: 19,
                    color: _undoStack.isEmpty ? Colors.white24 : Colors.white70,
                  ),
                  tooltip: 'Undo',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 46),
                  onPressed: _undoStack.isEmpty ? null : _undo,
                ),

                // Redo
                IconButton(
                  icon: Icon(
                    Icons.redo,
                    size: 19,
                    color: _redoStack.isEmpty ? Colors.white24 : Colors.white70,
                  ),
                  tooltip: 'Redo',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 46),
                  onPressed: _redoStack.isEmpty ? null : _redo,
                ),

                // Notes List
                IconButton(
                  icon: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.format_list_numbered, size: 20, color: Colors.white70),
                      if (_items.isNotEmpty)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0284C7),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${_items.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'Annotations List',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 46),
                  onPressed: () => setState(() => _showListSheet = true),
                ),

                // Clear All
                if (_items.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20),
                    tooltip: 'Clear All',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 46),
                    onPressed: () {
                      _saveSnapshot();
                      setState(() => _items.clear());
                    },
                  ),

                const SizedBox(width: 6),

                // Copy Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(60, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.copy_all, size: 15),
                    label: Text(
                      _items.isEmpty ? 'Copy' : 'Copy (${_items.length})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'sans-serif'),
                    ),
                    onPressed: _copyNotes,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTool({
    required IconData icon,
    required String label,
    required AnnotterMode mode,
  }) {
    final isSelected = _activeMode == mode;
    final activeColor = mode == AnnotterMode.navigate ? const Color(0xFF10B981) : const Color(0xFF0284C7);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _activeMode = mode),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 10 : 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected ? Border.all(color: activeColor, width: 1.2) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? activeColor : Colors.white60,
            ),
            // Only show text label for the active tool to keep it ultra compact
            if (isSelected) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'sans-serif',
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Draggable FAB for idle trigger
  Widget _buildIdleFab(MediaQueryData mediaQuery, Size size) {
    return Positioned(
      left: _fabPosition.dx,
      top: _fabPosition.dy,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _fabPosition += details.delta;
              _fabPosition = Offset(
                _fabPosition.dx.clamp(10.0, size.width - 60.0),
                _fabPosition.dy.clamp(mediaQuery.padding.top + 10, size.height - 70.0),
              );
            });
          },
          child: Material(
            elevation: 8,
            shape: const CircleBorder(),
            color: const Color(0xFF0284C7), // DevTools Blue
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _isActive = true),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.edit_note, color: Colors.white, size: 26),
                    if (_items.isNotEmpty)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_items.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'sans-serif',
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
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

  void _renumberItems() {
    for (int i = 0; i < _items.length; i++) {
      _items[i].number = i + 1;
    }
  }

  void _copyNotes() async {
    final size = MediaQuery.of(context).size;

    // 1. Auto-capture current visible viewport screenshot
    String? savedScreenshotPath;
    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final pngBytes = byteData.buffer.asUint8List();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filename = 'annotter_$timestamp.png';

          File? file;
          if (Platform.isAndroid) {
            final downloadDir = Directory('/sdcard/Download');
            if (await downloadDir.exists()) {
              file = File('${downloadDir.path}/$filename');
            }
          }
          file ??= File('${Directory.systemTemp.path}/$filename');

          await file.writeAsBytes(pngBytes);
          savedScreenshotPath = file.path;
        }
      }
    } catch (_) {}

    // 2. Filter visible-only annotations on screen to match the screenshot
    final visibleItems = _items.where((item) {
      final dy = item.isScrollable ? (item.scrollOffsetAtCreation - _currentScrollOffset) : 0.0;
      final displayRect = item.rect.translate(0, dy);
      return displayRect.bottom > 0 && displayRect.top < size.height;
    }).toList();

    // 3. Export structured Markdown matching the visual screenshot
    await AnnotterExporter.copyToClipboard(
      items: visibleItems.isNotEmpty ? visibleItems : _items,
      routeName: _activeScreenName,
      viewportSize: size,
      screenshotPath: savedScreenshotPath,
    );

    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('✓ Copied Markdown & Screenshot!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
