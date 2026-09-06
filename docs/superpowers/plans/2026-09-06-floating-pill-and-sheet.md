# Floating Pill Toolbar, Bottom Sheet Form & Design Tokens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement global design tokens (`tokens.dart`), keyboard-adaptive bottom sheet annotation form (`sheet.dart`), and an Agentations-style draggable floating pill toolbar (`floating_toolbar.dart`) while restoring 100% native fullscreen rendering in Annotter.

**Architecture:** 
- Centralize all design tokens into `lib/src/tokens.dart` (palettes, semantic tokens `AnnotterColors`, border tokens `AnnotterBorders`, elevation shadows `AnnotterShadows`, text styles `AnnotterTextStyles`).
- Replace `AnnotationDialog` (`dialog.dart`) with `AnnotationSheet` (`sheet.dart`) that anchors to the screen bottom and automatically glides above the keyboard via `viewInsets.bottom`.
- Replace static bottom dock `AnnotterBottomBar` (`bottom_bar.dart`) with a draggable floating pill capsule `AnnotterFloatingToolbar` (`floating_toolbar.dart`) with modern icons (`touch_app_outlined` / `layers_outlined` for Widget inspection).
- Remove `FittedBox` letterboxing in `overlay.dart` to make the canvas and target Flutter app 100% fullscreen native.

**Tech Stack:** Flutter SDK (Pure Dart / zero external packages), Flutter Material & Rendering.

## Global Constraints
- Pure Flutter SDK, zero external pub dependencies.
- No `SnackBar` usage anywhere.
- 100% English for code, comments, commit messages, and documentation.
- Delete `docs/superpowers/specs/2026-09-06-floating-pill-and-sheet-design.md` once all tasks and verifications pass.

---

### Task 1: Global Design Tokens Architecture (`lib/src/tokens.dart`)

**Files:**
- Create: `lib/src/tokens.dart`
- Modify: `lib/src/colors.dart` (re-export or alias for backwards compatibility)
- Modify: `lib/annotter.dart` (export `src/tokens.dart`)
- Test: `test/annotter_test.dart`

**Interfaces:**
- Produces: 
  - `AnnotterPalette`: Primitive 50-950 Tailwind palettes.
  - `AnnotterColors`: Semantic color tokens (`primary`, `onPrimary`, `surface`, `onSurface`, `background`, `foreground`, `border`, `success`, `error`, etc.).
  - `AnnotterBorders`: Semantic border tokens (radii: `sm`, `md`, `lg`, `pill`, `sheet`, borders: `subtle`, `standard`, `active`).
  - `AnnotterShadows`: Semantic box shadows (`sm`, `md`, `pill`, `sheet`).
  - `AnnotterTextStyles`: Standardized font sizing & weights.

- [ ] **Step 1: Write unit test for design tokens in `test/annotter_test.dart`**
- [ ] **Step 2: Implement `lib/src/tokens.dart` with full semantic token scales**
- [ ] **Step 3: Update `lib/src/colors.dart` to delegate to `tokens.dart`**
- [ ] **Step 4: Run `flutter test` and `flutter analyze`**
- [ ] **Step 5: Commit changes**

---

### Task 2: Keyboard-Adaptive Annotation Bottom Sheet (`lib/src/sheet.dart`)

**Files:**
- Create: `lib/src/sheet.dart`
- Modify: `lib/src/overlay.dart` (switch from dialog to bottom sheet)
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: `AnnotterColors`, `AnnotterBorders`, `AnnotterShadows`, `AnnotterItem`
- Produces: `AnnotationSheet` widget:
  - Header: Drag handle, Item Number badge, Widget Name, Screen Route, Selected Text/source location.
  - Intent chips (`Fix`, `Style`, `Change`, `Question`).
  - Severity chips (`Blocking`, `Important`, `Suggestion`).
  - Multiline `TextField` with autofocus and dynamic bottom padding `viewInsets.bottom + 16`.
  - Actions: Delete, Cancel, Save Note.

- [ ] **Step 1: Create `lib/src/sheet.dart` using semantic design tokens**
- [ ] **Step 2: Add swipe down gesture to dismiss sheet**
- [ ] **Step 3: Write widget test verifying sheet rendering and keyboard inset adaptation**
- [ ] **Step 4: Run `flutter test` and `flutter analyze`**
- [ ] **Step 5: Commit changes**

---

### Task 3: Floating Pill Toolbar ala Agentations (`lib/src/floating_toolbar.dart`)

**Files:**
- Create: `lib/src/floating_toolbar.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: `AnnotterColors`, `AnnotterBorders`, `AnnotterShadows`, `AnnotterMode`
- Produces: `AnnotterFloatingToolbar` widget:
  - Height 44px capsule (`BorderRadius.circular(22)`).
  - Clean iconography:
    - `Move`: `Icons.pan_tool_outlined`
    - `Select`: `Icons.near_me_outlined`
    - `Widget`: `Icons.touch_app_outlined` (or `layers_outlined` instead of old widget cube)
    - `Area`: `Icons.crop_square_rounded`
    - `Point`: `Icons.adjust_rounded`
  - Quick actions: Copy (with count & sent state), Undo/Redo, Freeze, List, Settings.
  - Vertical separator divider.
  - Close button (`Icons.close_rounded`) to collapse back to idle FAB button.

- [ ] **Step 1: Implement `lib/src/floating_toolbar.dart`**
- [ ] **Step 2: Implement draggable positioning and clamping in screen viewport**
- [ ] **Step 3: Add unit/widget tests for floating pill toolbar**
- [ ] **Step 4: Run `flutter test` and `flutter analyze`**
- [ ] **Step 5: Commit changes**

---

### Task 4: Fullscreen Native Overlay Integration (`lib/src/overlay.dart`)

**Files:**
- Modify: `lib/src/overlay.dart`
- Delete/Deprecate: `lib/src/dialog.dart`, `lib/src/bottom_bar.dart`
- Modify: `lib/annotter.dart`

**Interfaces:**
- Renders `widget.child` at 100% native resolution (removes `Container(color: studioBackdrop)` and `FittedBox`).
- Draggable FAB in idle state smoothly toggles to draggable Floating Pill Toolbar in active state.
- `AnnotationSheet` opens when new annotation is tapped or edited.

- [ ] **Step 1: Refactor `overlay.dart` to remove letterboxing & connect `AnnotationSheet` and `AnnotterFloatingToolbar`**
- [ ] **Step 2: Remove obsolete `dialog.dart` and `bottom_bar.dart`**
- [ ] **Step 3: Run full suite: `flutter analyze` & `flutter test`**
- [ ] **Step 4: Delete temporary design spec `docs/superpowers/specs/2026-09-06-floating-pill-and-sheet-design.md`**
- [ ] **Step 5: Commit and push to git**
