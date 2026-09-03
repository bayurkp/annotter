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

              final appBottomPadding = mediaQuery.padding.bottom;
              final canvasHeight = (appBottomPadding > 0) ? (size.height - appBottomPadding) : size.height;

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
                                    height: canvasHeight,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _activeMode == AnnotterMode.navigate
                                            ? const Color(0xFF10B981) // Green in Move
                                            : _activeMode == AnnotterMode.select
                                                ? const Color(0xFF6366F1) // Indigo in Select
                                                : const Color(0xFF0284C7), // DevTools Blue in annotate
                                        width: 2.0,
                                      ),
                                    ),
                                    child: RepaintBoundary(
                                      key: _repaintBoundaryKey,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Reactive Scroll & Navigation Listener + Inset override
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
                                            child: MediaQuery(
                                              data: mediaQuery.copyWith(
                                                size: Size(size.width, canvasHeight),
                                                padding: mediaQuery.padding.copyWith(bottom: 0),
                                                viewPadding: mediaQuery.viewPadding.copyWith(bottom: 0),
                                              ),
                                              child: KeyedSubtree(key: _appChildKey, child: widget.child),
                                            ),
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
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _activeDialogItem = null),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.65),
                                alignment: Alignment.center,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {}, // Prevent backdrop dismiss when tapping dialog itself
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
                            ),
                          ),

                        // Inline Modal Annotation List Sheet
                        // Inline Modal Annotation List Sheet
                        if (_showListSheet)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _showListSheet = false),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.65),
                                alignment: Alignment.bottomCenter,
                                child: SafeArea(
                                  bottom: true,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {}, // Prevent backdrop dismiss when tapping sheet itself
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
                                ),
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

  // Modern Glassmorphic Developer Tool Bottom Bar (Linear / Figma Dev Mode Aesthetic)
  Widget _buildSlimBottomBar(BuildContext context) {
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
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.0),
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
                  onTap: () => setState(() => _isActive = false),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  ),
                ),

                const SizedBox(width: 8),

                // 2. Cohesive Segmented Control Capsule for Tools
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSegmentTool(
                        icon: Icons.pan_tool_outlined,
                        label: 'Move',
                        mode: AnnotterMode.navigate,
                      ),
                      const SizedBox(width: 2),
                      _buildSegmentTool(
                        icon: Icons.near_me_outlined,
                        label: 'Select',
                        mode: AnnotterMode.select,
                      ),
                      const SizedBox(width: 2),
                      _buildSegmentTool(
                        icon: Icons.touch_app_outlined,
                        label: 'Inspect',
                        mode: AnnotterMode.inspect,
                      ),
                      const SizedBox(width: 2),
                      _buildSegmentTool(
                        icon: Icons.crop_square_rounded,
                        label: 'Area',
                        mode: AnnotterMode.rectangle,
                      ),
                      const SizedBox(width: 2),
                      _buildSegmentTool(
                        icon: Icons.pin_drop_outlined,
                        label: 'Pin',
                        mode: AnnotterMode.pin,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 3. Action Buttons Group (Undo, Redo, List, Clear)
                _buildActionSquare(
                  icon: Icons.undo_rounded,
                  tooltip: 'Undo',
                  enabled: _undoStack.isNotEmpty,
                  onTap: _undoStack.isEmpty ? null : _undo,
                ),
                const SizedBox(width: 4),

                _buildActionSquare(
                  icon: Icons.redo_rounded,
                  tooltip: 'Redo',
                  enabled: _redoStack.isNotEmpty,
                  onTap: _redoStack.isEmpty ? null : _redo,
                ),
                const SizedBox(width: 4),

                _buildActionSquare(
                  icon: Icons.format_list_numbered_rounded,
                  tooltip: 'Annotations List',
                  badgeCount: _items.isNotEmpty ? _items.length : null,
                  enabled: true,
                  onTap: () => setState(() => _showListSheet = true),
                ),
                const SizedBox(width: 4),

                if (_items.isNotEmpty) ...[
                  _buildActionSquare(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Clear All',
                    iconColor: Colors.redAccent.shade100,
                    enabled: true,
                    onTap: () {
                      _saveSnapshot();
                      setState(() => _items.clear());
                    },
                  ),
                  const SizedBox(width: 4),
                ],

                const SizedBox(width: 4),

                // 4. Copy CTA Button (High-contrast DevTools Blue Gradient)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _copyNotes,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x6638BDF8), width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          _items.isEmpty ? 'Copy' : 'Copy (${_items.length})',
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
    final isSelected = _activeMode == mode;
    final activeColor = mode == AnnotterMode.navigate
        ? const Color(0xFF10B981)
        : mode == AnnotterMode.select
            ? const Color(0xFF6366F1)
            : const Color(0xFF0284C7);

    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () => setState(() => _activeMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 28,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 10 : 8),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.white60,
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'sans-serif',
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ],
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
    final effectiveColor = enabled ? (iconColor ?? Colors.white70) : Colors.white24;

    return InkWell(
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
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
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

    final appBottomPadding = MediaQuery.of(context).padding.bottom;
    final canvasHeight = (appBottomPadding > 0) ? (size.height - appBottomPadding) : size.height;

    // 2. Filter visible-only annotations on screen to match the screenshot
    final visibleItems = _items.where((item) {
      final dy = item.isScrollable ? (item.scrollOffsetAtCreation - _currentScrollOffset) : 0.0;
      final displayRect = item.rect.translate(0, dy);
      return displayRect.bottom > 0 && displayRect.top < canvasHeight;
    }).toList();

    // 3. Export structured Markdown matching the visual screenshot
    await AnnotterExporter.copyToClipboard(
      items: visibleItems.isNotEmpty ? visibleItems : _items,
      routeName: _activeScreenName,
      viewportSize: Size(size.width, canvasHeight),
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
