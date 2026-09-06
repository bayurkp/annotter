import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'tokens.dart';
import 'models.dart';
import 'floating_toolbar.dart';
import 'canvas.dart';
import 'sheet.dart';
import 'exporter.dart';
import 'idle_fab.dart';
import 'inspector.dart';
import 'list_sheet.dart';
import 'settings_dialog.dart';
import 'snapshot_helper.dart';
import 'sync_client.dart';

/// The root wrapper for Annotter.
/// Wraps your application to provide non-intrusive in-app UI inspection and annotation.
class Annotter extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final String? serverUrl;
  final String? snapshotDirectory;

  const Annotter({
    super.key,
    required this.child,
    this.enabled = true,
    this.serverUrl,
    this.snapshotDirectory,
  });

  @override
  State<Annotter> createState() => _AnnotterState();
}

class _AnnotterState extends State<Annotter> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final GlobalKey _appChildKey = GlobalKey();
  Key _appSubtreeKey = UniqueKey();

  bool _isActive = false;
  AnnotterMode _mode = AnnotterMode.widget;
  List<AnnotterItem> _items = [];

  // Settings state
  String _detailLevel = 'detailed'; // 'compact', 'standard', 'detailed'
  bool _includeTree = true;
  Color _markerColor = AnnotterColors.markerPalette[3]; // Default Emerald
  bool _clearOnCopy = false;
  bool _blockInteractions = false;
  bool _replaceServerOnCopy = false;
  String? _snapshotDirectory;
  bool _showSettings = false;
  bool _isAnimationPaused = false;

  // Sync Client & Status Polling
  AnnotterSyncClient? _syncClient;
  Timer? _statusPollTimer;
  bool? _isServerConnected;
  bool _isCopied = false;
  Timer? _copiedTimer;

  // Positions
  Offset _fabPosition = const Offset(20, 120);
  Offset _toolbarPosition = const Offset(20, 120);
  double _scrollOffset = 0.0;

  // Edit / Creation state
  AnnotterItem? _editingItem;
  bool _isCreating = false;
  bool _showList = false;
  String _currentScreenName = 'HomeScreen';

  // Undo / Redo History Stacks
  final List<List<AnnotterItem>> _undoStack = [];
  final List<List<AnnotterItem>> _redoStack = [];

  void _handleHotReload() {
    scheduleMicrotask(() async {
      try {
        await WidgetsBinding.instance.reassembleApplication();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _appSubtreeKey = UniqueKey();
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _snapshotDirectory = widget.snapshotDirectory;
    if (widget.serverUrl != null && widget.serverUrl!.isNotEmpty) {
      _syncClient = AnnotterSyncClient(serverUrl: widget.serverUrl!);
      _checkServerConnection();
    }
  }

  Future<void> _checkServerConnection() async {
    if (_syncClient == null || !mounted) return;
    final isConnected = await _syncClient!.ping();
    if (mounted) {
      if (_isServerConnected != isConnected) {
        setState(() => _isServerConnected = isConnected);
      }
      if (isConnected) {
        _startStatusPolling();
      } else {
        _statusPollTimer?.cancel();
        _statusPollTimer = null;
      }
    }
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _statusPollTimer?.cancel();
    _syncClient?.dispose();
    super.dispose();
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_syncClient == null || !mounted) return;
      if (!_syncClient!.isConnected) {
        _statusPollTimer?.cancel();
        _statusPollTimer = null;
        if (_isServerConnected == true) setState(() => _isServerConnected = false);
        return;
      }
      if (_items.isEmpty) return;
      final statuses = await _syncClient!.fetchStatuses();
      if (!mounted || statuses.isEmpty) return;

      bool changed = false;
      for (final item in _items) {
        final key = 'ann_${item.id}';
        if (statuses.containsKey(key) && item.status != statuses[key]) {
          item.status = statuses[key]!;
          changed = true;
        }
      }
      if (changed) setState(() {});
    });
  }

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

  void _toggleAnimationPause() {
    setState(() {
      _isAnimationPaused = !_isAnimationPaused;
      timeDilation = _isAnimationPaused ? 10000.0 : 1.0;
    });
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
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (overlayContext) {
              if (!_isActive) {
                // Inactive: Fullscreen app + Draggable FAB button
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    KeyedSubtree(
                      key: _appChildKey,
                      child: KeyedSubtree(
                        key: _appSubtreeKey,
                        child: widget.child,
                      ),
                    ),
                    AnnotterIdleFab(
                      position: _fabPosition,
                      onPositionChanged: (pos) => setState(() => _fabPosition = pos),
                      onTap: () {
                        setState(() {
                          _isActive = true;
                          // Initialize toolbar position near the FAB
                          _toolbarPosition = Offset(
                            _fabPosition.dx.clamp(8.0, mediaQuery.size.width - 56.0),
                            _fabPosition.dy.clamp(mediaQuery.padding.top + 8, mediaQuery.size.height - 320.0),
                          );
                        });
                      },
                      badgeCount: _items.length,
                    ),
                  ],
                );
              }

              // Active: 100% Native Fullscreen application + Draggable Floating Pill Toolbar + Canvas
              return Material(
                color: AnnotterColors.transparent,
                textStyle: const TextStyle(
                  decoration: TextDecoration.none,
                  fontFamily: 'sans-serif',
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Native 1:1 App Viewport & Repaint Boundary (Zero letterboxing)
                    RepaintBoundary(
                      key: _repaintBoundaryKey,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          NotificationListener<Notification>(
                            onNotification: (notification) {
                              if (notification is ScrollNotification) {
                                if (notification.metrics.axis == Axis.vertical) {
                                  setState(() {
                                    _scrollOffset = notification.metrics.pixels;
                                  });
                                }
                              } else if (notification is NavigationNotification) {
                                setState(() {});
                              }
                              return false;
                            },
                            child: IgnorePointer(
                              ignoring: _blockInteractions && _isActive,
                              child: KeyedSubtree(
                                key: _appChildKey,
                                child: KeyedSubtree(
                                  key: _appSubtreeKey,
                                  child: widget.child,
                                ),
                              ),
                            ),
                          ),

                          AnnotterCanvas(
                            items: _items,
                            mode: _mode,
                            scrollOffset: _scrollOffset,
                            markerColor: _markerColor,
                            onCreate: (item, screenName) {
                              _saveSnapshot();
                              setState(() {
                                if (screenName != null) {
                                  _currentScreenName = screenName;
                                }
                                _editingItem = item;
                                _isCreating = true;
                              });
                            },
                            onEdit: (item) {
                              setState(() {
                                _editingItem = item;
                                _isCreating = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // Agentations-style Draggable Floating Pill Toolbar
                    AnnotterFloatingToolbar(
                      initialPosition: _toolbarPosition,
                      onPositionChanged: (pos) => _toolbarPosition = pos,
                      mode: _mode,
                      onModeChanged: (mode) => setState(() => _mode = mode),
                      onExit: () => setState(() => _isActive = false),
                      onCopy: _copyNotes,
                      isCopied: _isCopied,
                      isServerConnected: _isServerConnected == true,
                      itemCount: _items.length,
                      canUndo: _undoStack.isNotEmpty,
                      onUndo: _undo,
                      canRedo: _redoStack.isNotEmpty,
                      onRedo: _redo,
                      onHotReload: _handleHotReload,
                      isAnimationPaused: _isAnimationPaused,
                      onToggleAnimationPause: _toggleAnimationPause,
                      onOpenList: () => setState(() => _showList = true),
                      onOpenSettings: () {
                        _checkServerConnection();
                        setState(() => _showSettings = true);
                      },
                      onClearAll: _items.isNotEmpty
                          ? () {
                              _saveSnapshot();
                              setState(() => _items.clear());
                            }
                          : null,
                    ),

                    // Keyboard-Adaptive Annotation Bottom Sheet Form
                    if (_editingItem != null)
                      _buildModalBackdrop(
                        onDismiss: () => setState(() => _editingItem = null),
                        alignment: Alignment.bottomCenter,
                        child: AnnotationSheet(
                          item: _editingItem!,
                          isNew: _isCreating,
                          onCancel: () => setState(() => _editingItem = null),
                          onDelete: () {
                            final deletedId = _editingItem?.id;
                            _saveSnapshot();
                            setState(() {
                              _items.removeWhere((i) => i.id == _editingItem!.id);
                              _renumberItems();
                              _editingItem = null;
                            });
                            if (deletedId != null) {
                              _syncClient?.deleteAnnotation(deletedId);
                            }
                          },
                          onSave: (note, intent, severity) {
                            final currentItem = _editingItem;
                            _saveSnapshot();
                            setState(() {
                              _editingItem!.note = note;
                              _editingItem!.intent = intent;
                              _editingItem!.severity = severity;
                              if (_isCreating) {
                                _items.add(_editingItem!);
                              }
                              _editingItem = null;
                            });
                            if (currentItem != null) {
                              _captureScreenshot('annotter_${currentItem.id}.png').then((path) {
                                _syncClient?.syncAnnotation(
                                  currentItem,
                                  route: _activeScreenName,
                                  screenshotPath: path,
                                );
                              });
                            }
                          },
                        ),
                      ),

                    // Inline Modal Annotation List Sheet
                    if (_showList)
                      _buildModalBackdrop(
                        onDismiss: () => setState(() => _showList = false),
                        alignment: Alignment.bottomCenter,
                        child: SafeArea(
                          bottom: true,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                            child: AnnotationListSheet(
                              items: _items,
                              onClose: () => setState(() => _showList = false),
                              onReorder: (newItems) {
                                _saveSnapshot();
                                setState(() {
                                  _items = newItems;
                                  _renumberItems();
                                });
                              },
                              onEdit: (item) {
                                setState(() {
                                  _showList = false;
                                  _editingItem = item;
                                  _isCreating = false;
                                });
                              },
                              onDelete: (item) {
                                _saveSnapshot();
                                setState(() {
                                  _items.removeWhere((i) => i.id == item.id);
                                  _renumberItems();
                                });
                                _syncClient?.deleteAnnotation(item.id);
                              },
                              onClearAll: () {
                                _saveSnapshot();
                                setState(() => _items.clear());
                                _syncClient?.clearAnnotations();
                              },
                            ),
                          ),
                        ),
                      ),

                    // Inline Modal Settings Dialog
                    if (_showSettings)
                      _buildModalBackdrop(
                        onDismiss: () => setState(() => _showSettings = false),
                        child: SingleChildScrollView(
                          child: AnnotterSettingsDialog(
                            detailLevel: _detailLevel,
                            includeTree: _includeTree,
                            markerColor: _markerColor,
                            clearOnCopy: _clearOnCopy,
                            blockInteractions: _blockInteractions,
                            replaceServerOnCopy: _replaceServerOnCopy,
                            isServerConnected: _isServerConnected,
                            snapshotDirectory: _snapshotDirectory,
                            onDetailLevelChanged: (lvl) => setState(() => _detailLevel = lvl),
                            onIncludeTreeChanged: (val) => setState(() => _includeTree = val),
                            onMarkerColorChanged: (col) => setState(() => _markerColor = col),
                            onClearOnCopyChanged: (val) => setState(() => _clearOnCopy = val),
                            onBlockInteractionsChanged: (val) =>
                                setState(() => _blockInteractions = val),
                            onReplaceServerOnCopyChanged: (val) =>
                                setState(() => _replaceServerOnCopy = val),
                            onSnapshotDirectoryChanged: (dir) =>
                                setState(() => _snapshotDirectory = dir),
                            onClearSnapshots: () async {
                              return await AnnotterSnapshotHelper.clearSnapshots(
                                snapshotDirectory: _snapshotDirectory,
                                syncClient: _syncClient,
                              );
                            },
                            onClose: () => setState(() => _showSettings = false),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Reusable modal backdrop scaffold with tap-to-dismiss.
  Widget _buildModalBackdrop({
    required VoidCallback onDismiss,
    required Widget child,
    Alignment alignment = Alignment.center,
  }) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: Container(
          color: AnnotterColors.overlay,
          alignment: alignment,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // Prevent backdrop dismiss when tapping content
            child: child,
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

  Future<String?> _captureScreenshot(String filename) async {
    final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    return AnnotterSnapshotHelper.capture(
      boundary: boundary,
      filename: filename,
      snapshotDirectory: _snapshotDirectory,
      syncClient: _syncClient,
    );
  }

  void _copyNotes() async {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;

    final String platformName = kIsWeb
        ? 'Web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'Android',
            TargetPlatform.iOS => 'iOS',
            TargetPlatform.windows => 'Windows',
            TargetPlatform.macOS => 'macOS',
            TargetPlatform.linux => 'Linux',
            TargetPlatform.fuchsia => 'Fuchsia',
          };
    final themeName = mediaQuery.platformBrightness == Brightness.dark
        ? 'Dark Mode'
        : 'Light Mode';
    final orientationName = mediaQuery.orientation == Orientation.portrait
        ? 'Portrait'
        : 'Landscape';
    final dpr = mediaQuery.devicePixelRatio;
    final textScale =
        '${(mediaQuery.textScaler.scale(10.0) / 10.0).toStringAsFixed(1)}x';

    String dynamicRoute = _activeScreenName;
    try {
      final modalRoute = ModalRoute.of(context);
      if (modalRoute != null &&
          modalRoute.settings.name != null &&
          modalRoute.settings.name!.isNotEmpty) {
        dynamicRoute = '${modalRoute.settings.name} ($_activeScreenName)';
      }
    } catch (_) {}

    final environment = AnnotterEnvironment(
      platform: platformName,
      theme: themeName,
      textScale: textScale,
      orientation: orientationName,
      devicePixelRatio: dpr,
      route: dynamicRoute,
    );

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final List<AnnotterViewSection> sections = [];

    if (_items.isEmpty) {
      final path = await _captureScreenshot('annotter_$timestamp.png');
      sections.add(AnnotterViewSection(
        title: _activeScreenName,
        screenshotPath: path,
        items: [],
      ));
    } else {
      ScrollPosition? scrollPos;
      final appCtx = _appChildKey.currentContext;
      if (appCtx != null) {
        void search(Element el) {
          if (scrollPos != null) return;
          if (el is StatefulElement && el.state is ScrollableState) {
            scrollPos = (el.state as ScrollableState).position;
            return;
          }
          el.visitChildren(search);
        }

        appCtx.visitChildElements(search);
      }

      final sortedItems = List<AnnotterItem>.from(_items)
        ..sort((a, b) => a.scrollOffset.compareTo(b.scrollOffset));

      final List<List<AnnotterItem>> clusters = [];
      for (final item in sortedItems) {
        if (clusters.isEmpty) {
          clusters.add([item]);
        } else {
          final lastCluster = clusters.last;
          final diff = (item.scrollOffset - lastCluster.first.scrollOffset).abs();
          if (diff < size.height * 0.75) {
            lastCluster.add(item);
          } else {
            clusters.add([item]);
          }
        }
      }

      if (clusters.length <= 1 || scrollPos == null) {
        final filename = 'annotter_$timestamp.png';
        final path = await _captureScreenshot(filename);
        sections.add(AnnotterViewSection(
          title: _activeScreenName,
          screenshotPath: path,
          items: _items,
        ));
      } else {
        final originalOffset = _scrollOffset;

        for (int i = 0; i < clusters.length; i++) {
          final cluster = clusters[i];
          final targetOffset = cluster.first.scrollOffset;

          scrollPos?.jumpTo(targetOffset);
          setState(() => _scrollOffset = targetOffset);
          await Future.delayed(const Duration(milliseconds: 100));

          final filename = 'annotter_view_${i + 1}_$timestamp.png';
          final path = await _captureScreenshot(filename);

          final sectionTitle = i == 0
              ? '$_activeScreenName (Top)'
              : '$_activeScreenName (Scrolled to ${targetOffset.toInt()}px)';

          sections.add(AnnotterViewSection(
            title: sectionTitle,
            screenshotPath: path,
            items: cluster,
          ));
        }

        scrollPos?.jumpTo(originalOffset);
        setState(() => _scrollOffset = originalOffset);
      }
    }

    // 1. Export structured Markdown to clipboard
    await AnnotterExporter.copyToClipboard(
      items: _items,
      routeName: dynamicRoute,
      viewportSize: Size(size.width, size.height),
      sections: sections,
      environment: environment,
      detailLevel: _detailLevel,
      includeTree: _includeTree,
    );

    // 2. Automatically sync all annotations to MCP server if connected
    if (_syncClient != null && _items.isNotEmpty) {
      final mainScreenshot =
          sections.isNotEmpty ? sections.first.screenshotPath : null;
      _syncClient!.syncAnnotations(
        _items,
        route: _activeScreenName,
        screenshotPath: mainScreenshot,
        replace: _replaceServerOnCopy,
      );
    }

    if (_clearOnCopy) {
      _saveSnapshot();
      setState(() => _items.clear());
    }

    // In-place button feedback (2s state indication)
    if (mounted) {
      _copiedTimer?.cancel();
      setState(() => _isCopied = true);
      _copiedTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isCopied = false);
        }
      });
    }
  }
}
