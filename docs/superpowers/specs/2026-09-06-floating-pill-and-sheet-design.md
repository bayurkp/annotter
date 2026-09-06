# Design Spec: Semantic Color Tokens, Floating Pill Toolbar & Bottom Sheet Annotation Form

**Date:** 2026-09-06  
**Status:** Validated / Ready for Implementation  
**Target:** Flutter SDK (Pure Dart / zero external packages)

---

## 1. Overview & Goals

Transform Annotter's UI architecture away from a rigid bottom dock and centered modal dialog into a lightweight, non-intrusive developer experience inspired by Agentations:
1. **Full 3-Layer Design System & Color Tokens**: Centralize primitive palettes, semantic roles (`primary`, `surface`, `foreground`, `border`, `success`, `error`, etc.), and component tokens in `lib/src/colors.dart` so widgets never repeatedly write raw hexadecimal or palette index lookups.
2. **Native 1:1 Fullscreen Experience**: Eliminate the artificial studio letterboxing and `FittedBox` viewport shrinkage. The underlying application renders at 100% native resolution and scale.
3. **Agentations-Style Floating Pill Toolbar**: Replace the full-width bottom bar with an adaptive floating pill capsule. Users can drag it anywhere on screen, collapse to an idle circular button, or expand into tools with zero screen real estate sacrifice.
4. **Keyboard-Adaptive Bottom Sheet Form**: Replace `AnnotationDialog` with a sleek `AnnotationSheet` that docks at the bottom, automatically pans upwards smoothly with `MediaQuery.viewInsets.bottom` when the software keyboard opens, and supports swipe-to-dismiss gestures.

---

## 2. Design System: Three-Layer Color Tokens (`lib/src/colors.dart`)

Refactor `lib/src/colors.dart` into a clean hierarchy:
- **Primitives / Palettes (`AnnotterPalette`)**: MaterialColor scales (50-950) for slate, gray, blue, emerald, amber, red, etc.
- **Semantic Tokens (`AnnotterColors`)**: High-level semantic aliases consumed directly by UI components.
- **Component Tokens (`AnnotterSheetTokens`, `AnnotterPillTokens`)**: Layout & geometry constants (radii, elevations, padding, heights).

### Semantic Token Structure
```dart
class AnnotterColors {
  const AnnotterColors._();

  // --- Primary / Action ---
  static const primary = AnnotterPalette.blue;
  static const primaryForeground = AnnotterPalette.white;
  static const secondary = AnnotterPalette.slate;
  static const secondaryForeground = AnnotterPalette.white;
  static const tertiary = AnnotterPalette.indigo;
  static const tertiaryForeground = AnnotterPalette.white;

  // --- Content ---
  static const foreground = AnnotterPalette.white;
  static const mutedForeground = Color(0xFF94A3B8); // slate-400
  static const subtleForeground = Color(0xFF64748B); // slate-500

  // --- Surface & Background ---
  static const background = Color(0xFF0F172A); // slate-900
  static const surface = Color(0xFF1E293B);    // slate-800
  static const surfaceElevated = Color(0xFF334155); // slate-700
  static const surfaceBackdrop = Color(0xB3000000); // 70% black
  static const muted = Color(0xFF1E293B);      // slate-800

  // --- Status & Feedback ---
  static const success = AnnotterPalette.emerald;
  static const successForeground = AnnotterPalette.white;
  static const warning = AnnotterPalette.amber;
  static const warningForeground = AnnotterPalette.white;
  static const error = AnnotterPalette.red;
  static const errorForeground = AnnotterPalette.white;
  static const info = AnnotterPalette.blue;
  static const infoForeground = AnnotterPalette.white;

  // --- Utility & Controls ---
  static const border = Color(0x24FFFFFF); // 14% white border
  static const borderSubtle = Color(0x14FFFFFF); // 8% white
  static const input = Color(0xFF090D16); // near black
  static const ring = Color(0xFF3B82F6); // focus blue ring
  static const overlay = Color(0x800F172A);
  static const handle = Color(0x4DFFFFFF); // 30% white grab bar

  // --- Primitives Direct Access ---
  static const white = AnnotterPalette.white;
  static const black = AnnotterPalette.black;
  static const transparent = AnnotterPalette.transparent;
  static const slate = AnnotterPalette.slate;
  static const blue = AnnotterPalette.blue;
  static const emerald = AnnotterPalette.emerald;
  static const amber = AnnotterPalette.amber;
  static const red = AnnotterPalette.red;
  static const indigo = AnnotterPalette.indigo;
}
```

---

## 3. UI Component Architecture

### A. Floating Pill Toolbar (`lib/src/floating_toolbar.dart`)
Replaces `AnnotterBottomBar`.
- **Capsule Geometry**: Height 44px, `BorderRadius.circular(22)`, padding horizontal 6px.
- **Draggable & Boundary Constrained**: Follows pointer/pan gestures and clamps inside `MediaQuery.padding` / `viewInsets`.
- **Left/Tool Segment**:
  - `Move` (Hand icon)
  - `Select` (Pointer icon)
  - `Widget` (Widgets icon - default)
  - `Area` (Crop/box icon)
  - `Point` (Target/crosshair icon)
- **Center Quick Actions**:
  - `Copy` (Sent/Copied with in-place badge and dynamic count)
  - `Undo` / `Redo`
  - `Freeze Animation`
  - `Annotation List` (with count badge)
  - `Settings`
- **Right Segment**:
  - Vertical micro-divider
  - `Close / Collapse (x)` button returning the state to idle circular FAB.

### B. Annotation Input Sheet (`lib/src/sheet.dart`)
Replaces `AnnotationDialog`.
- **Positioning**: Bottom aligned modal, max-width 520px (centered on tablets/desktop).
- **Keyboard Adaptation**:
  ```dart
  padding: EdgeInsets.only(
    left: 16,
    right: 16,
    top: 8,
    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
  )
  ```
- **Drag Handle**: Top centered pill `(width: 36, height: 4)` supporting drag-to-dismiss gesture.
- **Header**:
  - Number badge + Selected Widget Name (`item.widgetName`).
  - Screen / Route tag and mode badge (`WIDGET`, `AREA`, `POINT`).
  - Selected text preview or Flutter source location (if available).
- **Interactive Controls**:
  - Intent chips: `Fix` (rose), `Style` (sky), `Change` (amber), `Question` (indigo).
  - Severity chips: `Blocking` (red), `Important` (orange), `Suggestion` (slate).
  - Multiline `TextField` with auto-focus.
- **Action Footer**:
  - `Delete` (in edit mode)
  - `Cancel`
  - `Save Note` (primary CTA with checkmark)

### C. Root Integration (`lib/src/overlay.dart`)
- Eliminates `Container(color: studioBackdrop)` and `FittedBox(fit: BoxFit.contain)`.
- Renders `widget.child` directly in a native `Stack` with the `RepaintBoundary` and `AnnotterCanvas` overlaying 1:1 on top.
- Floating Pill Toolbar floats seamlessly above the canvas.

---

## 4. Verification & Testing Plan
1. **Static Analysis**: `flutter analyze` must produce 0 issues.
2. **Unit & Widget Tests**: Update `test/widget_test.dart` and `test/annotter_test.dart` to assert:
   - Fullscreen rendering without `FittedBox`.
   - `AnnotationSheet` opens on annotation creation and responds correctly to dismiss/save actions.
   - `FloatingToolbar` renders all tools and triggers callbacks.
3. **MCP Consistency**: MCP server syntax and sync protocols remain 100% compatible.
