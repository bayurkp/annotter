import 'package:flutter/material.dart';

enum AnnotterMode {
  move,
  select,
  widget,
  area,
  point,
}

class SourceCallSite {
  final String widgetName;
  final String location; // e.g. "lib/features/home_screen.dart:42"

  const SourceCallSite({
    required this.widgetName,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
    'widgetName': widgetName,
    'location': location,
  };

  factory SourceCallSite.fromJson(Map<String, dynamic> json) => SourceCallSite(
    widgetName: json['widgetName'] as String? ?? '',
    location: json['location'] as String? ?? '',
  );

  @override
  String toString() => '$widgetName ($location)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceCallSite &&
          runtimeType == other.runtimeType &&
          widgetName == other.widgetName &&
          location == other.location;

  @override
  int get hashCode => widgetName.hashCode ^ location.hashCode;
}

class AnnotterItem {
  final int id;
  int number;
  Rect rect;
  String widgetName;
  List<String> hierarchy;
  String note;
  AnnotterMode mode;
  String screenName;
  bool isScrollable;
  double scrollOffset;
  String? intent; // 'fix', 'style', 'change', 'question'
  String? severity; // 'blocking', 'important', 'suggestion'
  String?
      selectedText; // Actual text content if clicked element is or contains Text
  String? sourceLocation; // Flutter file & line e.g. "lib/views/home_screen.dart:42"
  List<SourceCallSite> callStack; // Caller hierarchy stack from element traversal
  Map<String, String>? properties; // Widget properties (DiagnosticsNode)
  String status; // 'pending', 'resolved'

  AnnotterItem({
    required this.id,
    required this.number,
    required this.rect,
    this.widgetName = 'Element',
    this.hierarchy = const [],
    this.note = '',
    this.mode = AnnotterMode.widget,
    this.screenName = 'HomeScreen',
    this.isScrollable = false,
    this.scrollOffset = 0.0,
    this.intent,
    this.severity,
    this.selectedText,
    this.sourceLocation,
    this.callStack = const [],
    this.properties,
    this.status = 'pending',
  });

  AnnotterItem copy() {
    return AnnotterItem(
      id: id,
      number: number,
      rect: rect,
      widgetName: widgetName,
      hierarchy: List.from(hierarchy),
      note: note,
      mode: mode,
      screenName: screenName,
      isScrollable: isScrollable,
      scrollOffset: scrollOffset,
      intent: intent,
      severity: severity,
      selectedText: selectedText,
      sourceLocation: sourceLocation,
      callStack: List.from(callStack),
      properties: properties != null ? Map.from(properties!) : null,
      status: status,
    );
  }
}

class AnnotterViewSection {
  final String title;
  final String? screenshotPath;
  final List<AnnotterItem> items;

  const AnnotterViewSection({
    required this.title,
    this.screenshotPath,
    required this.items,
  });
}

class AnnotterEnvironment {
  final String platform;
  final String theme;
  final String textScale;
  final String orientation;
  final double devicePixelRatio;
  final String? route;
  final DateTime timestamp;

  AnnotterEnvironment({
    required this.platform,
    required this.theme,
    required this.textScale,
    required this.orientation,
    required this.devicePixelRatio,
    this.route,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
