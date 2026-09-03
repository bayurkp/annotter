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

  bool _isActive = false;
  AnnotterMode _activeMode = AnnotterMode.inspect;
  final List<AnnotterItem> _items = [];

  Offset _fabPosition = const Offset(20, 120);

  final GlobalKey _appChildKey = GlobalKey();

  AnnotterItem? _activeDialogItem;
  bool _isCreatingItem = false;
  String? _bannerMessage;
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

              // Active: Proportional Scale Studio
              return Container(
                  color: const Color(0xFF0B0F19), // Deep studio backdrop
                  child: SafeArea(
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            // Proportional Scaled App Viewport (Preserving exact aspect ratio & resolution)
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: Container(
                                      width: size.width,
                                      height: size.height,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.7),
                                            blurRadius: 28,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: _activeMode == AnnotterMode.navigate
                                              ? const Color(0xFF10B981) // Green in navigate
                                              : const Color(0xFF0284C7), // DevTools Blue in annotate
                                          width: 3.0,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(21),
                                        child: RepaintBoundary(
                                          key: _repaintBoundaryKey,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              KeyedSubtree(key: _appChildKey, child: widget.child),
                                              AnnotterCanvas(
                                                items: _items,
                                                activeMode: _activeMode,
                                                onRequestCreate: (item, screenName) {
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
                              ),
                            ),

                            // Vertical Side Rail Toolbar
                            _buildSideRail(),
                          ],
                        ),

                        // Top Screen Name & Banner
                        Positioned(
                          top: 8,
                          left: 14,
                          child: _buildTopStudioBar(),
                        ),

                        // Inline Modal Dialog
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
                                    setState(() {
                                      final deleteId = _activeDialogItem!.id;
                                      _items.removeWhere((i) => i.id == deleteId);
                                      _renumberItems();
                                      _activeDialogItem = null;
                                    });
                                  },
                                  onSave: (note) {
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
                      ],
                    ),
                  ),
                );
            },
          ),
        ],
      ),
    );
  }

  // Top Minimal Studio Bar
  Widget _buildTopStudioBar() {
    final modeLabel = _activeMode == AnnotterMode.navigate ? 'NAVIGATE (SCROLL)' : _activeMode.name.toUpperCase();
    final modeColor = _activeMode == AnnotterMode.navigate ? const Color(0xFF10B981) : const Color(0xFF0284C7);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: modeColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              _bannerMessage ?? '$_activeScreenName • $modeLabel',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'sans-serif',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Vertical Side Rail (DevTools Style)
  Widget _buildSideRail() {
    return Container(
      width: 54,
      margin: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate 800
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            // Close Button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              onPressed: () => setState(() => _isActive = false),
            ),
            const Divider(color: Colors.white12, height: 14, indent: 6, endIndent: 6),

            // Navigate (Scroll/Browse)
            _buildRailTool(
              icon: Icons.pan_tool_outlined,
              label: 'Nav',
              mode: AnnotterMode.navigate,
            ),
            const SizedBox(height: 6),

            // Inspect
            _buildRailTool(
              icon: Icons.touch_app_outlined,
              label: 'Inspect',
              mode: AnnotterMode.inspect,
            ),
            const SizedBox(height: 6),

            // Area (Rect)
            _buildRailTool(
              icon: Icons.crop_square_outlined,
              label: 'Area',
              mode: AnnotterMode.rectangle,
            ),
            const SizedBox(height: 6),

            // Pin
            _buildRailTool(
              icon: Icons.pin_drop_outlined,
              label: 'Pin',
              mode: AnnotterMode.pin,
            ),

            if (_items.isNotEmpty) ...[
              const Divider(color: Colors.white12, height: 14, indent: 6, endIndent: 6),
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                onPressed: () => setState(() => _items.clear()),
              ),
            ],

            const Spacer(),

            // Copy for AI Button (DevTools Blue)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _copyForAI,
              child: Container(
                width: 42,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7), // DevTools Blue
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.copy_all, color: Colors.white, size: 16),
                    const SizedBox(height: 2),
                    Text(
                      _items.isEmpty ? 'AI' : 'AI (${_items.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildRailTool({
    required IconData icon,
    required String label,
    required AnnotterMode mode,
  }) {
    final isSelected = _activeMode == mode;
    final activeColor = mode == AnnotterMode.navigate ? const Color(0xFF10B981) : const Color(0xFF0284C7);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _activeMode = mode),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: isSelected ? Colors.white : Colors.white60),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'sans-serif',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Draggable FAB for idle trigger (DevTools Blue)
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
      _items[i] = AnnotterItem(
        id: _items[i].id,
        number: i + 1,
        rect: _items[i].rect,
        widgetName: _items[i].widgetName,
        hierarchy: _items[i].hierarchy,
        note: _items[i].note,
        mode: _items[i].mode,
        screenName: _items[i].screenName,
      );
    }
  }

  void _copyForAI() async {
    final size = MediaQuery.of(context).size;

    // 1. Auto-capture screenshot
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

    // 2. Export structured Markdown grouped by screen
    await AnnotterExporter.copyToClipboard(
      items: _items,
      routeName: _activeScreenName,
      viewportSize: size,
      screenshotPath: savedScreenshotPath,
    );

    setState(() {
      _bannerMessage = '✓ Copied Markdown & Screenshot!';
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _bannerMessage = null);
      }
    });
  }
}
