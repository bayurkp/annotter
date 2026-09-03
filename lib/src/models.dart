import 'package:flutter/material.dart';

enum AnnotterMode {
  move,
  select,
  widget,
  area,
  point,
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
  double scrollOffsetAtCreation;

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
    this.scrollOffsetAtCreation = 0.0,
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
      scrollOffsetAtCreation: scrollOffsetAtCreation,
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
