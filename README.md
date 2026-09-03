# Annotter ✍️🤖

> **Visual feedback for AI agents in Flutter.**  
> Inspired by [Agentation](https://www.agentation.com/). Click any element, drag bounding boxes, drop numbered pins, attach notes, and export structured Markdown context directly to AI coding agents (Claude Code, Cursor, Antigravity, Gemini).

---

## ⚡ Quick Start

### 1. Add dependency
In your Flutter app's `pubspec.yaml`:

```yaml
dev_dependencies:
  annotter:
    path: ../annotter # or git URL
```

### 2. Wrap your app

```dart
import 'package:annotter/annotter.dart';

void main() {
  runApp(
    const Annotter(
      child: MyApp(),
    ),
  );
}
```

> **Note:** Annotter automatically disables itself in release/profile mode (`kDebugMode` only). Zero overhead in production!

---

## 🛠️ Features

- **Inspect Mode (Smart Widget Detection)**: Tap any widget to automatically extract its name, bounding box, and widget tree hierarchy.
- **Area Mode (Rectangle Selection)**: Drag to select arbitrary UI areas.
- **Pin Mode**: Drop numbered pins (①, ②, ③) on specific UI points.
- **Structured AI Markdown Export**: Generates Markdown context formatted specifically for AI coding agents to grep your codebase.

---

## 📋 Example AI Output

When you click **"Copy for AI"**, your clipboard gets:

```markdown
## Page Feedback: /dashboard
**Viewport:** 393x852
**Total Annotations:** 2

### 1. PrimaryButton
**Hierarchy:** <DashboardPage> <ActionRow> <PrimaryButton>
**Position:** x:24, y:450 (w:345, h:48)
**Mode:** inspect
**Feedback:** Button text should say "Save", not "Submit"

### 2. SelectionArea
**Hierarchy:** <DashboardPage> <StatsCard>
**Position:** x:24, y:120 (w:160, h:100)
**Mode:** rectangle
**Feedback:** Margin between cards should be 16px instead of 8px
```
